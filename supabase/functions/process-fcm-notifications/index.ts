/**
 * Process FCM Notifications - Production Function
 * Based on working test-fcm-simple approach using Deno native crypto
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
 * Generate OAuth2 access token for FCM using Deno native crypto
 */
async function getAccessToken(serviceAccount: any): Promise<string> {
  // Prepare JWT claims
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: getNumericDate(60 * 60), // 1 hour
    iat: getNumericDate(0),
  };

  // Import the private key
  const privateKey = serviceAccount.private_key;
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = privateKey
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  // Create JWT
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    payload,
    cryptoKey
  );

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    const error = await tokenResponse.text();
    throw new Error(`Failed to exchange JWT for access token: ${error}`);
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

/**
 * Send FCM notification
 */
async function sendFcmNotification(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<{ success: boolean; error?: string }> {
  const message = {
    token,
    notification: {
      title,
      body,
    },
    data: data || {},
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          alert: {
            title,
            body,
          },
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  const fcmResponse = await fetch(
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

  const fcmResult = await fcmResponse.json();

  if (fcmResponse.ok) {
    return { success: true };
  } else {
    return {
      success: false,
      error: fcmResult.error?.message || "Unknown error",
    };
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("🔔 Processing FCM notifications...");

    // Get service account key
    const serviceAccountKey = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
    if (!serviceAccountKey) {
      throw new Error("FCM_SERVICE_ACCOUNT_KEY not configured");
    }

    const serviceAccount = JSON.parse(serviceAccountKey);
    const projectId = serviceAccount.project_id;

    // Get OAuth access token
    const accessToken = await getAccessToken(serviceAccount);

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Supabase configuration missing");
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Get pending notifications (limit to 50)
    const { data: notifications, error: fetchError } = await supabase
      .from("notification_events")
      .select("*")
      .eq("status", "pending")
      .order("created_at", { ascending: true })
      .limit(50);

    if (fetchError) {
      throw new Error(`Failed to fetch notifications: ${fetchError.message}`);
    }

    if (!notifications || notifications.length === 0) {
      console.log("No pending notifications");
      return new Response(
        JSON.stringify({
          success: true,
          processed: 0,
          delivered: 0,
          failed: 0,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`Found ${notifications.length} pending notifications`);

    let delivered = 0;
    let failed = 0;

    // Process each notification
    for (const notification of notifications) {
      try {
        // Get user devices
        const { data: devices, error: devicesError } = await supabase
          .from("user_devices")
          .select("*")
          .eq("user_id", notification.user_id)
          .not("push_token", "is", null);

        if (devicesError || !devices || devices.length === 0) {
          // Mark as failed
          await supabase
            .from("notification_events")
            .update({
              status: "failed",
              error_message: "No devices found",
              updated_at: new Date().toISOString(),
            })
            .eq("id", notification.id);

          failed++;
          continue;
        }

        // Send to all user devices
        let sentCount = 0;
        for (const device of devices) {
          const result = await sendFcmNotification(
            accessToken,
            projectId,
            device.push_token,
            notification.payload?.title || "Notification",
            notification.payload?.body || "",
            {
              notification_id: notification.id,
              event_type: notification.event_type,
              ...notification.payload,
            }
          );

          if (result.success) {
            sentCount++;
          }
        }

        // Update notification status
        if (sentCount > 0) {
          await supabase
            .from("notification_events")
            .update({
              status: "delivered",
              delivered_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
            .eq("id", notification.id);

          delivered++;
        } else {
          await supabase
            .from("notification_events")
            .update({
              status: "failed",
              error_message: "Failed to send to any device",
              updated_at: new Date().toISOString(),
            })
            .eq("id", notification.id);

          failed++;
        }
      } catch (error) {
        console.error(`Error processing notification ${notification.id}:`, error);

        await supabase
          .from("notification_events")
          .update({
            status: "failed",
            error_message: error instanceof Error ? error.message : String(error),
            updated_at: new Date().toISOString(),
          })
          .eq("id", notification.id);

        failed++;
      }
    }

    console.log(`✅ Processed ${notifications.length} notifications (${delivered} delivered, ${failed} failed)`);

    return new Response(
      JSON.stringify({
        success: true,
        processed: notifications.length,
        delivered,
        failed,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("❌ Function error:", error);
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
