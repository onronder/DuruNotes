import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-clipper-timestamp, x-clipper-signature",
};

/**
 * Normalize alias by stripping any domain part
 * Examples:
 *   "myalias@in.durunotes.app" -> "myalias"
 *   "myalias@example.com" -> "myalias"
 *   "myalias" -> "myalias"
 */
function normalizeAlias(alias: string): string {
  return alias.split('@')[0].trim().toLowerCase();
}

/**
 * Compute HMAC-SHA256 signature
 */
async function computeHmac(secret: string, message: string): Promise<string> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const messageData = encoder.encode(message);
  
  const key = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  
  const signature = await crypto.subtle.sign("HMAC", key, messageData);
  const hashArray = Array.from(new Uint8Array(signature));
  return hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Verify HMAC signature and timestamp
 */
async function verifySignature(
  secret: string,
  timestamp: string,
  signature: string,
  body: string
): Promise<{ valid: boolean; reason?: string }> {
  // Check timestamp freshness (5 minutes)
  try {
    const requestTime = new Date(timestamp).getTime();
    const now = Date.now();
    const diff = Math.abs(now - requestTime);
    
    if (diff > 5 * 60 * 1000) {
      return { valid: false, reason: "Timestamp too old or too far in future" };
    }
  } catch {
    return { valid: false, reason: "Invalid timestamp format" };
  }
  
  // Verify HMAC
  const message = `${timestamp}\n${body}`;
  const expectedSignature = await computeHmac(secret, message);
  
  if (signature !== expectedSignature) {
    return { valid: false, reason: "Invalid signature" };
  }
  
  return { valid: true };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const inboundSecret = Deno.env.get("INBOUND_PARSE_SECRET");

    if (!supabaseUrl || !serviceKey) {
      console.error("Missing Supabase config");
      return new Response("Server Misconfigured", { status: 500, headers: corsHeaders });
    }

    // Read body as text for signature verification
    const bodyText = await req.text();
    let body: any;
    
    try {
      body = JSON.parse(bodyText);
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON body" }), 
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check for HMAC signature (preferred)
    const timestamp = req.headers.get("x-clipper-timestamp");
    const signature = req.headers.get("x-clipper-signature");
    
    let authenticated = false;
    
    if (timestamp && signature && inboundSecret) {
      // Verify HMAC signature
      const verification = await verifySignature(
        inboundSecret,
        timestamp,
        signature,
        bodyText
      );
      
      if (verification.valid) {
        authenticated = true;
        console.log(JSON.stringify({
          event: "auth_success",
          method: "hmac"
        }));
      } else {
        console.log(JSON.stringify({
          event: "hmac_failed",
          reason: verification.reason
        }));
      }
    }
    
    // Fallback to query secret (backward compatibility)
    if (!authenticated) {
      const url = new URL(req.url);
      if (inboundSecret && url.searchParams.get("secret") === inboundSecret) {
        authenticated = true;
        console.log(JSON.stringify({
          event: "auth_success",
          method: "query_secret",
          warning: "deprecated_method"
        }));
      }
    }
    
    if (!authenticated) {
      console.log(JSON.stringify({
        event: "auth_failed",
        reason: "no valid HMAC signature or query secret"
      }));
      return new Response("Unauthorized", { status: 401, headers: corsHeaders });
    }
    
    // Extract required fields
    const { alias, title, text, url: pageUrl, html, clip_timestamp, clipped_at } = body;
    
    if (!alias) {
      console.log(JSON.stringify({ 
        event: "missing_alias",
        error: "Missing required field: alias"
      }));
      return new Response(
        JSON.stringify({ error: "Missing required field: alias" }), 
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    
    // Normalize alias by stripping any domain part
    const normalizedAlias = normalizeAlias(alias);
    console.log(JSON.stringify({
      event: "alias_normalized",
      original: alias,
      normalized: normalizedAlias
    }));

    const supabase = createClient(supabaseUrl, serviceKey);

    // Map alias to user (use normalized alias)
    const { data: aliasRow, error: aliasErr } = await supabase
      .from("inbound_aliases")
      .select("user_id")
      .eq("alias", normalizedAlias)
      .maybeSingle();

    if (aliasErr) {
      console.error(JSON.stringify({
        event: "alias_lookup_error",
        error: aliasErr.message,
        code: aliasErr.code
      }));
      return new Response(
        JSON.stringify({ error: "Temporary error" }), 
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!aliasRow?.user_id) {
      console.log(JSON.stringify({
        event: "alias_not_found",
        alias: normalizedAlias
      }));
      return new Response(
        JSON.stringify({ error: "Alias not registered", alias: normalizedAlias }), 
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = aliasRow.user_id;
    console.log(JSON.stringify({
      event: "user_found",
      alias: normalizedAlias,
      user_id: userId,
      title: title || "N/A"
    }));

    // Build payload for backward compatibility
    const payload = {
      title: title || 'Web Clip',
      text: text || '',
      url: pageUrl || undefined,
      html: html || undefined,
      clipped_at: clipped_at || clip_timestamp || new Date().toISOString(),
    };
    
    // Build metadata for new structure
    const metadata = {
      url: pageUrl,
      clip_timestamp,
      clipped_at: clipped_at || clip_timestamp || new Date().toISOString(),
      ...body // Keep any extra fields
    };

    // Insert web clip into clipper_inbox with BOTH structures for compatibility
    const { error: insErr } = await supabase
      .from("clipper_inbox")
      .insert({
        user_id: userId,
        source_type: "web",
        // New structure fields
        title: title || 'Web Clip',
        content: text || '',
        html: html || null,
        metadata: metadata,
        // Backward compatibility field
        payload_json: payload,
        message_id: null, // Not applicable for web clips
      });

    if (insErr) {
      console.error(JSON.stringify({
        event: "insert_failed",
        error: insErr.message,
        code: insErr.code,
        user_id: userId,
        title: title || "N/A"
      }));
      return new Response(
        JSON.stringify({ error: "Failed to save clip" }), 
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(JSON.stringify({
      event: "web_clip_saved",
      user_id: userId,
      title: title || "N/A",
      alias: normalizedAlias
    }));

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "Web clip saved",
        alias: normalizedAlias
      }), 
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(JSON.stringify({
      event: "unexpected_error",
      error: error.message,
      stack: error.stack
    }));
    return new Response(
      JSON.stringify({ error: "Internal server error" }), 
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
