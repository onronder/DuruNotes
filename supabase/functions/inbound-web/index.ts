/**
 * FINAL Unified Web Clipper Endpoint
 * Handles ALL incoming data: webhooks, Chrome extension, external services
 * Supports both JWT authentication (for users) and secret/HMAC (for services)
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-clipper-timestamp, x-clipper-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { 
      status: 405, 
      headers: corsHeaders 
    });
  }

  try {
    // Get environment variables (automatically provided by Supabase)
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const inboundSecret = Deno.env.get("INBOUND_PARSE_SECRET");

    if (!supabaseUrl || !serviceKey) {
      console.error("Missing Supabase configuration");
      return new Response("Server misconfigured", { 
        status: 500, 
        headers: corsHeaders 
      });
    }

    // Create Supabase client with service role key
    const supabase = createClient(supabaseUrl, serviceKey);

    // Parse request body
    const body = await req.json();
    const { alias, title, text, url: pageUrl, html, clipped_at } = body;

    // Determine authentication method and user
    let userId = null;
    let authMethod = "none";

    // 1. Check for JWT authentication (Chrome extension with user auth)
    const authHeader = req.headers.get("authorization");
    if (authHeader && authHeader.startsWith("Bearer ")) {
      try {
        // SECURITY FIX: Use proper Supabase authentication instead of unsafe JWT parsing
        const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
        if (!anonKey) {
          console.error("Missing SUPABASE_ANON_KEY");
          throw new Error("Authentication configuration error");
        }

        // Create authenticated Supabase client with user JWT
        const userSupabase = createClient(supabaseUrl, anonKey, {
          global: { headers: { Authorization: authHeader } }
        });

        // Verify JWT and get user
        const { data: { user }, error: authError } = await userSupabase.auth.getUser();

        if (user && !authError) {
          userId = user.id;
          authMethod = "jwt";
          console.log("Authenticated via JWT for user:", userId);
        } else {
          console.log("JWT verification failed:", authError?.message);
        }
      } catch (e) {
        console.log("JWT authentication failed, trying other auth methods:", e.message);
      }
    }

    // 2. Check for secret authentication (webhooks, services)
    if (!userId && inboundSecret) {
      const url = new URL(req.url);
      const providedSecret = url.searchParams.get("secret");
      
      if (providedSecret === inboundSecret) {
        authMethod = "secret";
        console.log("Authenticated via secret");
        
        // For secret auth, we need to map alias to user
        if (alias) {
          const normalizedAlias = alias.split('@')[0].trim().toLowerCase();
          const { data: aliasRow } = await supabase
            .from("inbound_aliases")
            .select("user_id")
            .eq("alias", normalizedAlias)
            .maybeSingle();
          
          if (aliasRow?.user_id) {
            userId = aliasRow.user_id;
            console.log("Mapped alias to user:", userId);
          } else {
            console.log("Unknown alias:", normalizedAlias);
            // Return success to avoid revealing whether alias exists
            return new Response(
              JSON.stringify({ status: "ok", message: "Request processed" }), 
              { 
                status: 200, 
                headers: { ...corsHeaders, "Content-Type": "application/json" } 
              }
            );
          }
        }
      }
    }

    // If no authentication succeeded, reject
    if (authMethod === "none") {
      console.log("No valid authentication provided");
      return new Response("Unauthorized", { 
        status: 401, 
        headers: corsHeaders 
      });
    }

    // Validate we have a user ID
    if (!userId) {
      console.log("No user ID determined");
      return new Response(
        JSON.stringify({ error: "User not found" }), 
        { 
          status: 400, 
          headers: { ...corsHeaders, "Content-Type": "application/json" } 
        }
      );
    }

    // Validate required fields
    if (!title && !text) {
      return new Response(
        JSON.stringify({ error: "Missing title or text" }), 
        { 
          status: 400, 
          headers: { ...corsHeaders, "Content-Type": "application/json" } 
        }
      );
    }

    // Insert into clipper_inbox
    const { error: insertError } = await supabase
      .from("clipper_inbox")
      .insert({
        user_id: userId,
        source_type: "web", // REQUIRED FIELD
        title: title || "Untitled Clip",
        content: text || "",
        html: html || null,
        metadata: {
          url: pageUrl,
          clipped_at: clipped_at || new Date().toISOString(),
          auth_method: authMethod,
          alias: alias || null
        },
        message_id: `clip_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        created_at: new Date().toISOString()
      });

    if (insertError) {
      console.error("Insert error:", insertError);
      return new Response(
        JSON.stringify({ error: "Failed to save clip" }), 
        { 
          status: 500, 
          headers: { ...corsHeaders, "Content-Type": "application/json" } 
        }
      );
    }

    console.log("Clip saved successfully for user:", userId);

    // Trigger notification (optional, non-blocking)
    try {
      await supabase.rpc("create_notification_event", {
        p_user_id: userId,
        p_event_type: "web_clip_saved",
        p_event_source: "web",
        p_payload: {
          title: title || "Web Clip",
          url: pageUrl || "",
          preview: text ? text.substring(0, 100) : ""
        },
        p_priority: "normal",
        p_dedupe_key: `webclip_${Date.now()}_${userId}`
      });
    } catch (notifErr) {
      // Log but don't fail the request
      console.log("Notification trigger failed (non-critical):", notifErr);
    }

    return new Response(
      JSON.stringify({ 
        status: "ok", 
        message: "Clip saved successfully",
        auth_method: authMethod
      }), 
      { 
        status: 200, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );

  } catch (error) {
    console.error("Unhandled error:", error);
    return new Response(
      JSON.stringify({ error: "Server error" }), 
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});
