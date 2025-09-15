/**
 * Consolidated Email Inbox Function
 * Handles incoming emails with HMAC verification, attachment processing,
 * and unified payload structure
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { Logger } from "../common/logger.ts";
import { authenticateWebhook, getClientIp } from "../common/auth.ts";
import { 
  ApiError, 
  ValidationError, 
  AuthenticationError,
  ServerError,
  errorResponse 
} from "../common/errors.ts";

const logger = new Logger("email_inbox");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-signature, x-hmac-signature",
};

/**
 * Extract provider timestamp from email headers
 */
function extractProviderTimestamp(headers: string): number | null {
  if (!headers) return null;
  
  // Mailgun: X-Mailgun-Timestamp (Unix timestamp)
  const mailgunMatch = headers.match(/X-Mailgun-Timestamp:\s*(\d+)/i);
  if (mailgunMatch) {
    return parseInt(mailgunMatch[1]) * 1000;
  }
  
  // SendGrid: X-Sendgrid-Event-Time (Unix timestamp)
  const sendgridMatch = headers.match(/X-Sendgrid-Event-Time:\s*(\d+)/i);
  if (sendgridMatch) {
    return parseInt(sendgridMatch[1]) * 1000;
  }
  
  // Standard Date header as fallback
  const dateMatch = headers.match(/Date:\s*(.+)/i);
  if (dateMatch) {
    const parsed = Date.parse(dateMatch[1]);
    if (!isNaN(parsed)) return parsed;
  }
  
  return null;
}

/**
 * Normalize email alias (remove dots, plus addressing, etc)
 */
function normalizeAlias(email: string): string {
  const [localPart, domain] = email.split("@");
  if (!localPart) return "";
  
  // Remove plus addressing (e.g., alias+tag@domain -> alias@domain)
  let normalized = localPart.split("+")[0];
  
  // Convert to lowercase
  normalized = normalized.toLowerCase();
  
  // Remove dots for Gmail-style normalization (optional)
  // normalized = normalized.replace(/\./g, "");
  
  return normalized;
}

/**
 * Extract Message-ID from headers
 */
function extractMessageId(headers: string): string | null {
  if (!headers) return null;
  
  const match = headers.match(/Message-I[dD]:\s*<([^>]+)>/i);
  return match ? match[1] : null;
}

/**
 * Process email attachments
 */
async function processAttachments(
  formData: FormData,
  userId: string,
  supabase: any
): Promise<any[]> {
  const attachments = [];
  const startTime = Date.now();
  
  try {
    // Look for attachment fields (SendGrid uses attachment1, attachment2, etc.)
    for (let i = 1; i <= 10; i++) {
      const file = formData.get(`attachment${i}`) as File;
      if (!file) continue;
      
      const fileName = file.name || `attachment_${i}`;
      const fileSize = file.size;
      const contentType = file.type || "application/octet-stream";
      
      // Skip oversized attachments (>10MB)
      if (fileSize > 10 * 1024 * 1024) {
        logger.warn("attachment_too_large", { 
          fileName, 
          fileSize,
          max_size: 10 * 1024 * 1024 
        });
        continue;
      }
      
      // Generate unique path
      const timestamp = Date.now();
      const filePath = `${userId}/${timestamp}_${fileName}`;
      
      // Upload to storage
      const arrayBuffer = await file.arrayBuffer();
      const { data, error } = await supabase.storage
        .from("inbound-attachments")
        .upload(filePath, arrayBuffer, {
          contentType,
          upsert: false,
        });
      
      if (error) {
        logger.error("attachment_upload_failed", error, { fileName });
        continue;
      }
      
      attachments.push({
        filename: fileName,
        size: fileSize,
        content_type: contentType,
        storage_path: filePath,
        uploaded_at: new Date().toISOString(),
      });
    }
    
    logger.perf("attachments_processed", startTime, { 
      count: attachments.length 
    });
    
    return attachments;
  } catch (error) {
    logger.error("attachment_processing_error", error as Error);
    return attachments; // Return what we've processed so far
  }
}

