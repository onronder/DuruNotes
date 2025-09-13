import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Structured logging
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

// Process a batch of notifications
async function processBatch(supabase: any, batchSize: number): Promise<any> {
  const startTime = Date.now();
  
  try {
    // Get the Edge Function URL for send-push-notification
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    
    if (!supabaseUrl) {
      throw new Error("SUPABASE_URL not configured");
    }

    // Construct the Edge Function URL
    const projectRef = supabaseUrl.match(/https:\/\/([^.]+)\.supabase\.co/)?.[1];
    if (!projectRef) {
      throw new Error("Could not extract project ref from SUPABASE_URL");
    }
    
    const sendNotificationUrl = `https://${projectRef}.supabase.co/functions/v1/send-push-notification-v1`;
    
    // Call the send-push-notification function to process a batch
    const response = await fetch(sendNotificationUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        batch_size: batchSize,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Failed to process batch: ${error}`);
    }

    const result = await response.json();
    
    log("info", "batch_processed", {
      processed: result.processed,
      duration_ms: Date.now() - startTime,
    });
    
    return result;
  } catch (error) {
    log("error", "batch_processing_failed", {
      error: String(error),
      duration_ms: Date.now() - startTime,
    });
    throw error;
  }
}

// Clean up old notifications
async function cleanupOldNotifications(supabase: any, daysOld: number): Promise<number> {
  try {
    const { data, error } = await supabase.rpc("cleanup_old_notifications", {
      p_days_old: daysOld,
    });

    if (error) {
      throw error;
    }

    log("info", "cleanup_completed", {
      deleted_count: data,
      days_old: daysOld,
    });

    return data;
  } catch (error) {
    log("error", "cleanup_failed", {
      error: String(error),
      days_old: daysOld,
    });
    throw error;
  }
}

// Collect and aggregate analytics
async function collectAnalytics(supabase: any): Promise<any> {
  try {
    const endDate = new Date();
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 1); // Last 24 hours

    // Get notification stats
    const { data: stats, error: statsError } = await supabase
      .from("notification_stats")
      .select("*")
      .gte("date", startDate.toISOString().split("T")[0])
      .lte("date", endDate.toISOString().split("T")[0]);

    if (statsError) {
      throw statsError;
    }

    // Calculate aggregates
    const totals = {
      total_events: 0,
      total_delivered: 0,
      total_failed: 0,
      avg_delivery_time: 0,
      by_type: {},
      by_source: {},
    };

    if (stats && stats.length > 0) {
      stats.forEach((stat: any) => {
        totals.total_events += stat.events_created || 0;
        totals.total_delivered += stat.events_delivered || 0;
        totals.total_failed += stat.events_failed || 0;

        // Aggregate by type
        if (!totals.by_type[stat.event_type]) {
          totals.by_type[stat.event_type] = {
            created: 0,
            delivered: 0,
            failed: 0,
          };
        }
        totals.by_type[stat.event_type].created += stat.events_created || 0;
        totals.by_type[stat.event_type].delivered += stat.events_delivered || 0;
        totals.by_type[stat.event_type].failed += stat.events_failed || 0;

        // Aggregate by source
        if (!totals.by_source[stat.event_source]) {
          totals.by_source[stat.event_source] = {
            created: 0,
            delivered: 0,
            failed: 0,
          };
        }
        totals.by_source[stat.event_source].created += stat.events_created || 0;
        totals.by_source[stat.event_source].delivered += stat.events_delivered || 0;
        totals.by_source[stat.event_source].failed += stat.events_failed || 0;
      });

      // Calculate average delivery time
      const deliveryTimes = stats
        .filter((s: any) => s.avg_delivery_time_seconds)
        .map((s: any) => s.avg_delivery_time_seconds);
      
      if (deliveryTimes.length > 0) {
        totals.avg_delivery_time = 
          deliveryTimes.reduce((a: number, b: number) => a + b, 0) / deliveryTimes.length;
      }
    }

    log("info", "analytics_collected", {
      period_start: startDate.toISOString(),
      period_end: endDate.toISOString(),
      totals,
    });

    return totals;
  } catch (error) {
    log("error", "analytics_failed", {
      error: String(error),
    });
    throw error;
  }
}

// Check for stuck notifications and retry them
async function retryStuckNotifications(supabase: any): Promise<number> {
  try {
    // Find notifications stuck in processing for more than 5 minutes
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    
    const { data: stuckEvents, error: fetchError } = await supabase
      .from("notification_events")
      .select("id")
      .eq("status", "processing")
      .lt("processed_at", fiveMinutesAgo.toISOString());

    if (fetchError) {
      throw fetchError;
    }

    if (!stuckEvents || stuckEvents.length === 0) {
      return 0;
    }

    // Reset stuck events to pending
    const { error: updateError } = await supabase
      .from("notification_events")
      .update({
        status: "pending",
        processed_at: null,
        error_message: "Reset from stuck processing state",
      })
      .in("id", stuckEvents.map((e: any) => e.id));

    if (updateError) {
      throw updateError;
    }

    log("info", "stuck_notifications_reset", {
      count: stuckEvents.length,
      event_ids: stuckEvents.map((e: any) => e.id),
    });

    return stuckEvents.length;
  } catch (error) {
    log("error", "retry_stuck_failed", {
      error: String(error),
    });
    throw error;
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
    const { 
      action = "process", 
      batch_size = 50,
      cleanup_days = 30,
    } = body;

    let result: any = {};

    switch (action) {
      case "process":
        // Process pending notifications
        result.batch = await processBatch(supabase, batch_size);
        break;

      case "cleanup":
        // Clean up old notifications
        result.cleaned = await cleanupOldNotifications(supabase, cleanup_days);
        break;

      case "analytics":
        // Collect analytics
        result.analytics = await collectAnalytics(supabase);
        break;

      case "retry_stuck":
        // Retry stuck notifications
        result.retried = await retryStuckNotifications(supabase);
        break;

      case "full":
        // Run all maintenance tasks
        result.stuck_retried = await retryStuckNotifications(supabase);
        result.batch = await processBatch(supabase, batch_size);
        result.cleaned = await cleanupOldNotifications(supabase, cleanup_days);
        result.analytics = await collectAnalytics(supabase);
        break;

      default:
        return new Response(
          JSON.stringify({ error: `Unknown action: ${action}` }), 
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }

    // Log completion
    log("info", "queue_processor_completed", {
      action,
      result,
      duration_ms: Date.now() - startTime,
    });

    return new Response(
      JSON.stringify({
        action,
        result,
        duration_ms: Date.now() - startTime,
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  } catch (error) {
    log("error", "queue_processor_error", {
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

// Schedule this function to run periodically using Supabase Cron Jobs
// Example cron expression for every 5 minutes: */5 * * * *
// This would be configured in the Supabase dashboard or via SQL:
// 
// SELECT cron.schedule(
//   'process-notification-queue',
//   '*/5 * * * *', -- Every 5 minutes
//   $$
//   SELECT net.http_post(
//     url := 'https://YOUR_PROJECT.supabase.co/functions/v1/process-notification-queue',
//     headers := jsonb_build_object(
//       'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
//       'Content-Type', 'application/json'
//     ),
//     body := jsonb_build_object('action', 'full')
//   );
//   $$
// );
