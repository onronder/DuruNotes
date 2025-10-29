/**
 * Production-Grade Push Notification Service
 * Sends notifications IMMEDIATELY when called (no cron, no polling)
 *
 * Usage:
 *   POST /send-push-notification
 *   {
 *     "user_id": "uuid" | ["uuid1", "uuid2"],  // Single user or array
 *     "title": "Notification Title",
 *     "body": "Notification message",
 *     "data": { ... },  // Optional custom data
 *     "priority": "high" | "normal"  // Optional, defaults to "high"
 *   }
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/**
 * Generate FCM access token using Deno native crypto
 */
async function getAccessToken(serviceAccount: any): Promise<string> {
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: getNumericDate(60 * 60),
    iat: getNumericDate(0),
  };

  // Import private key
  const privateKey = serviceAccount.private_key;
  const pemContents = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  // Create and sign JWT
  const jwt = await create({ alg: "RS256", typ: "JWT" }, payload, cryptoKey);

  // Exchange for access token
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`Failed to get access token: ${await response.text()}`);
  }

  const data = await response.json();
  return data.access_token;
}

/**
 * Send FCM notification to a single device
 */
async function sendToDevice(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
  priority: "high" | "normal" = "high"
): Promise<{ success: boolean; error?: string }> {
  const message = {
    token: fcmToken,
    notification: { title, body },
    data,
    apns: {
      headers: {
        "apns-priority": priority === "high" ? "10" : "5",
      },
      payload: {
        aps: {
          alert: { title, body },
          sound: "default",
          badge: 1,
        },
      },
    },
    android: {
      priority: priority === "high" ? "high" : "normal",
      notification: {
        sound: "default",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message }),
    }
  );

  if (response.ok) {
    const result = await response.json();
    return { success: true };
  } else {
    const error = await response.json();
    return {
      success: false,
      error: error.error?.message || "Unknown FCM error",
    };
  }
}

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    console.log("📱 Push notification request received");

    // Parse request body
    const body = await req.json();
    const {
      user_id,
      user_ids,
      title,
      body: messageBody,
      data = {},
      priority = "high",
    } = body;

    // Validation
    if (!title || !messageBody) {
      throw new Error("Missing required fields: title and body");
    }

    const targetUserIds = user_ids || (user_id ? [user_id] : []);
    if (targetUserIds.length === 0) {
      throw new Error("No user_id or user_ids provided");
    }

    console.log(`📤 Sending to ${targetUserIds.length} user(s)`);

    // Get FCM service account
    const serviceAccountKey = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
    if (!serviceAccountKey) {
      throw new Error("FCM_SERVICE_ACCOUNT_KEY not configured");
    }

    const serviceAccount = JSON.parse(serviceAccountKey);
    const projectId = serviceAccount.project_id;

    // Get access token
    const accessToken = await getAccessToken(serviceAccount);

    // Initialize Supabase
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Get FCM tokens for all target users
    const { data: devices, error: devicesError } = await supabase
      .from("user_devices")
      .select("user_id, push_token, platform")
      .in("user_id", targetUserIds)
      .not("push_token", "is", null);

    if (devicesError) {
      throw new Error(`Failed to get devices: ${devicesError.message}`);
    }

    if (!devices || devices.length === 0) {
      console.warn("⚠️ No devices found for specified users");
      return new Response(
        JSON.stringify({
          success: false,
          error: "No devices found",
          user_ids: targetUserIds,
        }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`📲 Found ${devices.length} device(s)`);

    // Send to all devices IN PARALLEL
    const sendPromises = devices.map((device) =>
      sendToDevice(
        accessToken,
        projectId,
        device.push_token,
        title,
        messageBody,
        {
          ...data,
          timestamp: new Date().toISOString(),
        },
        priority
      )
    );

    const results = await Promise.allSettled(sendPromises);

    // Count successes and failures
    const successful = results.filter(
      (r) => r.status === "fulfilled" && r.value.success
    ).length;
    const failed = results.length - successful;

    const duration = Date.now() - startTime;

    console.log(
      `✅ Sent: ${successful}/${devices.length} in ${duration}ms`
    );

    // Optional: Log to database for analytics
    if (successful > 0) {
      const { error: logError } = await supabase
        .from("notification_events")
        .insert({
          user_id: targetUserIds[0], // Primary user
          event_type: "push_notification",
          event_source: "app",
          status: "delivered",
          priority,
          payload: {
            title,
            body: messageBody,
            data,
            recipients_count: successful,
          },
          delivered_at: new Date().toISOString(),
        });

      if (logError) {
        console.warn("Failed to log notification:", logError);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent: successful,
        failed,
        total: devices.length,
        duration_ms: duration,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("❌ Error:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