serve(async (req) => {
  const startTime = Date.now();
  
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  
  // Only accept POST
  if (req.method !== "POST") {
    return errorResponse(
      new ApiError("Method not allowed", 405),
      corsHeaders
    );
  }
  
  let messageId: string | undefined;
  let aliasNorm: string | undefined;
  let userId: string | undefined;
  
  try {
    // Get configuration
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const hmacSecret = Deno.env.get("INBOUND_HMAC_SECRET");
    const allowedIps = Deno.env.get("INBOUND_ALLOWED_IPS");
    const legacySecret = Deno.env.get("INBOUND_PARSE_SECRET"); // For backward compatibility
    
    if (!supabaseUrl || !serviceKey) {
      throw new ServerError("Missing Supabase configuration");
    }
    
    // Authenticate request
    const authResult = await authenticateWebhook(req, {
      hmacSecret,
      allowedIps,
      legacySecret,
    });
    
    if (!authResult.authenticated) {
      logger.warn("auth_failed", {
        method: authResult.method,
        error: authResult.error,
        ip: getClientIp(req),
      });
      throw new AuthenticationError(authResult.error);
    }
    
    logger.info("auth_success", {
      method: authResult.method,
      ip: getClientIp(req),
    });
    
    // Parse form data
    const formData = await req.formData();
    
    // Extract email fields
    const toField = (formData.get("to") as string) ?? "";
    const fromField = (formData.get("from") as string) ?? "";
    const subject = (formData.get("subject") as string) ?? "";
    const textBody = (formData.get("text") as string) ?? "";
    const htmlBody = (formData.get("html") as string) ?? "";
    const headers = (formData.get("headers") as string) ?? "";
    const spamScore = (formData.get("spam_score") as string) ?? "";
    const envelope = (formData.get("envelope") as string) ?? "";
    
    // Extract provider timestamp
    const providerTimestamp = extractProviderTimestamp(headers);
    
    // Extract recipient email
    let recipientEmail = "";
    if (envelope) {
      try {
        const env = JSON.parse(envelope);
        if (env?.to?.[0]) {
          recipientEmail = String(env.to[0]).toLowerCase();
        }
      } catch (e) {
        logger.warn("envelope_parse_failed", { error: String(e) });
      }
    }
    
    // Fallback to parsing "to" field
    if (!recipientEmail && toField) {
      const match = toField.match(/<([^>]+)>/) || toField.match(/([^\s,;]+@[^\s,;]+)/);
      if (match) {
        recipientEmail = match[1].toLowerCase();
      }
    }
    
    if (!recipientEmail) {
      logger.info("no_recipient", { to: toField });
      return new Response("OK", { status: 200, headers: corsHeaders });
    }
    
    // Normalize alias
    aliasNorm = normalizeAlias(recipientEmail);
    
    if (!aliasNorm) {
      logger.info("invalid_alias", { email: recipientEmail });
      return new Response("OK", { status: 200, headers: corsHeaders });
    }
    
    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, serviceKey);
    
    // Look up user by alias
    const { data: aliasRow, error: aliasErr } = await supabase
      .from("inbound_aliases")
      .select("user_id")
      .eq("alias", aliasNorm)
      .maybeSingle();
    
    if (aliasErr) {
      logger.error("alias_lookup_error", aliasErr);
      throw new ServerError("Database error");
    }
    
    if (!aliasRow?.user_id) {
      logger.info("unknown_alias", { alias: aliasNorm });
      return new Response("OK", { status: 200, headers: corsHeaders });
    }
    
    userId = aliasRow.user_id;
    
    // Extract Message-ID for deduplication
    messageId = extractMessageId(headers) || `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    // Process attachments
    const attachments = await processAttachments(formData, userId, supabase);
    
    // Build metadata object
    const metadata = {
      from: fromField,
      to: toField,
      spam_score: spamScore,
      headers: headers.substring(0, 5000), // Limit header size
      attachments,
      received_at: new Date().toISOString(),
      provider_timestamp: providerTimestamp ? new Date(providerTimestamp).toISOString() : null,
    };
    
    // Build unified payload structure
    const inboxPayload = {
      // New structure fields
      user_id: userId,
      source_type: "email_in",
      title: subject || "No Subject",
      content: textBody,
      html: htmlBody,
      metadata,
      message_id: messageId,
      
      // Legacy payload_json for backward compatibility
      payload_json: {
        to: toField,
        from: fromField,
        subject,
        text: textBody,
        html: htmlBody,
        headers: headers.substring(0, 5000),
        spam_score: spamScore,
        attachments,
        received_at: metadata.received_at,
      },
    };
    
    // Insert into clipper_inbox
    const { error: insertErr } = await supabase
      .from("clipper_inbox")
      .insert(inboxPayload);
    
    if (insertErr) {
      // Check for duplicate message
      if (insertErr.code === "23505") {
        logger.info("duplicate_message", { 
          message_id: messageId,
          user_id: userId 
        });
        return new Response("OK (duplicate)", { status: 200, headers: corsHeaders });
      }
      
      logger.error("insert_error", insertErr, {
        user_id: userId,
        message_id: messageId,
      });
      throw new ServerError("Failed to store message");
    }
    
    // Log performance metrics
    logger.perf("email_processed", startTime, {
      user_id: userId,
      message_id: messageId,
      alias: aliasNorm,
      attachments: attachments.length,
      auth_method: authResult.method,
    });
    
    return new Response("OK", { status: 200, headers: corsHeaders });
    
  } catch (error) {
    // Log error with context
    logger.error("request_failed", error as Error, {
      message_id: messageId,
      alias: aliasNorm,
      user_id: userId,
      duration_ms: Date.now() - startTime,
    });
    
    // Return appropriate error response
    return errorResponse(error as Error, corsHeaders);
  }
});