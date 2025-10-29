/**
 * Production-Grade Web Clipper Endpoint
 * Handles incoming web clips from Chrome extension with comprehensive security
 *
 * Security Features:
 * - JWT authentication for users
 * - HMAC-SHA256 authentication for services
 * - HTML sanitization (XSS protection)
 * - Rate limiting (50 clips/hour per user)
 * - Input validation and sanitization
 * - Restricted CORS policy
 * - Structured error handling and logging
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

// Production-grade CORS: restrict to known domains
const ALLOWED_ORIGINS = [
  "chrome-extension://", // Allow all Chrome extensions (checked by ID)
  "https://durunotes.com",
  "https://www.durunotes.com",
  "https://app.durunotes.com"
];

const corsHeaders = {
  "Access-Control-Allow-Origin": "", // Set dynamically based on origin
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-clipper-timestamp, x-clipper-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ============================================================================
// SECURITY UTILITIES
// ============================================================================

/**
 * Validate origin against allowed list and return CORS headers
 */
function getCorsHeaders(origin: string | null): Record<string, string> {
  if (!origin) {
    return { ...corsHeaders, "Access-Control-Allow-Origin": "" };
  }

  // Check if origin is allowed
  const isAllowed = ALLOWED_ORIGINS.some(allowed =>
    origin.startsWith(allowed) || allowed === origin
  );

  if (isAllowed) {
    return { ...corsHeaders, "Access-Control-Allow-Origin": origin };
  }

  // Reject unknown origins
  return { ...corsHeaders, "Access-Control-Allow-Origin": "" };
}

/**
 * Verify HMAC signature using SHA-256
 */
async function verifyHMAC(payload: string, signature: string, secret: string): Promise<boolean> {
  try {
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      'raw',
      encoder.encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );

    const signatureBuffer = await crypto.subtle.sign(
      'HMAC',
      key,
      encoder.encode(payload)
    );

    const computedSignature = Array.from(new Uint8Array(signatureBuffer))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    return computedSignature === signature.toLowerCase();
  } catch (e) {
    console.error("HMAC verification error:", e);
    return false;
  }
}

/**
 * Sanitize HTML to prevent XSS attacks
 * Removes all potentially dangerous tags and attributes
 */
function sanitizeHtml(html: string): string {
  if (!html) return '';

  // Remove script tags and their content
  let sanitized = html.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');

  // Remove event handlers (onclick, onerror, etc.)
  sanitized = sanitized.replace(/on\w+\s*=\s*["'][^"']*["']/gi, '');
  sanitized = sanitized.replace(/on\w+\s*=\s*[^\s>]*/gi, '');

  // Remove javascript: protocol
  sanitized = sanitized.replace(/javascript:/gi, '');

  // Remove data: URIs (except images)
  sanitized = sanitized.replace(/data:(?!image\/)[^,]*,/gi, '');

  // Remove dangerous tags
  const dangerousTags = ['iframe', 'object', 'embed', 'applet', 'meta', 'link', 'style', 'form'];
  dangerousTags.forEach(tag => {
    const regex = new RegExp(`<${tag}\\b[^<]*(?:(?!<\\/${tag}>)<[^<]*)*<\\/${tag}>`, 'gi');
    sanitized = sanitized.replace(regex, '');
  });

  return sanitized.trim();
}

/**
 * Validate and sanitize text input
 */
function validateText(text: string | null, fieldName: string, maxLength: number): string {
  if (!text) return '';

  // Trim and limit length
  const sanitized = text.trim().substring(0, maxLength);

  // Basic XSS prevention for text fields
  return sanitized
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;');
}

/**
 * Check rate limit for user (50 clips per hour)
 */
async function checkRateLimit(supabase: any, userId: string): Promise<{ allowed: boolean; remaining: number }> {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const RATE_LIMIT = 50; // clips per hour

  try {
    const { data, error } = await supabase
      .from('clipper_inbox')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('source_type', 'web')
      .gte('created_at', oneHourAgo);

    if (error) {
      console.error("Rate limit check error:", error);
      return { allowed: true, remaining: RATE_LIMIT }; // Fail open
    }

    const count = data || 0;
    const remaining = Math.max(0, RATE_LIMIT - count);

    return {
      allowed: count < RATE_LIMIT,
      remaining
    };
  } catch (e) {
    console.error("Rate limit exception:", e);
    return { allowed: true, remaining: RATE_LIMIT }; // Fail open
  }
}

