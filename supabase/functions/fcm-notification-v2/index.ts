/**
 * Production-Grade FCM Notification Handler v2.0
 * Enhanced with advanced error handling, circuit breakers, and observability
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts";
import { Logger } from "../common/logger.ts";
import { extractJwt, verifyHmacSignature } from "../common/auth.ts";
import {
  ApiError,
  ValidationError,
  AuthenticationError,
  RateLimitError,
  ServerError,
  errorResponse,
} from "../common/errors.ts";
import { CircuitBreaker } from "../common/circuit-breaker.ts";
import { MetricsCollector } from "../common/metrics.ts";
import { RetryPolicy } from "../common/retry.ts";

const logger = new Logger("fcm-notification-v2");
const metrics = new MetricsCollector("fcm_notifications");

// Circuit breaker for FCM API calls
const fcmCircuitBreaker = new CircuitBreaker({
  failureThreshold: 5,
  recoveryTimeout: 30000,
  monitoringPeriod: 60000,
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/**
 * Enhanced FCM Message Interface with platform-specific optimizations
 */
interface EnhancedFcmMessage {
  token: string;
  notification?: {
    title: string;
    body: string;
    image?: string;
  };
  data?: Record<string, string>;
  android?: {
    priority: "high" | "normal";
    collapse_key?: string;
    ttl?: number;
    notification?: {
      sound?: string;
      click_action?: string;
      icon?: string;
      color?: string;
      tag?: string;
      sticky?: boolean;
      local_only?: boolean;
      default_sound?: boolean;
      default_vibrate_timings?: boolean;
      default_light_settings?: boolean;
      vibrate_timings?: string[];
      visibility?: "private" | "public" | "secret";
      notification_count?: number;
    };
    fcm_options?: {
      analytics_label?: string;
    };
  };
  apns?: {
    headers?: {
      "apns-priority"?: "5" | "10";
      "apns-expiration"?: string;
      "apns-collapse-id"?: string;
    };
    payload: {
      aps: {
        alert?: {
          title?: string;
          subtitle?: string;
          body?: string;
          "launch-image"?: string;
          "title-loc-key"?: string;
          "title-loc-args"?: string[];
          "subtitle-loc-key"?: string;
          "subtitle-loc-args"?: string[];
          "loc-key"?: string;
          "loc-args"?: string[];
        };
        badge?: number;
        sound?: string | {
          critical?: number;
          name?: string;
          volume?: number;
        };
        "thread-id"?: string;
        category?: string;
        "content-available"?: number;
        "mutable-content"?: number;
        "target-content-id"?: string;
        "interruption-level"?: "passive" | "active" | "time-sensitive" | "critical";
        "relevance-score"?: number;
      };
    };
    fcm_options?: {
      analytics_label?: string;
      image?: string;
    };
  };
  webpush?: {
    headers?: Record<string, string>;
    data?: Record<string, any>;
    notification?: {
      title?: string;
      body?: string;
      icon?: string;
      image?: string;
      badge?: string;
      vibrate?: number[];
      timestamp?: number;
      renotify?: boolean;
      silent?: boolean;
      require_interaction?: boolean;
      tag?: string;
      actions?: Array<{
        action: string;
        title: string;
        icon?: string;
      }>;
    };
    fcm_options?: {
      link?: string;
      analytics_label?: string;
    };
  };
  fcm_options?: {
    analytics_label?: string;
  };
}

/**
 * FCM Token Management with validation and cleanup
 */
class FcmTokenManager {
  private supabase: any;

  constructor(supabase: any) {
    this.supabase = supabase;
  }

  async validateAndCleanupTokens(tokens: string[]): Promise<string[]> {
    const validTokens: string[] = [];
    const invalidTokens: string[] = [];

    for (const token of tokens) {
      if (await this.isTokenValid(token)) {
        validTokens.push(token);
      } else {
        invalidTokens.push(token);
      }
    }

    // Cleanup invalid tokens
    if (invalidTokens.length > 0) {
      await this.removeInvalidTokens(invalidTokens);
    }

    return validTokens;
  }

  private async isTokenValid(token: string): Promise<boolean> {
    // Basic token format validation
    if (!token || token.length < 152 || token.length > 1024) {
      return false;
    }

    // Check if token is marked as invalid in our database
    const { data } = await this.supabase
      .from("invalid_tokens")
      .select("token")
      .eq("token", token)
      .maybeSingle();

    return !data;
  }

