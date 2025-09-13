import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

// CORS headers for browser requests
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Cache for access token to avoid unnecessary token generation
let cachedAccessToken: { token: string; expiry: number } | null = null;

// Structured logging helper
function log(level: string, event: string, data: Record<string, any> = {}) {
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    event,
    ...data,
    edge_region: Deno.env.get("DENO_REGION") || "unknown",
    project_ref: Deno.env.get("SUPABASE_PROJECT_REF") || "unknown",
  };
  
  if (level === "error") {
    console.error(JSON.stringify(logEntry));
  } else {
    console.log(JSON.stringify(logEntry));
  }
}

// Base64 URL encoding helper
function base64url(source: ArrayBuffer): string {
  const base64 = btoa(String.fromCharCode(...new Uint8Array(source)));
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// Create JWT manually for Service Account authentication
async function createServiceAccountJWT(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  
  const header = {
    alg: "RS256",
    typ: "JWT",
    kid: serviceAccount.private_key_id
  };
  
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600, // 1 hour
    scope: "https://www.googleapis.com/auth/firebase.messaging"
  };
  
  // Encode header and payload
  const encodedHeader = base64url(new TextEncoder().encode(JSON.stringify(header)));
  const encodedPayload = base64url(new TextEncoder().encode(JSON.stringify(payload)));
  const signatureInput = `${encodedHeader}.${encodedPayload}`;
  
  // Import private key for signing
  const privateKey = serviceAccount.private_key
    .replace(/\\n/g, '\n')
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  
  const binaryKey = Uint8Array.from(atob(privateKey), c => c.charCodeAt(0));
  
  // Import key using WebCrypto API
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );
  
  // Sign the JWT
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signatureInput)
  );
  
  // Combine all parts
  const jwt = `${signatureInput}.${base64url(signature)}`;
  return jwt;
}

// Get FCM v1 access token using service account with caching
async function getFCMAccessToken(): Promise<string | null> {
  try {
    // Check cache first
    if (cachedAccessToken && cachedAccessToken.expiry > Date.now() + 60000) {
      // Still valid for at least 1 minute
      return cachedAccessToken.token;
    }
    
    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
    if (!serviceAccountJson) {
      log("error", "fcm_auth_missing", { reason: "FCM_SERVICE_ACCOUNT_KEY not configured" });
      return null;
    }

    // Parse service account
    const serviceAccount = JSON.parse(serviceAccountJson);
    
    // Create JWT
    const jwt = await createServiceAccountJWT(serviceAccount);
    
    // Exchange JWT for access token
    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      log("error", "oauth_token_failed", { 
        status: response.status,
        error 
      });
      return null;
    }

    const data = await response.json();
    
    // Cache the token (expires_in is in seconds)
    cachedAccessToken = {
      token: data.access_token,
      expiry: Date.now() + (data.expires_in * 1000)
    };
    
    log("info", "oauth_token_obtained", { 
      expires_in: data.expires_in 
    });
    
    return data.access_token;
  } catch (error) {
    log("error", "fcm_auth_exception", { error: String(error) });
    return null;
  }
}

// Send push notification via FCM v1 API with batch support
async function sendFCMv1Notification(
  tokens: Array<{ token: string; device_id: string }>,
  title: string,
  body: string,
  data: Record<string, any> = {},
  options: Record<string, any> = {}
): Promise<Array<{ device_id: string; success: boolean; error?: string; messageId?: string }>> {
  try {
    // Get OAuth2 access token
    const accessToken = await getFCMAccessToken();
    if (!accessToken) {
      return tokens.map(t => ({ 
        device_id: t.device_id, 
        success: false, 
        error: "Failed to get FCM access token" 
      }));
    }

    // Get project ID from service account
    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
    const serviceAccount = JSON.parse(serviceAccountJson!);
    const projectId = serviceAccount.project_id;

    // Process tokens in batches (FCM v1 doesn't support batch, so we'll use Promise.all)
    const results = await Promise.all(
      tokens.map(async ({ token, device_id }) => {
        try {
          // Build FCM v1 message with consistent payload
          const message = {
            message: {
              token,
              notification: {
                title,
                body,
              },
              data: {
                ...data,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                notification_id: crypto.randomUUID(),
                timestamp: new Date().toISOString(),
              },
              android: {
                priority: options.priority === "critical" ? "HIGH" : "NORMAL",
                notification: {
                  sound: options.sound || "default",
                  icon: options.icon || "notification_icon",
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                  channel_id: options.channel_id || "default",
                },
              },
              apns: {
                payload: {
                  aps: {
                    alert: {
                      title,
                      body,
                    },
                    sound: options.sound || "default",
                    badge: options.badge || 1,
                    "content-available": 1,
                    "mutable-content": 1,
                  },
                },
              },
            },
          };

          // Send to FCM v1 endpoint
          const response = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${accessToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify(message),
            }
          );

          const result = await response.json();

          if (response.ok && result.name) {
            return { 
              device_id,
              success: true, 
              messageId: result.name,
            };
          } else {
            const error = result.error?.message || "Unknown FCM error";
            const errorCode = result.error?.code;
            
            log("warning", "fcm_send_failed", { 
              device_id,
              status: response.status,
              error_code: errorCode,
              error: result.error,
            });
            
            return { 
              device_id,
              success: false, 
              error,
              errorCode,
            };
          }
        } catch (error) {
          log("error", "fcm_send_exception", { 
            device_id,
            error: String(error) 
          });
          return { 
            device_id,
            success: false, 
            error: String(error),
          };
        }
      })
    );

    return results;
  } catch (error) {
    log("error", "fcm_batch_exception", { error: String(error) });
    return tokens.map(t => ({ 
      device_id: t.device_id, 
      success: false, 
      error: String(error) 
    }));
  }
}

