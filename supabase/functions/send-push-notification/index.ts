import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

// CORS headers for browser requests
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// FCM API endpoint
const FCM_API_URL = "https://fcm.googleapis.com/v1/projects/{project-id}/messages:send";

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

// Get FCM access token using service account
async function getFCMAccessToken(): Promise<string | null> {
  try {
    // This would typically use a service account JSON key
    // For production, store this securely in Supabase Vault
    const serviceAccount = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
    if (!serviceAccount) {
      log("error", "fcm_auth_missing", { reason: "FCM_SERVICE_ACCOUNT_KEY not configured" });
      return null;
    }

    // Parse service account
    const sa = JSON.parse(serviceAccount);
    
    // Create JWT for OAuth2
    const header = {
      alg: "RS256",
      typ: "JWT",
    };
    
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: sa.client_email,
      sub: sa.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600, // 1 hour
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    };
    
    // Sign JWT with private key (simplified - in production use proper JWT library)
    // For now, we'll use the legacy FCM API as fallback
    return null;
  } catch (error) {
    log("error", "fcm_auth_failed", { error: String(error) });
    return null;
  }
}

// Send push notification via FCM (legacy HTTP API for simplicity)
async function sendFCMNotification(
  token: string,
  title: string,
  body: string,
  data: Record<string, any> = {},
  options: Record<string, any> = {}
): Promise<{ success: boolean; error?: string; messageId?: string }> {
  try {
    const serverKey = Deno.env.get("FCM_SERVER_KEY");
    if (!serverKey) {
      return { success: false, error: "FCM_SERVER_KEY not configured" };
    }

    const message = {
      to: token,
      notification: {
        title,
        body,
        sound: options.sound || "default",
        badge: options.badge || 1,
        icon: options.icon || "notification_icon",
        click_action: options.clickAction || "FLUTTER_NOTIFICATION_CLICK",
      },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        notification_id: crypto.randomUUID(),
        timestamp: new Date().toISOString(),
      },
      priority: options.priority === "critical" ? "high" : "normal",
      content_available: true,
      mutable_content: true,
    };

    const response = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Authorization": `key=${serverKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    });

    const result = await response.json();

    if (response.ok && result.success === 1) {
      return { 
        success: true, 
        messageId: result.results?.[0]?.message_id 
      };
    } else {
      const error = result.results?.[0]?.error || "Unknown FCM error";
      return { 
        success: false, 
        error 
      };
    }
  } catch (error) {
    return { 
      success: false, 
      error: String(error) 
    };
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
    },
  };
}

// Calculate next retry time with exponential backoff
function calculateNextRetry(retryCount: number): Date {
  const delays = [30, 120, 600, 3600]; // 30s, 2m, 10m, 1h
  const delaySeconds = delays[Math.min(retryCount, delays.length - 1)];
  return new Date(Date.now() + delaySeconds * 1000);
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

    // Process specific event or batch
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
      // Process batch of pending events
      const { data, error } = await supabase
        .from("notification_events")
        .select("*, notification_templates!inner(*)")
        .eq("status", "pending")
        .lte("scheduled_for", new Date().toISOString())
        .order("priority", { ascending: false })
        .order("scheduled_for", { ascending: true })
        .limit(batch_size);

      if (error) {
        log("error", "batch_fetch_failed", { error: error.message });
        return new Response(
          JSON.stringify({ error: "Failed to fetch events" }), 
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      events = data || [];
    }

    // Process each event
    const results = [];
    for (const event of events) {
      const eventStartTime = Date.now();
      
      try {
        // Update status to processing
        await supabase
          .from("notification_events")
          .update({ 
            status: "processing",
            processed_at: new Date().toISOString(),
          })
          .eq("id", event.id);

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

        // Check quiet hours
        if (preferences?.quiet_hours_enabled) {
          const now = new Date();
          const userTime = new Date(now.toLocaleString("en-US", { timeZone: preferences.timezone || "UTC" }));
          const currentTime = `${userTime.getHours().toString().padStart(2, "0")}:${userTime.getMinutes().toString().padStart(2, "0")}`;
          
          if (
            preferences.quiet_hours_start && 
            preferences.quiet_hours_end &&
            currentTime >= preferences.quiet_hours_start &&
            currentTime <= preferences.quiet_hours_end
          ) {
            // Reschedule for after quiet hours
            const [endHour, endMinute] = preferences.quiet_hours_end.split(":").map(Number);
            const rescheduledTime = new Date();
            rescheduledTime.setHours(endHour, endMinute + 1, 0, 0);
            
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

        // Get user's device tokens
        const { data: devices } = await supabase
          .from("user_devices")
          .select("*")
          .eq("user_id", event.user_id)
          .order("updated_at", { ascending: false });

        if (!devices || devices.length === 0) {
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
          continue;
        }

        // Process template with event payload
        const { title, body, options } = processTemplate(
          template.push_template,
          event.payload
        );

        // Send to all devices
        let successCount = 0;
        let failureCount = 0;
        const deliveryAttempts = [];

        for (const device of devices) {
          const deliveryStartTime = Date.now();
          
          try {
            // Send push notification
            const result = await sendFCMNotification(
              device.push_token,
              title,
              body,
              {
                event_id: event.id,
                event_type: event.event_type,
                ...event.payload,
              },
              { ...options, priority: event.priority }
            );

            // Record delivery attempt
            const deliveryRecord = {
              event_id: event.id,
              user_id: event.user_id,
              channel: "push",
              device_id: device.device_id,
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
              
              // Handle invalid token
              if (result.error === "InvalidRegistration" || result.error === "NotRegistered") {
                // Remove invalid token
                await supabase
                  .from("user_devices")
                  .delete()
                  .eq("id", device.id);
                
                log("info", "invalid_token_removed", {
                  device_id: device.device_id,
                  user_id: event.user_id,
                });
              }
            }

            deliveryAttempts.push({
              device_id: device.device_id,
              platform: device.platform,
              success: result.success,
              error: result.error,
              duration_ms: Date.now() - deliveryStartTime,
            });
          } catch (error) {
            failureCount++;
            log("error", "delivery_exception", {
              event_id: event.id,
              device_id: device.device_id,
              error: String(error),
            });
          }
        }

        // Update event status based on results
        let finalStatus;
        let errorMessage = null;
        
        if (successCount > 0) {
          finalStatus = "delivered";
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
        }

        if (finalStatus !== "pending") {
          await supabase
            .from("notification_events")
            .update({ 
              status: finalStatus,
              error_message: errorMessage,
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
      }
    }

    // Log batch processing complete
    log("info", "batch_processed", {
      events_processed: events.length,
      results,
      total_duration_ms: Date.now() - startTime,
    });

    return new Response(
      JSON.stringify({
        processed: events.length,
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
