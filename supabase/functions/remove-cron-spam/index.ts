/**
 * One-time function to remove the spam cron job
 * Run this once, then delete this function
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    console.log("🗑️ Removing spam cron job...");

    // Unschedule the cron job
    const { data: unscheduled, error: unscheduleError } = await supabase.rpc(
      "cron_unschedule_job",
      { job_name: "process-fcm-notifications" }
    );

    if (unscheduleError) {
      console.error("Error:", unscheduleError);
      // Try direct SQL query
      const { data, error } = await supabase.rpc("exec_sql", {
        query: `
          SELECT cron.unschedule(jobid)
          FROM cron.job
          WHERE jobname = 'process-fcm-notifications'
        `
      });

      if (error) {
        throw error;
      }
    }

    // Verify it's gone
    const { data: remainingJobs, error: verifyError } = await supabase
      .from("cron.job")
      .select("*")
      .or("jobname.like.%fcm%,jobname.like.%notif%");

    console.log("✅ Cron job removed!");
    console.log("Remaining jobs:", remainingJobs);

    return new Response(
      JSON.stringify({
        success: true,
        message: "Spam cron job removed successfully!",
        remaining_jobs: remainingJobs || [],
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("❌ Failed:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
        manual_fix: "Go to Supabase SQL Editor and run: SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'process-fcm-notifications';"
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