// Process notification template with variable substitution
function processTemplate(template: any, variables: Record<string, any>): { title: string; body: string; options: any } {
  let title = template.title || "Notification";
  let body = template.body || "";
  
  // Simple variable substitution
  Object.entries(variables).forEach(([key, value]) => {
    const placeholder = `{{${key}}}`;
    title = title.replace(new RegExp(placeholder, "g"), String(value));
    body = body.replace(new RegExp(placeholder, "g"), String(value));
  });
  
  return {
    title,
    body,
    options: {
      icon: template.icon,
      sound: template.sound,
      badge: template.badge,
      priority: template.priority,
      channel_id: template.channel_id,
    },
  };
}

// Calculate next retry time with exponential backoff
function calculateNextRetry(retryCount: number): Date {
  const delays = [30, 120, 600, 3600]; // 30s, 2m, 10m, 1h
  const delaySeconds = delays[Math.min(retryCount, delays.length - 1)];
  return new Date(Date.now() + delaySeconds * 1000);
}

// Check if current time is in quiet hours (handles overnight spans)
function isInQuietHours(
  startTime: string, 
  endTime: string, 
  timezone: string = "UTC"
): boolean {
  const now = new Date();
  const userTime = new Date(now.toLocaleString("en-US", { timeZone: timezone }));
  const currentMinutes = userTime.getHours() * 60 + userTime.getMinutes();
  
  const [startHour, startMin] = startTime.split(":").map(Number);
  const [endHour, endMin] = endTime.split(":").map(Number);
  
  const startMinutes = startHour * 60 + startMin;
  const endMinutes = endHour * 60 + endMin;
  
  // Handle overnight spans (e.g., 22:00 to 07:00)
  if (startMinutes > endMinutes) {
    // Quiet hours span midnight
    return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
  } else {
    // Normal daytime span
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }
}

