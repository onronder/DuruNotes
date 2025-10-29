/**
 * Simple FCM Test Function - Using Deno native APIs
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

/**
 * Generate OAuth2 access token for FCM using Deno native crypto
 */
async function getAccessToken(serviceAccount: any): Promise<string> {
  console.log("🔐 Generating OAuth2 access token...");

  // Prepare JWT claims
  const now = Math.floor(Date.now() / 1000);
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

  console.log("✅ JWT created successfully");

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
    console.error("❌ Token exchange failed:", error);
    throw new Error(`Failed to exchange JWT for access token: ${error}`);
  }

  const tokenData = await tokenResponse.json();
  console.log("✅ Access token obtained");

  return tokenData.access_token;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("🔔 Test FCM function started");

    // Check if FCM_SERVICE_ACCOUNT_KEY is set
    const serviceAccountKey = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");

    if (!serviceAccountKey) {
      console.error("❌ FCM_SERVICE_ACCOUNT_KEY not found in environment");
      return new Response(JSON.stringify({
        success: false,
        error: "FCM_SERVICE_ACCOUNT_KEY not configured",
        hint: "Set the secret in Supabase Dashboard: Project Settings → Edge Functions → Secrets"
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Parse and validate the service account
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountKey);
      console.log("✅ Service account parsed successfully");
      console.log(`📱 Project ID: ${serviceAccount.project_id}`);
      console.log(`📧 Client Email: ${serviceAccount.client_email}`);
    } catch (parseError) {
      console.error("❌ Failed to parse service account JSON:", parseError);
      return new Response(JSON.stringify({
        success: false,
        error: "Invalid service account JSON format",
        details: String(parseError)
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Validate required fields
    if (!serviceAccount.project_id || !serviceAccount.client_email || !serviceAccount.private_key) {
      return new Response(JSON.stringify({
        success: false,
        error: "Invalid service account: missing required fields",
        required: ["project_id", "client_email", "private_key"]
      }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get OAuth2 access token
    const accessToken = await getAccessToken(serviceAccount);
    console.log(`🔑 Access token: ${accessToken.substring(0, 20)}...`);

    // Test sending to a token (if provided)
    const body = await req.json().catch(() => ({}));
    const testToken = body.token;

    if (testToken) {
      console.log(`📤 Attempting to send test notification to: ${testToken.substring(0, 30)}...`);

      const message = {
        token: testToken,
        notification: {
          title: "Test from Supabase",
          body: "FCM is working! 🎉"
        },
        data: {
          test: "true",
          timestamp: new Date().toISOString(),
          source: "supabase-edge-function"
        },
        apns: {
          headers: {
            "apns-priority": "10"
          },
          payload: {
            aps: {
              alert: {
                title: "Test from Supabase",
                body: "FCM is working! 🎉"
              },
              sound: "default",
              badge: 1
            }
          }
        }
      };

      const fcmResponse = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
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
        console.log("✅ Notification sent successfully!");
        console.log(`📨 Message ID: ${fcmResult.name}`);
        return new Response(JSON.stringify({
          success: true,
          message: "Notification sent successfully! Check your iPhone 📱",
          messageId: fcmResult.name,
          project_id: serviceAccount.project_id,
          token_preview: `${testToken.substring(0, 30)}...`
        }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      } else {
        console.error("❌ FCM send failed:", fcmResult);
        return new Response(JSON.stringify({
          success: false,
          error: "FCM send failed",
          status: fcmResponse.status,
          details: fcmResult,
          hint: fcmResult.error?.message || "Check FCM error details"
        }), {
          status: fcmResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    // No token provided - just return success with config info
    return new Response(JSON.stringify({
      success: true,
      message: "FCM configuration is valid ✅",
      config: {
        project_id: serviceAccount.project_id,
        client_email: serviceAccount.client_email,
        has_private_key: !!serviceAccount.private_key,
        access_token_obtained: true,
        access_token_preview: `${accessToken.substring(0, 20)}...`
      },
      hint: "Send a POST request with {\"token\": \"your-fcm-token\"} to test notification delivery"
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("❌ Function error:", error);
    return new Response(JSON.stringify({
      success: false,
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
