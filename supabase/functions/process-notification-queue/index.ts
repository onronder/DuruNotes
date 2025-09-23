/**
 * Notification Queue Processor
 * Handles batch processing, cleanup, analytics, and retry operations
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { Logger } from "../common/logger.ts";
import { extractJwt } from "../common/auth.ts";
import {
  ApiError,
  ValidationError,
  AuthenticationError,
  ServerError,
  errorResponse,
} from "../common/errors.ts";

const logger = new Logger("notification-queue");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/**
 * Call the v1 push notification handler
 */
async function callPushHandler(
  batchSize: number,
  serviceKey: string
): Promise<any> {
  const startTime = Date.now();
  
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    if (!supabaseUrl) {
      throw new ServerError("SUPABASE_URL not configured");
    }
    
    // Extract project ref from URL
    const projectRef = supabaseUrl.match(/https:\/\/([^.]+)\.supabase\.co/)?.[1];
    if (!projectRef) {
      throw new ServerError("Could not extract project ref from SUPABASE_URL");
    }
    
    // Call the v1 handler using the auto-provided service key
    const url = `https://${projectRef}.supabase.co/functions/v1/send-push-notification-v1`;
    
    // Use the SUPABASE_SERVICE_ROLE_KEY that's auto-provided by Supabase
    const authKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${authKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ batch_size: batchSize }),
    });
    
    if (!response.ok) {
      const error = await response.text();
      throw new ServerError(`Push handler failed: ${error}`);
    }
    
    const result = await response.json();
    
    logger.perf("push_handler_called", startTime, result);
    return result;
    
  } catch (error) {
    logger.error("push_handler_error", error as Error);
    throw error;
  }
}

/**
 * Process a batch of notifications
 */
async function processBatch(
  supabase: any,
  batchSize: number,
  serviceKey: string
): Promise<any> {
  return callPushHandler(batchSize, serviceKey);
}

/**
 * Clean up old notifications
 */
async function cleanupOldNotifications(
  supabase: any,
  daysOld: number
): Promise<number> {
  const startTime = Date.now();
  
  try {
    // Delete old delivered/failed/cancelled notifications
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysOld);
    
    const { data, error } = await supabase
      .from("notification_events")
      .delete()
      .in("status", ["delivered", "failed", "cancelled"])
      .lt("created_at", cutoffDate.toISOString())
      .select("id");
    
    if (error) {
      throw error;
    }
    
    const deletedCount = data?.length || 0;
    
    logger.perf("cleanup_completed", startTime, {
      deleted_count: deletedCount,
      days_old: daysOld,
    });
    
    return deletedCount;
  } catch (error) {
    logger.error("cleanup_failed", error as Error);
    throw new ServerError("Cleanup failed");
  }
}

/**
 * Generate analytics for notifications
 */
async function generateAnalytics(
  supabase: any,
  hours: number = 24
): Promise<any> {
  const startTime = Date.now();
  
  try {
    const cutoffDate = new Date();
    cutoffDate.setHours(cutoffDate.getHours() - hours);
    
    // Get notification statistics
    const { data: stats, error: statsError } = await supabase
      .from("notification_events")
      .select("status, event_type")
      .gte("created_at", cutoffDate.toISOString());
    
    if (statsError) {
      throw statsError;
    }
    
    // Calculate metrics
    const metrics = {
      total: stats.length,
      by_status: {} as Record<string, number>,
      by_type: {} as Record<string, number>,
      delivery_rate: 0,
    };
    
    for (const event of stats) {
      // Count by status
      metrics.by_status[event.status] = (metrics.by_status[event.status] || 0) + 1;
      
      // Count by type
      metrics.by_type[event.event_type] = (metrics.by_type[event.event_type] || 0) + 1;
    }
    
    // Calculate delivery rate
    const delivered = metrics.by_status.delivered || 0;
    const failed = metrics.by_status.failed || 0;
    const total = delivered + failed;
    
    if (total > 0) {
      metrics.delivery_rate = Math.round((delivered / total) * 100);
    }
    
    // Store analytics
    const { error: insertError } = await supabase
      .from("notification_analytics")
      .insert({
        date: new Date().toISOString().split("T")[0],
        metrics,
      });
    
    if (insertError && !insertError.message.includes("duplicate")) {
      logger.warn("analytics_insert_failed", { error: insertError });
    }
    
    logger.perf("analytics_generated", startTime, metrics);
    return metrics;
    
  } catch (error) {
    logger.error("analytics_failed", error as Error);
    throw new ServerError("Analytics generation failed");
  }
}