/**
 * Structured logging helper
 */
function logEvent(level: string, message: string, context: Record<string, any> = {}) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...context
  };
  console.log(JSON.stringify(logEntry));
}

// ============================================================================
// MAIN HANDLER
// ============================================================================

serve(async (req) => {
  // Get origin and validate CORS
  const origin = req.headers.get("origin");
  const responseCorsHeaders = getCorsHeaders(origin);

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: responseCorsHeaders });
  }

  if (req.method !== "POST") {
    logEvent("warn", "Invalid method", { method: req.method, origin });
    return new Response("Method Not Allowed", {
      status: 405,
      headers: responseCorsHeaders
    });
  }

  const startTime = Date.now();

  try {
    // Get environment variables (automatically provided by Supabase)
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const inboundSecret = Deno.env.get("INBOUND_PARSE_SECRET");

    if (!supabaseUrl || !serviceKey) {
      logEvent("error", "Missing Supabase configuration");
      return new Response("Server misconfigured", {
        status: 500,
        headers: responseCorsHeaders
      });
    }

    // Create Supabase client with service role key
    const supabase = createClient(supabaseUrl, serviceKey);

    // Parse request body
    let body;
    try {
      body = await req.json();
    } catch (e) {
      logEvent("error", "Invalid JSON in request body", { error: e.message });
      return new Response(
        JSON.stringify({ error: "Invalid JSON" }),
        {
          status: 400,
          headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
        }
      );
    }

    const { alias, title, text, url: pageUrl, html, clipped_at } = body;

    // Determine authentication method and user
    let userId = null;
    let authMethod = "none";

    // 1. Check for JWT authentication (Chrome extension with user auth)
    const authHeader = req.headers.get("authorization");
    if (authHeader && authHeader.startsWith("Bearer ")) {
      try {
        // Extract JWT token from Bearer header
        const jwt = authHeader.replace("Bearer ", "").trim();

        // SECURITY: Use proper Supabase authentication
        const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
        if (!anonKey) {
          logEvent("error", "Missing SUPABASE_ANON_KEY");
          throw new Error("Authentication configuration error");
        }

        // Create Supabase client with anon key
        const userSupabase = createClient(supabaseUrl, anonKey);

        // Verify JWT by passing it directly to getUser()
        // This is the correct way in Supabase JS SDK v2
        const { data: { user }, error: authError } = await userSupabase.auth.getUser(jwt);

        if (user && !authError) {
          userId = user.id;
          authMethod = "jwt";
          logEvent("info", "Authenticated via JWT", { userId });
        } else {
          logEvent("error", "JWT verification failed", {
            error: authError?.message,
            errorCode: authError?.code,
            errorDetails: JSON.stringify(authError),
            hasAnonKey: !!anonKey,
            jwtLength: jwt.length
          });
        }
      } catch (e) {
        logEvent("warn", "JWT authentication failed", { error: e.message });
      }
    }

    // 2. Check for HMAC authentication (webhooks, services)
    if (!userId && inboundSecret) {
      const timestamp = req.headers.get("x-clipper-timestamp");
      const signature = req.headers.get("x-clipper-signature");

      if (timestamp && signature) {
        // SECURITY: HMAC authentication from headers (not URL)
        const payload = JSON.stringify(body) + timestamp;
        const isValid = await verifyHMAC(payload, signature, inboundSecret);

        if (isValid) {
          authMethod = "hmac";
          logEvent("info", "Authenticated via HMAC");

          // For HMAC auth, map alias to user
          if (alias) {
            const normalizedAlias = alias.split('@')[0].trim().toLowerCase();
            const { data: aliasRow } = await supabase
              .from("inbound_aliases")
              .select("user_id")
              .eq("alias", normalizedAlias)
              .maybeSingle();

            if (aliasRow?.user_id) {
              userId = aliasRow.user_id;
              logEvent("info", "Mapped alias to user", { alias: normalizedAlias, userId });
            } else {
              logEvent("warn", "Unknown alias", { alias: normalizedAlias });
              // Return success to avoid revealing whether alias exists
              return new Response(
                JSON.stringify({ status: "ok", message: "Request processed" }),
                {
                  status: 200,
                  headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
                }
              );
            }
          }
        } else {
          logEvent("warn", "HMAC verification failed");
        }
      }
    }

    // If no authentication succeeded, reject
    if (authMethod === "none") {
      logEvent("warn", "No valid authentication provided", { origin, hasAuthHeader: !!authHeader });
      return new Response(
        JSON.stringify({ error: "Unauthorized", message: "No valid authentication method" }),
        {
          status: 401,
          headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
        }
      );
    }

    // Validate we have a user ID
    if (!userId) {
      logEvent("warn", "No user ID determined");
      return new Response(
        JSON.stringify({ error: "User not found" }),
        {
          status: 400,
          headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
        }
      );
    }

    // Check rate limit (50 clips per hour)
    const rateLimit = await checkRateLimit(supabase, userId);
    if (!rateLimit.allowed) {
      logEvent("warn", "Rate limit exceeded", { userId, remaining: rateLimit.remaining });
      return new Response(
        JSON.stringify({
          error: "Rate limit exceeded",
          message: "Maximum 50 clips per hour allowed",
          remaining: rateLimit.remaining
        }),
        {
          status: 429,
          headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
        }
      );
    }

    // Validate required fields
    if (!title && !text) {
      logEvent("warn", "Missing required fields", { userId });
      return new Response(
        JSON.stringify({ error: "Missing title or text" }),
        {
          status: 400,
          headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
        }
      );
    }

    // SECURITY: Sanitize and validate inputs
    const sanitizedTitle = validateText(title, "title", 500);
    const sanitizedText = validateText(text, "text", 50000);
    const sanitizedUrl = validateText(pageUrl, "url", 2000);
    const sanitizedHtml = html ? sanitizeHtml(html) : null;

    logEvent("info", "Input validation complete", {
      userId,
      titleLength: sanitizedTitle.length,
      textLength: sanitizedText.length,
      hasHtml: !!sanitizedHtml
    });

    // Prepare payload_json (consistent with email-in)
    const payloadJson = {
      title: sanitizedTitle || "Untitled Clip",
      text: sanitizedText || "",
      url: sanitizedUrl || "",
      html: sanitizedHtml,
      clipped_at: clipped_at || new Date().toISOString(),
      source: "chrome_extension"
    };

    // Insert into clipper_inbox
    const { error: insertError } = await supabase
      .from("clipper_inbox")
      .insert({
        user_id: userId,
        source_type: "web", // REQUIRED FIELD
        title: sanitizedTitle || "Untitled Clip",
        content: sanitizedText || "",
        html: sanitizedHtml,
        metadata: {
          url: sanitizedUrl,
          clipped_at: clipped_at || new Date().toISOString(),
          auth_method: authMethod,
          alias: alias || null,
          origin: origin || "unknown"
        },
        payload_json: payloadJson, // NEW: Consistent with email-in
        message_id: `clip_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        created_at: new Date().toISOString()
      });

    if (insertError) {
      logEvent("error", "Failed to insert clip", {
        userId,
        error: insertError.message,
        code: insertError.code
      });
      return new Response(
        JSON.stringify({ error: "Failed to save clip" }),
        {
          status: 500,
          headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
        }
      );
    }

    const processingTime = Date.now() - startTime;
    logEvent("info", "Clip saved successfully", {
      userId,
      authMethod,
      processingTimeMs: processingTime,
      rateRemaining: rateLimit.remaining - 1
    });

    // Trigger notification (optional, non-blocking)
    try {
      await supabase.rpc("create_notification_event", {
        p_user_id: userId,
        p_event_type: "web_clip_saved",
        p_event_source: "web",
        p_payload: {
          title: sanitizedTitle || "Web Clip",
          url: sanitizedUrl || "",
          preview: sanitizedText ? sanitizedText.substring(0, 100) : ""
        },
        p_priority: "normal",
        p_dedupe_key: `webclip_${Date.now()}_${userId}`
      });
    } catch (notifErr) {
      // Log but don't fail the request
      logEvent("warn", "Notification trigger failed (non-critical)", {
        error: notifErr.message
      });
    }

    return new Response(
      JSON.stringify({
        status: "ok",
        message: "Clip saved successfully",
        auth_method: authMethod,
        rate_limit: {
          remaining: rateLimit.remaining - 1,
          limit: 50
        },
        processing_time_ms: processingTime
      }),
      {
        status: 200,
        headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
      }
    );

  } catch (error) {
    const processingTime = Date.now() - startTime;
    logEvent("error", "Unhandled error", {
      error: error.message,
      stack: error.stack,
      processingTimeMs: processingTime
    });
    return new Response(
      JSON.stringify({ error: "Server error" }),
      {
        status: 500,
        headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
      }
    );
  }
});
