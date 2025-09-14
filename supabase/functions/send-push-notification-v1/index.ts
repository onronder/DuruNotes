/**
 * Unified Push Notification Handler v1
 * Consolidates all push notification processing with improved error handling
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { JWT } from "https://esm.sh/google-auth-library@8.7.0";
import { Logger } from "../common/logger.ts";
import { extractJwt } from "../common/auth.ts";
import {
  ApiError,
  ValidationError,
  AuthenticationError,
  RateLimitError,
  ServerError,
  errorResponse,
} from "../common/errors.ts";

const logger = new Logger("push-notification-v1");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/**
 * FCM Message Interface
 */
interface FcmMessage {
  token: string;
  notification?: {
    title: string;
    body: string;
  };
  data?: Record<string, string>;
  android?: {
    priority: "high" | "normal";
    notification?: {
      sound?: string;
      click_action?: string;
    };
  };
  apns?: {
    payload: {
      aps: {
        sound?: string;
        badge?: number;
      };
    };
  };
}

/**
 * Get FCM access token using service account
 */
async function getFcmAccessToken(): Promise<string> {
  const startTime = Date.now();
  
  try {
    const serviceAccountKey = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
    if (!serviceAccountKey) {
      throw new ServerError("FCM service account not configured");
    }
    
    const serviceAccount = JSON.parse(serviceAccountKey);
    
    const jwt = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    
    const token = await jwt.getAccessToken();
    
    logger.perf("fcm_token_obtained", startTime);
    
    return token.token || "";
  } catch (error) {
    logger.error("fcm_token_error", error as Error);
    throw new ServerError("Failed to obtain FCM token");
  }
}

/**
 * Send FCM notification
 */
async function sendFcmNotification(
  message: FcmMessage,
  accessToken: string,
  projectId: string
): Promise<{ success: boolean; error?: string }> {
  const startTime = Date.now();
  
  try {
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
    
    const responseText = await response.text();
    
    if (!response.ok) {
      // Handle specific FCM errors
      if (response.status === 404) {
        logger.warn("fcm_token_invalid", { token: message.token });
        return { success: false, error: "Invalid registration token" };
      }
      
      if (response.status === 429) {
        logger.warn("fcm_rate_limit");
        throw new RateLimitError();
      }
      
      logger.error("fcm_send_failed", responseText, {
        status: response.status,
        token: message.token,
      });
      
      return { success: false, error: responseText };
    }
    
    logger.perf("fcm_sent", startTime, { token: message.token });
    return { success: true };
    
  } catch (error) {
    if (error instanceof ApiError) throw error;
    
    logger.error("fcm_send_error", error as Error);
    return { success: false, error: String(error) };
  }
}

/**
 * Process a batch of notifications
 */
async function processBatch(
  supabase: any,
  batchSize: number = 50
): Promise<{
  processed: number;
  delivered: number;
  failed: number;
  errors: string[];
}> {
  const startTime = Date.now();
  const results = {
    processed: 0,
    delivered: 0,
    failed: 0,
    errors: [] as string[],
  };
  
  try {
    // Claim notifications atomically
    const { data: notifications, error: claimError } = await supabase
      .rpc("claim_notification_events", { batch_limit: batchSize });
    
    if (claimError) {
      logger.error("claim_notifications_error", claimError);
      throw new ServerError("Failed to claim notifications");
    }
    
    if (!notifications || notifications.length === 0) {
      logger.info("no_notifications_pending");
      return results;
    }
    
    logger.info("notifications_claimed", { count: notifications.length });
    
    // Get FCM access token
    const accessToken = await getFcmAccessToken();
    const projectId = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT_KEY") || "{}").project_id;
    
    if (!projectId) {
      throw new ServerError("FCM project ID not configured");
    }
    
    // Process each notification
    for (const notification of notifications) {
      results.processed++;
      
      try {
        // Get user devices
        const { data: devices, error: devicesError } = await supabase
          .rpc("get_user_device_tokens", { _user_id: notification.user_id });
        
        if (devicesError || !devices || devices.length === 0) {
          logger.warn("no_devices_found", { 
            user_id: notification.user_id,
            notification_id: notification.id 
          });
          
          await updateNotificationStatus(
            supabase,
            notification.id,
            "failed",
            "No devices found"
          );
          
          results.failed++;
          continue;
        }
        
        // Parse template
        const template = notification.notification_templates?.push_template || {};
        const payload = notification.payload || {};
        
        // Build notification content
        const title = interpolateTemplate(template.title || "Notification", payload);
        const body = interpolateTemplate(template.body || "", payload);
        
        let successCount = 0;
        const deliveryErrors: string[] = [];
        
        // Send to each device
        for (const device of devices) {
          const message: FcmMessage = {
            token: device.push_token,
            notification: { title, body },
            data: {
              notification_id: notification.id,
              event_type: notification.event_type,
              ...payload,
            },
            android: {
              priority: notification.priority === "critical" ? "high" : "normal",
              notification: {
                sound: template.sound || "default",
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: template.sound || "default",
                  badge: template.badge || 1,
                },
              },
            },
          };
          
          const result = await sendFcmNotification(message, accessToken, projectId);
          
          if (result.success) {
            successCount++;
            
            // Record delivery
            await supabase.from("notification_deliveries").insert({
              notification_event_id: notification.id,
              device_id: device.device_id,
              delivered_at: new Date().toISOString(),
              status: "delivered",
            });
          } else {
            deliveryErrors.push(result.error || "Unknown error");
            
            // Handle invalid tokens
            if (result.error?.includes("Invalid registration token")) {
              await supabase
                .from("user_devices")
                .delete()
                .eq("push_token", device.push_token);
              
              logger.info("invalid_token_removed", { 
                token: device.push_token 
              });
            }
          }
        }
        
        // Update notification status
        if (successCount > 0) {
          await updateNotificationStatus(
            supabase,
            notification.id,
            "delivered",
            null,
            { devices_sent: successCount }
          );
          results.delivered++;
        } else {
          await updateNotificationStatus(
            supabase,
            notification.id,
            "failed",
            deliveryErrors.join("; ")
          );
          results.failed++;
          results.errors.push(...deliveryErrors);
        }
        
      } catch (error) {
        logger.error("notification_processing_error", error as Error, {
          notification_id: notification.id,
        });
        
        await updateNotificationStatus(
          supabase,
          notification.id,
          "failed",
          String(error)
        );
        
        results.failed++;
        results.errors.push(String(error));
      }
    }
    
    logger.perf("batch_processed", startTime, results);
    return results;
    
  } catch (error) {
    logger.error("batch_processing_failed", error as Error);
    throw error;
  }
}