// Main handler
serve(async (req) => {
  const startTime = Date.now();
  
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Only allow POST
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }

  try {
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceKey) {
      log("error", "config_missing", { 
        error: "Missing Supabase configuration" 
      });
      return new Response(
        JSON.stringify({ error: "Server misconfigured" }), 
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, serviceKey);

    // Parse request body
    const body = await req.json();
    const { event_id, batch_size = 10 } = body;

    // Process specific event or batch with atomic claim
    let events;
    if (event_id) {
      // Process specific event
      const { data, error } = await supabase
        .from("notification_events")
        .select("*, notification_templates!inner(*)")
        .eq("id", event_id)
        .single();

      if (error || !data) {
        log("error", "event_not_found", { event_id, error: error?.message });
        return new Response(
          JSON.stringify({ error: "Event not found" }), 
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      events = [data];
    } else {
      // Atomic claim of pending events with FOR UPDATE SKIP LOCKED
      const { data: claimedEvents, error: claimError } = await supabase.rpc(
        'claim_notification_events',
        { batch_limit: batch_size }
      );

      if (claimError) {
        log("error", "claim_failed", { error: claimError.message });
        // Fallback to non-atomic query if RPC doesn't exist yet
        const { data, error } = await supabase
          .from("notification_events")
          .select("*, notification_templates!inner(*)")
          .eq("status", "pending")
          .lte("scheduled_for", new Date().toISOString())
          .order("priority", { ascending: false })
          .order("scheduled_for", { ascending: true })
          .limit(batch_size);
        
        events = data || [];
      } else {
        events = claimedEvents || [];
      }
    }

    // Process each event
    const results = [];
    let totalDelivered = 0;
    let totalFailed = 0;
    
    for (const event of events) {
      const eventStartTime = Date.now();
      
      try {
        // Check user preferences
        const { data: preferences } = await supabase
          .from("notification_preferences")
          .select("*")
          .eq("user_id", event.user_id)
          .single();

        // Skip if notifications disabled
        if (preferences && !preferences.enabled) {
          await supabase
            .from("notification_events")
            .update({ 
              status: "cancelled",
              error_message: "User has disabled notifications",
            })
            .eq("id", event.id);
          
          results.push({
            event_id: event.id,
            status: "cancelled",
            reason: "user_disabled",
          });
          continue;
        }

        // Check quiet hours (fixed for overnight spans)
        if (preferences?.quiet_hours_enabled) {
          if (isInQuietHours(
            preferences.quiet_hours_start,
            preferences.quiet_hours_end,
            preferences.timezone || "UTC"
          )) {
            // Reschedule for after quiet hours
            const [endHour, endMinute] = preferences.quiet_hours_end.split(":").map(Number);
            const rescheduledTime = new Date();
            rescheduledTime.setHours(endHour, endMinute + 1, 0, 0);
            
            // If rescheduled time is in the past (for overnight spans), add a day
            if (rescheduledTime <= new Date()) {
              rescheduledTime.setDate(rescheduledTime.getDate() + 1);
            }
            
            await supabase
              .from("notification_events")
              .update({ 
                status: "pending",
                scheduled_for: rescheduledTime.toISOString(),
                error_message: "Rescheduled due to quiet hours",
              })
              .eq("id", event.id);
            
            results.push({
              event_id: event.id,
              status: "rescheduled",
              reason: "quiet_hours",
              next_attempt: rescheduledTime.toISOString(),
            });
            continue;
          }
        }

        // Check DND
        if (preferences?.dnd_enabled && preferences.dnd_until) {
          const dndEnd = new Date(preferences.dnd_until);
          if (new Date() < dndEnd) {
            await supabase
              .from("notification_events")
              .update({ 
                status: "pending",
                scheduled_for: dndEnd.toISOString(),
                error_message: "Rescheduled due to DND",
              })
              .eq("id", event.id);
            
            results.push({
              event_id: event.id,
              status: "rescheduled",
              reason: "dnd",
              next_attempt: dndEnd.toISOString(),
            });
            continue;
          }
        }

        // Get user's device tokens
        const { data: devices } = await supabase
          .from("user_devices")
          .select("*")
          .eq("user_id", event.user_id)
          .order("updated_at", { ascending: false });

        if (!devices || devices.length === 0) {
          // Check for email fallback preference
          if (preferences?.email_enabled) {
            // Add stub for email fallback
            await supabase
              .from("notification_events")
              .update({ 
                status: "pending",
                error_message: "No push tokens, queued for email delivery",
                error_details: { fallback: "email" }
              })
              .eq("id", event.id);
            
            results.push({
              event_id: event.id,
              status: "fallback",
              channel: "email",
              reason: "no_devices",
            });
          } else {
            await supabase
              .from("notification_events")
              .update({ 
                status: "failed",
                error_message: "No device tokens found for user",
              })
              .eq("id", event.id);
            
            results.push({
              event_id: event.id,
              status: "failed",
              reason: "no_devices",
            });
            totalFailed++;
          }
          continue;
        }

        // Get notification template
        const template = event.notification_templates;
        if (!template || !template.push_template) {
          await supabase
            .from("notification_events")
            .update({ 
              status: "failed",
              error_message: "No push template configured",
            })
            .eq("id", event.id);
          
          results.push({
            event_id: event.id,
            status: "failed",
            reason: "no_template",
          });
          totalFailed++;
          continue;
        }

        // Process template with event payload
        const { title, body, options } = processTemplate(
          template.push_template,
          event.payload
        );

        // Prepare tokens for batch sending
        const tokenBatch = devices.map(d => ({
          token: d.push_token,
          device_id: d.device_id
        }));

        // Build consistent payload
        const notificationData = {
          event_id: event.id,
          event_type: event.event_type,
          event_source: event.event_source,
          // Add navigation hints
          ...(event.payload.note_id && { note_id: event.payload.note_id }),
          ...(event.payload.reminder_id && { reminder_id: event.payload.reminder_id }),
          ...(event.payload.inbox_id && { inbox_id: event.payload.inbox_id }),
          ...(event.payload.url && { url: event.payload.url }),
          ...event.payload,
        };

        // Send to all devices in batch
        const deliveryResults = await sendFCMv1Notification(
          tokenBatch,
          title,
          body,
          notificationData,
          { ...options, priority: event.priority }
        );

        // Process results
        let successCount = 0;
        let failureCount = 0;
        const deliveryAttempts = [];

        for (const result of deliveryResults) {
          const device = devices.find(d => d.device_id === result.device_id);
          if (!device) continue;

          // Record delivery attempt
          const deliveryRecord = {
            event_id: event.id,
            user_id: event.user_id,
            channel: "push",
            device_id: result.device_id,
            status: result.success ? "delivered" : "failed",
            provider_response: result,
            provider_message_id: result.messageId,
            error_code: result.error,
            error_message: result.error,
            delivered_at: result.success ? new Date().toISOString() : null,
            failed_at: !result.success ? new Date().toISOString() : null,
          };

          await supabase
            .from("notification_deliveries")
            .insert(deliveryRecord);

          if (result.success) {
            successCount++;
          } else {
            failureCount++;
            
            // Handle invalid token (clean up)
            if (result.errorCode === "UNREGISTERED" || 
                result.errorCode === "INVALID_ARGUMENT" ||
                result.error?.includes("registration token is not valid")) {
              // Remove invalid token
              await supabase
                .from("user_devices")
                .delete()
                .eq("id", device.id);
              
              log("info", "invalid_token_removed", {
                device_id: device.device_id,
                user_id: event.user_id,
                error: result.error,
              });
            }
          }

          deliveryAttempts.push({
            device_id: device.device_id,
            platform: device.platform,
            success: result.success,
            error: result.error,
          });
        }

        // Update event status based on results
        let finalStatus;
        let errorMessage = null;
        
        if (successCount > 0) {
          finalStatus = "delivered";
          totalDelivered++;
        } else if (event.retry_count < event.max_retries) {
          // Schedule retry
          finalStatus = "pending";
          const nextRetry = calculateNextRetry(event.retry_count);
          
          await supabase
            .from("notification_events")
            .update({ 
              status: "pending",
              retry_count: event.retry_count + 1,
              scheduled_for: nextRetry.toISOString(),
              error_message: `Delivery failed to all devices. Retry ${event.retry_count + 1}/${event.max_retries}`,
            })
            .eq("id", event.id);
        } else {
          finalStatus = "failed";
          errorMessage = "Max retries exceeded";
          totalFailed++;
          
          // Check for email fallback on final failure
          if (preferences?.email_enabled) {
            // Queue for email delivery (stub)
            await supabase
              .from("notification_events")
              .update({ 
                error_details: { 
                  push_failed: true, 
                  fallback_to_email: true 
                }
              })
              .eq("id", event.id);
          }
        }

        if (finalStatus !== "pending") {
          await supabase
            .from("notification_events")
            .update({ 
              status: finalStatus,
              error_message: errorMessage,
              processed_at: new Date().toISOString(),
            })
            .eq("id", event.id);
        }

        results.push({
          event_id: event.id,
          status: finalStatus,
          devices_attempted: devices.length,
          devices_succeeded: successCount,
          devices_failed: failureCount,
          delivery_attempts: deliveryAttempts,
          duration_ms: Date.now() - eventStartTime,
        });

        // Log event processing
        log("info", "event_processed", {
          event_id: event.id,
          event_type: event.event_type,
          user_id: event.user_id,
          status: finalStatus,
          devices_attempted: devices.length,
          devices_succeeded: successCount,
          devices_failed: failureCount,
          duration_ms: Date.now() - eventStartTime,
        });
      } catch (error) {
        // Handle unexpected errors
        log("error", "event_processing_failed", {
          event_id: event.id,
          error: String(error),
        });

        await supabase
          .from("notification_events")
          .update({ 
            status: "failed",
            error_message: String(error),
            error_details: { error: String(error), stack: error.stack },
          })
          .eq("id", event.id);

        results.push({
          event_id: event.id,
          status: "failed",
          error: String(error),
        });
        totalFailed++;
      }
    }

    // Calculate delivery rate
    const deliveryRate = events.length > 0 
      ? Math.round((totalDelivered / events.length) * 100) 
      : 0;

    // Log batch metrics
    log("info", "batch_processed", {
      events_processed: events.length,
      delivered: totalDelivered,
      failed: totalFailed,
      delivery_rate_percent: deliveryRate,
      total_duration_ms: Date.now() - startTime,
    });

    return new Response(
      JSON.stringify({
        processed: events.length,
        delivered: totalDelivered,
        failed: totalFailed,
        delivery_rate: `${deliveryRate}%`,
        results,
        duration_ms: Date.now() - startTime,
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  } catch (error) {
    log("error", "handler_error", {
      error: String(error),
      stack: error.stack,
    });

    return new Response(
      JSON.stringify({ 
        error: "Internal server error",
        details: String(error),
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});