  private async removeInvalidTokens(tokens: string[]): Promise<void> {
    // Remove from user_devices
    await this.supabase
      .from("user_devices")
      .delete()
      .in("push_token", tokens);

    // Add to invalid_tokens blacklist
    const invalidTokenRecords = tokens.map(token => ({
      token,
      invalidated_at: new Date().toISOString(),
    }));

    await this.supabase
      .from("invalid_tokens")
      .upsert(invalidTokenRecords);

    logger.info("invalid_tokens_cleaned", { count: tokens.length });
  }
}

/**
 * Enhanced FCM Service with advanced features
 */
class EnhancedFcmService {
  private accessToken: string | null = null;
  private tokenExpiry: number = 0;
  private projectId: string;
  private retryPolicy: RetryPolicy;

  constructor(projectId: string) {
    this.projectId = projectId;
    this.retryPolicy = new RetryPolicy({
      maxRetries: 3,
      baseDelay: 1000,
      maxDelay: 10000,
      backoffMultiplier: 2,
      jitter: true,
    });
  }

  async getAccessToken(): Promise<string> {
    const startTime = Date.now();

    // Return cached token if still valid
    if (this.accessToken && Date.now() < this.tokenExpiry) {
      return this.accessToken;
    }

    try {
      const serviceAccountKey = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
      if (!serviceAccountKey) {
        throw new ServerError("FCM service account not configured");
      }

      const serviceAccount = JSON.parse(serviceAccountKey);

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
        throw new ServerError(`Failed to exchange JWT for access token: ${error}`);
      }

      const tokenData = await tokenResponse.json();
      this.accessToken = tokenData.access_token;
      // Cache token for 50 minutes (tokens expire in 1 hour)
      this.tokenExpiry = Date.now() + (50 * 60 * 1000);

      metrics.incrementCounter("fcm_token_refreshed");
      logger.perf("fcm_token_obtained", startTime);

      return this.accessToken;
    } catch (error) {
      metrics.incrementCounter("fcm_token_error");
      logger.error("fcm_token_error", error as Error);
      throw new ServerError("Failed to obtain FCM token");
    }
  }

  async sendNotification(message: EnhancedFcmMessage): Promise<{
    success: boolean;
    error?: string;
    errorCode?: string;
    retryAfter?: number;
  }> {
    const startTime = Date.now();

    try {
      const accessToken = await this.getAccessToken();

      const result = await fcmCircuitBreaker.execute(async () => {
        return await this.retryPolicy.execute(async () => {
          return await this.performSend(message, accessToken);
        });
      });

      metrics.recordLatency("fcm_send_duration", Date.now() - startTime);
      metrics.incrementCounter("fcm_send_success");

      return result;
    } catch (error) {
      metrics.incrementCounter("fcm_send_error");
      logger.error("fcm_send_failed", error as Error, {
        token: message.token.substring(0, 20) + "...",
      });

      if (error instanceof RateLimitError) {
        return {
          success: false,
          error: "Rate limit exceeded",
          errorCode: "RATE_LIMIT",
          retryAfter: 60000,
        };
      }

      return {
        success: false,
        error: error instanceof Error ? error.message : String(error),
        errorCode: "SEND_FAILED",
      };
    }
  }

  private async performSend(
    message: EnhancedFcmMessage,
    accessToken: string
  ): Promise<{ success: boolean; error?: string; errorCode?: string }> {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${this.projectId}/messages:send`,
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
      const responseData = await response.json();
      logger.debug("fcm_send_success", {
        messageId: responseData.name,
        token: message.token.substring(0, 20) + "...",
      });
      return { success: true };
    }

    const errorText = await response.text();

    // Handle specific FCM error codes
    switch (response.status) {
      case 400:
        if (errorText.includes("INVALID_ARGUMENT")) {
          return {
            success: false,
            error: "Invalid message format",
            errorCode: "INVALID_ARGUMENT",
          };
        }
        break;

      case 401:
        // Clear cached token
        this.accessToken = null;
        this.tokenExpiry = 0;
        throw new AuthenticationError("FCM authentication failed");

      case 403:
        return {
          success: false,
          error: "Insufficient permissions",
          errorCode: "FORBIDDEN",
        };

      case 404:
        return {
          success: false,
          error: "Invalid registration token",
          errorCode: "INVALID_TOKEN",
        };

      case 429:
        throw new RateLimitError();

      case 500:
      case 502:
      case 503:
      case 504:
        throw new ServerError(`FCM server error: ${response.status}`);

      default:
        logger.warn("fcm_unexpected_error", {
          status: response.status,
          body: errorText,
        });
    }

    return {
      success: false,
      error: errorText,
      errorCode: "UNKNOWN_ERROR",
    };
  }

  async sendBulkNotifications(
    messages: EnhancedFcmMessage[]
  ): Promise<{
    successful: number;
    failed: number;
    results: Array<{ success: boolean; error?: string; messageIndex: number }>;
  }> {
    const results = await Promise.allSettled(
      messages.map((message, index) =>
        this.sendNotification(message).then(result => ({
          ...result,
          messageIndex: index,
        }))
      )
    );

    const processedResults = results.map((result, index) => {
      if (result.status === "fulfilled") {
        return result.value;
      } else {
        return {
          success: false,
          error: result.reason?.message || "Unknown error",
          messageIndex: index,
        };
      }
    });

    const successful = processedResults.filter(r => r.success).length;
    const failed = processedResults.length - successful;

    metrics.recordGauge("fcm_bulk_successful", successful);
    metrics.recordGauge("fcm_bulk_failed", failed);

    return {
      successful,
      failed,
      results: processedResults,
    };
  }
}

/**
 * Enhanced notification processing with advanced features
 */
async function processNotificationBatch(
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
    // Claim notifications with priority ordering
    const { data: notifications, error: claimError } = await supabase
      .rpc("claim_priority_notification_events", {
        batch_limit: batchSize,
        max_age_minutes: 60 // Don't process notifications older than 1 hour
      });

    if (claimError) {
      logger.error("claim_notifications_error", claimError);
      throw new ServerError("Failed to claim notifications");
    }

    if (!notifications || notifications.length === 0) {
      logger.debug("no_notifications_pending");
      return results;
    }

    logger.info("notifications_claimed", { count: notifications.length });

    // Initialize services
    const projectId = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT_KEY") || "{}").project_id;
    if (!projectId) {
      throw new ServerError("FCM project ID not configured");
    }

    const fcmService = new EnhancedFcmService(projectId);
    const tokenManager = new FcmTokenManager(supabase);

    // Group notifications by user for efficiency
    const userNotifications = new Map<string, any[]>();
    for (const notification of notifications) {
      const userId = notification.user_id;
      if (!userNotifications.has(userId)) {
        userNotifications.set(userId, []);
      }
      userNotifications.get(userId)!.push(notification);
    }

    // Process each user's notifications
    for (const [userId, userNotifs] of userNotifications) {
      for (const notification of userNotifs) {
        results.processed++;

        try {
          // Get and validate user devices
          const { data: devices, error: devicesError } = await supabase
            .rpc("get_active_user_devices", { _user_id: userId });

          if (devicesError || !devices || devices.length === 0) {
            await updateNotificationStatus(
              supabase,
              notification.id,
              "failed",
              "No active devices found"
            );
            results.failed++;
            continue;
          }

          // Validate and cleanup tokens
          const tokens = devices.map((d: any) => d.push_token);
          const validTokens = await tokenManager.validateAndCleanupTokens(tokens);

          if (validTokens.length === 0) {
            await updateNotificationStatus(
              supabase,
              notification.id,
              "failed",
              "No valid device tokens"
            );
            results.failed++;
            continue;
          }

          // Build enhanced notification messages
          const messages = await buildEnhancedMessages(
            notification,
            devices.filter((d: any) => validTokens.includes(d.push_token))
          );

          // Send notifications
          const sendResult = await fcmService.sendBulkNotifications(messages);

          // Record deliveries
          await recordDeliveryResults(
            supabase,
            notification.id,
            devices,
            sendResult.results
          );

          // Update notification status
          if (sendResult.successful > 0) {
            await updateNotificationStatus(
              supabase,
              notification.id,
              "delivered",
              null,
              {
                devices_sent: sendResult.successful,
                devices_failed: sendResult.failed,
              }
            );
            results.delivered++;
          } else {
            const errors = sendResult.results
              .filter(r => !r.success)
              .map(r => r.error || "Unknown error");

            await updateNotificationStatus(
              supabase,
              notification.id,
              "failed",
              errors.join("; ")
            );
            results.failed++;
            results.errors.push(...errors);
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
    }

    metrics.recordGauge("notifications_processed", results.processed);
    metrics.recordGauge("notifications_delivered", results.delivered);
    metrics.recordGauge("notifications_failed", results.failed);

    logger.perf("batch_processed", startTime, results);
    return results;

  } catch (error) {
    logger.error("batch_processing_failed", error as Error);
    throw error;
  }
}

/**
 * Build platform-optimized FCM messages
 */
async function buildEnhancedMessages(
  notification: any,
  devices: any[]
): Promise<EnhancedFcmMessage[]> {
  const template = notification.notification_templates?.push_template || {};
  const payload = notification.payload || {};

  // Interpolate template variables
  const title = interpolateTemplate(template.title || "Notification", payload);
  const body = interpolateTemplate(template.body || "", payload);
  const imageUrl = template.image_url ? interpolateTemplate(template.image_url, payload) : undefined;

  const messages: EnhancedFcmMessage[] = [];

  for (const device of devices) {
    const baseMessage: EnhancedFcmMessage = {
      token: device.push_token,
      notification: {
        title,
        body,
        ...(imageUrl && { image: imageUrl }),
      },
      data: {
        notification_id: notification.id,
        event_type: notification.event_type,
        click_action: template.click_action || "FLUTTER_NOTIFICATION_CLICK",
        ...Object.fromEntries(
          Object.entries(payload).map(([k, v]) => [k, String(v)])
        ),
      },
      fcm_options: {
        analytics_label: `${notification.event_type}_${notification.priority}`,
      },
    };

    // Platform-specific optimizations
    switch (device.platform?.toLowerCase()) {
      case "android":
        baseMessage.android = {
          priority: notification.priority === "critical" ? "high" : "normal",
          collapse_key: notification.collapse_key,
          ttl: template.ttl || 3600,
          notification: {
            sound: template.sound || "default",
            icon: template.icon || "ic_notification",
            color: template.color || "#007AFF",
            tag: notification.tag,
            click_action: template.click_action || "FLUTTER_NOTIFICATION_CLICK",
            visibility: "private",
            notification_count: template.badge || 1,
          },
        };
        break;

      case "ios":
        baseMessage.apns = {
          headers: {
            "apns-priority": notification.priority === "critical" ? "10" : "5",
            ...(notification.collapse_key && { "apns-collapse-id": notification.collapse_key }),
            ...(template.ttl && { "apns-expiration": String(Math.floor(Date.now() / 1000) + template.ttl) }),
          },
          payload: {
            aps: {
              alert: {
                title,
                body,
                ...(template.subtitle && { subtitle: interpolateTemplate(template.subtitle, payload) }),
              },
              sound: template.sound || "default",
              badge: template.badge || 1,
              ...(template.category && { category: template.category }),
              "content-available": template.background ? 1 : undefined,
              "mutable-content": imageUrl ? 1 : undefined,
              "interruption-level": notification.priority === "critical" ? "critical" : "active",
              "relevance-score": notification.priority === "critical" ? 1.0 : 0.5,
            },
          },
          ...(imageUrl && {
            fcm_options: {
              image: imageUrl,
            },
          }),
        };
        break;

      case "web":
        baseMessage.webpush = {
          notification: {
            title,
            body,
            icon: template.icon || "/icons/notification-icon.png",
            ...(imageUrl && { image: imageUrl }),
            badge: template.badge_icon || "/icons/badge-icon.png",
            tag: notification.tag,
            require_interaction: notification.priority === "critical",
            timestamp: Date.now(),
            ...(template.actions && { actions: template.actions }),
          },
          fcm_options: {
            link: template.click_action || "/",
          },
        };
        break;
    }

    messages.push(baseMessage);
  }

  return messages;
}

/**
 * Record delivery results for analytics
 */
async function recordDeliveryResults(
  supabase: any,
  notificationId: string,
  devices: any[],
  results: Array<{ success: boolean; error?: string; messageIndex: number }>
): Promise<void> {
  const deliveryRecords = results.map((result, index) => ({
    notification_event_id: notificationId,
    device_id: devices[index]?.device_id,
    delivered_at: new Date().toISOString(),
    status: result.success ? "delivered" : "failed",
    error_message: result.error || null,
  }));

  const { error } = await supabase
    .from("notification_deliveries")
    .insert(deliveryRecords);

  if (error) {
    logger.error("delivery_recording_error", error);
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
    update.metadata = { ...update.metadata, ...metadata };
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
 * Interpolate template variables with enhanced functionality
 */
function interpolateTemplate(template: string, data: Record<string, any>): string {
  return template.replace(/\{\{(\w+(?:\.\w+)*)\}\}/g, (match, path) => {
    const value = path.split('.').reduce((obj: any, key: string) => obj?.[key], data);
    return value !== undefined ? String(value) : match;
  });
}

/**
 * Health check endpoint for monitoring
 */
async function handleHealthCheck(): Promise<Response> {
  const health = {
    status: "healthy",
    timestamp: new Date().toISOString(),
    version: "2.0",
    circuit_breaker: {
      fcm: fcmCircuitBreaker.getState(),
    },
    metrics: metrics.getSnapshot(),
  };

  return new Response(JSON.stringify(health), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

/**
 * Main request handler with enhanced security and monitoring
 */
serve(async (req) => {
  const startTime = Date.now();
  const requestId = crypto.randomUUID();

  // Add request ID to logger context
  logger.info("request_started", {
    request_id: requestId,
    method: req.method,
    url: req.url,
  });

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Health check endpoint
  if (req.method === "GET" && new URL(req.url).pathname.endsWith("/health")) {
    return await handleHealthCheck();
  }

  if (req.method !== "POST") {
    return errorResponse(
      new ApiError("Method not allowed", 405),
      corsHeaders
    );
  }

  try {
    // Check if request is from pg_cron
    const userAgent = req.headers.get("user-agent") || "";
    const isPgCron = userAgent.includes("pg_net");

    // Enhanced authentication
    const authHeader = req.headers.get("authorization");
    const webhookSignature = req.headers.get("x-webhook-signature");

    if (webhookSignature) {
      // Webhook authentication
      const secret = Deno.env.get("WEBHOOK_SECRET");
      if (!secret) {
        throw new AuthenticationError("Webhook secret not configured");
      }

      const payload = await req.clone().text();
      const isValid = await verifyHmacSignature(payload, webhookSignature, secret);

      if (!isValid) {
        throw new AuthenticationError("Invalid webhook signature");
      }
    } else {
      // JWT authentication - required for all requests (including pg_cron)
      const jwt = extractJwt(req);

      // Verify service role JWT for pg_cron or verify user JWT for regular calls
      if (!jwt) {
        const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
        const token = authHeader?.replace(/^Bearer\s+/i, "").trim();

        if (!authHeader || !serviceKey || token !== serviceKey) {
          logger.error("auth_failed", {
            isPgCron,
            hasAuthHeader: !!authHeader,
            hasServiceKey: !!serviceKey,
            userAgent
          });
          throw new AuthenticationError("Missing or invalid authentication");
        }
      }

      // For pg_cron, verify it's using service_role
      if (isPgCron && jwt && jwt.role !== "service_role") {
        throw new AuthenticationError("pg_cron must use service_role JWT");
      }
    }

    // Log pg_cron requests for monitoring
    if (isPgCron) {
      logger.info("pg_cron_request", { userAgent, requestId });
    }

    // Parse and validate request body
    const body = await req.json().catch(() => ({}));
    const batchSize = Math.min(Math.max(body.batch_size || 50, 1), 100);

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceKey) {
      throw new ServerError("Supabase configuration missing");
    }

    const supabase = createClient(supabaseUrl, serviceKey);

    // Process notifications
    const results = await processNotificationBatch(supabase, batchSize);

    logger.info("request_completed", {
      request_id: requestId,
      duration_ms: Date.now() - startTime,
      ...results,
    });

    metrics.recordLatency("request_duration", Date.now() - startTime);
    metrics.incrementCounter("requests_total");

    return new Response(JSON.stringify({
      success: true,
      request_id: requestId,
      ...results,
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });

  } catch (error) {
    logger.error("request_failed", error as Error, {
      request_id: requestId,
      duration_ms: Date.now() - startTime,
    });

    metrics.incrementCounter("requests_failed");

    return errorResponse(error as Error, corsHeaders);
  }
});