/**
 * Update notification status
 */
async function updateNotificationStatus(
  supabase: any,
  notificationId: string,
  status: string,
  errorMessage?: string | null,
  metadata?: Record<string, any>
): Promise<void> {
  const update: any = {
    status,
    updated_at: new Date().toISOString(),
  };
  
  if (status === "delivered") {
    update.delivered_at = new Date().toISOString();
  }
  
  if (errorMessage) {
    update.error_message = errorMessage;
  }
  
  if (metadata) {
    update.metadata = metadata;
  }
  
  const { error } = await supabase
    .from("notification_events")
    .update(update)
    .eq("id", notificationId);
  
  if (error) {
    logger.error("update_status_error", error, { 
      notification_id: notificationId 
    });
  }
}

/**
 * Interpolate template variables
 */
function interpolateTemplate(template: string, data: Record<string, any>): string {
  return template.replace(/\{\{(\w+)\}\}/g, (match, key) => {
    return data[key] || match;
  });
}

/**
 * Main request handler
 */
serve(async (req) => {
  const startTime = Date.now();
  
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  
  if (req.method !== "POST") {
    return errorResponse(
      new ApiError("Method not allowed", 405),
      corsHeaders
    );
  }
  
  try {
    // Verify authentication
    const jwt = extractJwt(req);
    
    if (!jwt) {
      // For service-to-service calls, we accept the auto-provided SUPABASE_SERVICE_ROLE_KEY
      // This is automatically set by Supabase and is the correct service role key
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      const authHeader = req.headers.get("authorization");
      
      if (!authHeader || !serviceKey) {
        logger.error("auth_missing", { 
          hasAuthHeader: !!authHeader,
          hasServiceKey: !!serviceKey 
        });
        throw new AuthenticationError("Missing authentication");
      }
      
      // Extract token from "Bearer <token>" format
      const token = authHeader.replace(/^Bearer\s+/i, "").trim();
      
      // The SUPABASE_SERVICE_ROLE_KEY from environment is the correct one
      if (token !== serviceKey) {
        logger.error("auth_mismatch", { 
          tokenLength: token.length,
          serviceKeyLength: serviceKey.length,
          tokenStart: token.substring(0, 20)
        });
        throw new AuthenticationError("Invalid service role key");
      }
    }
    
    // Parse request body
    const body = await req.json().catch(() => ({}));
    const batchSize = body.batch_size || 50;
    
    // Validate batch size
    if (batchSize < 1 || batchSize > 100) {
      throw new ValidationError("Batch size must be between 1 and 100");
    }
    
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    
    if (!supabaseUrl || !serviceKey) {
      throw new ServerError("Supabase configuration missing");
    }
    
    const supabase = createClient(supabaseUrl, serviceKey);
    
    // Process notifications
    const results = await processBatch(supabase, batchSize);
    
    logger.perf("request_completed", startTime, results);
    
    return new Response(JSON.stringify(results), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
    
  } catch (error) {
    logger.error("request_failed", error as Error, {
      duration_ms: Date.now() - startTime,
    });
    
    return errorResponse(error as Error, corsHeaders);
  }
});