/**
 * Authenticated Web Clipper Endpoint
 * Uses JWT authentication instead of shared secrets
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { Logger } from "../common/logger.ts";
import { 
  ApiError,
  ValidationError,
  AuthenticationError,
  ServerError,
  errorResponse
} from "../common/errors.ts";

const logger = new Logger("inbound-web-auth");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-user-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/**
 * Verify JWT token and extract user ID
 */
async function verifyUserToken(
  authHeader: string | null,
  supabase: any
): Promise<{ userId: string; email: string }> {
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    throw new AuthenticationError("Missing or invalid authorization header");
  }
  
  const token = authHeader.substring(7);
  
  // Verify token with Supabase
  const { data: { user }, error } = await supabase.auth.getUser(token);
  
  if (error || !user) {
    logger.error("token_verification_failed", error);
    throw new AuthenticationError("Invalid or expired token");
  }
  
  return {
    userId: user.id,
    email: user.email || ""
  };
}

/**
 * Normalize alias by removing domain part
 */
function normalizeAlias(alias: string): string {
  return alias.split('@')[0].trim().toLowerCase();
}

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
  
  const startTime = Date.now();
  let userId: string | null = null;
  
  try {
    // Initialize Supabase clients
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    
    logger.info("env_check", {
      hasUrl: !!supabaseUrl,
      hasServiceKey: !!serviceKey,
      hasAnonKey: !!anonKey,
      serviceKeyLength: serviceKey?.length,
      anonKeyLength: anonKey?.length
    });
    
    if (!supabaseUrl || !serviceKey || !anonKey) {
      throw new ServerError("Missing Supabase configuration");
    }
    
    // Create two clients: one for auth verification (anon), one for database operations (service)
    const supabaseAuth = createClient(supabaseUrl, anonKey);
    const supabaseService = createClient(supabaseUrl, serviceKey);
    
    // Verify user authentication with anon client
    const authHeader = req.headers.get("authorization");
    const userInfo = await verifyUserToken(authHeader, supabaseAuth);
    userId = userInfo.userId;
    
    logger.info("auth_success", { 
      userId,
      email: userInfo.email 
    });
    
    // Parse request body
    const body = await req.json();
    const { 
      alias, 
      title, 
      text, 
      url: pageUrl, 
      html, 
      clipped_at 
    } = body;
    
    if (!alias) {
      throw new ValidationError("Missing required field: alias");
    }
    
    // Normalize alias
    const normalizedAlias = normalizeAlias(alias);
    
    logger.info("processing_clip", {
      userId,
      alias: normalizedAlias,
      hasTitle: !!title,
      hasText: !!text,
      hasUrl: !!pageUrl,
      hasHtml: !!html
    });
    
    // Check if user has an alias (user_id is primary key, so one alias per user)
    const { data: userAliasData, error: userAliasError } = await supabaseService
      .from("inbound_aliases")
      .select("alias")
      .eq("user_id", userId)
      .single();
    
    if (userAliasError && userAliasError.code !== "PGRST116") {
      logger.error("user_alias_lookup_failed", userAliasError);
      throw new ServerError("Failed to verify user alias");
    }
    
    // If user has no alias, create one
    if (!userAliasData) {
      // Check if the requested alias is already taken by another user
      const { data: existingAlias } = await supabaseService
        .from("inbound_aliases")
        .select("alias")
        .eq("alias", normalizedAlias)
        .single();
      
      if (existingAlias) {
        // Alias is taken, generate a unique one
        const uniqueAlias = `${normalizedAlias}_${Date.now()}`;
        logger.info("alias_taken_using_unique", { 
          requested: normalizedAlias,
          using: uniqueAlias 
        });
        normalizedAlias = uniqueAlias;
      }
      
      const { error: createError } = await supabaseService
        .from("inbound_aliases")
        .insert({
          user_id: userId,
          alias: normalizedAlias,
          created_at: new Date().toISOString()
        });
      
      if (createError) {
        logger.error("alias_creation_failed", createError);
        throw new ServerError("Failed to create alias");
      }
      
      logger.info("alias_created", { 
        userId, 
        alias: normalizedAlias 
      });
    } else {
      // User already has an alias, use it regardless of what was requested
      const requestedAlias = normalizedAlias;
      normalizedAlias = userAliasData.alias;
      logger.info("using_existing_alias", { 
        userId, 
        requested: requestedAlias,
        using: normalizedAlias 
      });
    }
    
    // Prepare metadata
    const metadata = {
      source: "chrome_extension",
      url: pageUrl,
      clipped_at: clipped_at || new Date().toISOString(),
      has_html: !!html,
      user_agent: req.headers.get("user-agent"),
      ip: req.headers.get("x-forwarded-for") || req.headers.get("x-real-ip")
    };
    
    // Insert into clipper_inbox
    const { data: clipData, error: clipError } = await supabaseService
      .from("clipper_inbox")
      .insert({
        user_id: userId,
        title: title || "Untitled Clip",
        content: text || "",
        html: html || "",
        metadata: metadata,
        message_id: `clip_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        created_at: new Date().toISOString()
      })
      .select()
      .single();
    
    if (clipError) {
      logger.error("clip_insert_failed", clipError);
      throw new ServerError("Failed to save clip");
    }
    
    const duration = Date.now() - startTime;
    logger.info("clip_saved", {
      userId,
      clipId: clipData.id,
      alias: normalizedAlias,
      duration
    });
    
    return new Response(
      JSON.stringify({
        success: true,
        id: clipData.id,
        message: "Content clipped successfully"
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      }
    );
    
  } catch (error) {
    const duration = Date.now() - startTime;
    
    if (error instanceof ApiError) {
      logger.warn("request_failed", {
        error: error.message,
        code: error.code,
        userId,
        duration
      });
      return errorResponse(error, corsHeaders);
    }
    
    logger.error("unexpected_error", error, {
      userId,
      duration
    });
    
    return errorResponse(
      new ServerError("An unexpected error occurred"),
      corsHeaders
    );
  }
});
