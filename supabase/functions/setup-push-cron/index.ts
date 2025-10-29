/**
 * One-time setup function for push notification cron job
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Supabase configuration missing");
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    console.log("🔧 Setting up push notification cron job...");

    // Step 1: Unschedule any existing FCM cron jobs
    const { data: existingJobs } = await supabase
      .rpc('cron_unschedule_all_fcm_jobs');

    console.log("✅ Removed old cron jobs");

    // Step 2: Schedule the new cron job
    const { data: scheduleResult, error: scheduleError } = await supabase
      .rpc('cron_schedule_fcm_notifications');

    if (scheduleError) {
      console.error("❌ Failed to schedule cron:", scheduleError);
      throw scheduleError;
    }

    console.log("✅ Cron job scheduled successfully");

    // Step 3: Get the current user from request to create test notification
    const body = await req.json().catch(() => ({}));
    const userId = body.user_id;

    let testNotificationId = null;

    if (userId) {
      // Create a test notification
      const { data: testNotif, error: testError } = await supabase
        .from("notification_events")
        .insert({
          user_id: userId,
          event_type: "test_automated_notification",
          status: "pending",
          priority: "normal",
          payload: {
            title: "Automated Push Working! 🎉",
            body: "Your notification system is now processing automatically every minute!"
          }
        })
        .select()
        .single();

      if (testError) {
        console.warn("⚠️ Failed to create test notification:", testError);
      } else {
        testNotificationId = testNotif.id;
        console.log(`✅ Created test notification: ${testNotificationId}`);
      }
    }

    // Step 4: Verify the cron job
    const { data: cronJobs } = await supabase
      .from("cron.job")
      .select("jobid, jobname, schedule, active")
      .eq("jobname", "process-fcm-notifications");

    return new Response(
      JSON.stringify({
        success: true,
        message: "Push notification cron job setup complete!",
        cron_job: cronJobs?.[0],
        test_notification_id: testNotificationId,
        next_steps: [
          "The cron job will run every minute",
          testNotificationId
            ? "A test notification was created - check your phone in ~1 minute!"
            : "To test: Include your user_id in the request body to create a test notification",
          "Monitor with: SELECT * FROM cron.job WHERE jobname = 'process-fcm-notifications'"
        ]
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );

  } catch (error) {
    console.error("❌ Setup failed:", error);
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