/**
 * Retry stuck notifications
 */
async function retryStuckNotifications(
  supabase: any,
  minutesOld: number = 5
): Promise<number> {
  const startTime = Date.now();
  
  try {
    const cutoffDate = new Date();
    cutoffDate.setMinutes(cutoffDate.getMinutes() - minutesOld);
    
    // Reset stuck notifications
    const { data, error } = await supabase
      .from("notification_events")
      .update({
        status: "pending",
        processed_at: null,
        error_message: "Reset from stuck processing state",
        retry_count: supabase.raw("retry_count + 1"),
      })
      .eq("status", "processing")
      .lt("processed_at", cutoffDate.toISOString())
      .select("id");
    
    if (error) {
      throw error;
    }
    
    const resetCount = data?.length || 0;
    
    logger.perf("stuck_notifications_reset", startTime, {
      reset_count: resetCount,
      minutes_old: minutesOld,
    });
    
    return resetCount;
  } catch (error) {
    logger.error("retry_stuck_failed", error as Error);
    throw new ServerError("Failed to retry stuck notifications");
  }
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
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    
    // Check if this is from pg_cron (no auth but has x-source header)
    const source = req.headers.get("x-source");
    const userAgent = req.headers.get("user-agent");
    const isPgCron = source === "pg_cron" || userAgent?.includes("pg_net");
    
    if (!jwt && !isPgCron) {
      // Check if it's a service-to-service call with service role key
      const authHeader = req.headers.get("authorization");
      
      if (!authHeader || !serviceKey) {
        logger.warn("auth_missing", {
          hasAuth: !!authHeader,
          hasServiceKey: !!serviceKey,
          userAgent,
          source
        });
        throw new AuthenticationError("Missing authentication");
      }
      
      // Extract token from "Bearer <token>" format
      const token = authHeader.replace(/^Bearer\s+/i, "").trim();
      
      if (token !== serviceKey) {
        throw new AuthenticationError("Invalid service role key");
      }
    }
    
    if (isPgCron) {
      logger.info("pg_cron_request", { source, userAgent });
    }
    
    // Parse request body
    const body = await req.json().catch(() => ({}));
    const action = body.action || "process";
    
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = serviceKey || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

    if (!supabaseUrl || !supabaseServiceKey || !supabaseAnonKey) {
      throw new ServerError("Supabase configuration missing");
    }

    // SECURITY FIX: Use anon key with JWT context when available, service key only for pg_cron
    let supabase;
    if (isPgCron) {
      // pg_cron operations need service key for scheduled tasks
      supabase = createClient(supabaseUrl, supabaseServiceKey);
    } else {
      // Use anon key with user context to respect RLS policies
      const authHeader = req.headers.get("authorization");
      if (authHeader) {
        supabase = createClient(supabaseUrl, supabaseAnonKey, {
          global: { headers: { Authorization: authHeader } }
        });
      } else {
        // Fallback to service key only if no user context available
        supabase = createClient(supabaseUrl, supabaseServiceKey);
      }
    }
    
    let result: any = {};
    
    // Execute requested action
    switch (action) {
      case "process":
        const batchSize = body.batch_size || 50;
        if (batchSize < 1 || batchSize > 100) {
          throw new ValidationError("Batch size must be between 1 and 100");
        }
        result = await processBatch(supabase, batchSize, serviceKey);
        break;
        
      case "cleanup":
        const daysOld = body.days_old || 30;
        if (daysOld < 1 || daysOld > 365) {
          throw new ValidationError("Days old must be between 1 and 365");
        }
        const deletedCount = await cleanupOldNotifications(supabase, daysOld);
        result = { action: "cleanup", deleted_count: deletedCount };
        break;
        
      case "analytics":
        const hours = body.hours || 24;
        if (hours < 1 || hours > 168) {
          throw new ValidationError("Hours must be between 1 and 168");
        }
        const analytics = await generateAnalytics(supabase, hours);
        result = { action: "analytics", metrics: analytics };
        break;
        
      case "retry_stuck":
        const minutesOld = body.minutes_old || 5;
        if (minutesOld < 1 || minutesOld > 60) {
          throw new ValidationError("Minutes old must be between 1 and 60");
        }
        const resetCount = await retryStuckNotifications(supabase, minutesOld);
        result = { action: "retry_stuck", reset_count: resetCount };
        break;
        
      default:
        throw new ValidationError(`Unknown action: ${action}`);
    }
    
    logger.perf("request_completed", startTime, {
      action,
      ...result,
    });
    
    return new Response(JSON.stringify(result), {
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
