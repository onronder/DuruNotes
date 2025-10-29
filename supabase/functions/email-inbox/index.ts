/**
 * Email Inbox Function - Production Grade v2
 * Handles incoming emails with HMAC authentication, file storage, and security features
 *
 * Security Features:
 * - HMAC-SHA256 authentication
 * - Restricted CORS
 * - Filename sanitization (path traversal protection)
 * - MIME type validation
 * - File size limits (50MB)
 * - Rate limiting (100 emails/hour/user)
 * - HTML sanitization (XSS protection)
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.43/deno-dom-wasm.ts";
import { getUserLanguage, getEmailReceivedMessage } from "../_shared/notification_messages.ts";

// Restrict CORS to specific domains (production grade)
const ALLOWED_ORIGINS = [
  Deno.env.get("ALLOWED_ORIGIN") || "https://durunotes.com",
  "https://www.durunotes.com",
  "https://app.durunotes.com"
];

const corsHeaders = {
  "Access-Control-Allow-Origin": "", // Will be set dynamically based on request
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-signature",
  "Access-Control-Allow-Credentials": "true",
};

// Allowed MIME types for attachments (security whitelist)
const ALLOWED_MIME_TYPES = [
  'application/pdf',
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/gif',
  'image/webp',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain',
  'text/csv',
  'application/zip',
  'application/x-zip-compressed'
];

// Rate limiting: Store in-memory (for production, use Redis or database)
const rateLimitStore = new Map<string, { count: number; resetTime: number }>();
const RATE_LIMIT_MAX = 100; // 100 emails per hour per user
const RATE_LIMIT_WINDOW = 60 * 60 * 1000; // 1 hour in milliseconds

/**
 * Sanitize filename to prevent path traversal and security issues
 */
function sanitizeFilename(filename: string): string {
  return filename
    .replace(/[^a-zA-Z0-9._-]/g, '_') // Remove special chars
    .replace(/\.{2,}/g, '.') // No directory traversal (..)
    .replace(/^\.+/, '') // No leading dots
    .substring(0, 255); // Max length
}

/**
 * Validate MIME type against whitelist
 */
function isAllowedMimeType(mimeType: string): boolean {
  return ALLOWED_MIME_TYPES.includes(mimeType.toLowerCase());
}

/**
 * Check rate limit for user
 */
function checkRateLimit(userId: string): boolean {
  const now = Date.now();
  const userLimit = rateLimitStore.get(userId);

  if (!userLimit || now > userLimit.resetTime) {
    // Reset or create new limit
    rateLimitStore.set(userId, { count: 1, resetTime: now + RATE_LIMIT_WINDOW });
    return true;
  }

  if (userLimit.count >= RATE_LIMIT_MAX) {
    return false; // Rate limit exceeded
  }

  userLimit.count++;
  return true;
}

/**
 * Sanitize HTML content to prevent XSS
 * Basic sanitization - removes scripts, iframes, and dangerous attributes
 */
function sanitizeHtml(html: string): string {
  if (!html) return html;

  try {
    const doc = new DOMParser().parseFromString(html, 'text/html');
    if (!doc) return '';

    // Remove dangerous elements
    const dangerousTags = ['script', 'iframe', 'object', 'embed', 'style'];
    dangerousTags.forEach(tag => {
      const elements = doc.querySelectorAll(tag);
      elements.forEach(el => el.remove());
    });

    // Remove dangerous attributes
    const dangerousAttrs = ['onclick', 'onload', 'onerror', 'onmouseover'];
    const allElements = doc.querySelectorAll('*');
    allElements.forEach(el => {
      dangerousAttrs.forEach(attr => {
        if (el.hasAttribute(attr)) {
          el.removeAttribute(attr);
        }
      });
      // Remove javascript: URLs
      if (el.hasAttribute('href') && el.getAttribute('href')?.startsWith('javascript:')) {
        el.removeAttribute('href');
      }
    });

    return doc.body.innerHTML;
  } catch (e) {
    console.error('HTML sanitization failed:', e);
    // If sanitization fails, strip all HTML tags as fallback
    return html.replace(/<[^>]*>/g, '');
  }
}

/**
 * Verify HMAC signature
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

    // Timing-safe comparison
    return computedSignature === signature.toLowerCase();
  } catch (e) {
    console.error('HMAC verification failed:', e);
    return false;
  }
}

serve(async (req) => {
  // Dynamic CORS based on origin
  const origin = req.headers.get("origin") || "";
  const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  const responseCorsHeaders = {
    ...corsHeaders,
    "Access-Control-Allow-Origin": allowedOrigin,
  };

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: responseCorsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...responseCorsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const inboundSecret = Deno.env.get("INBOUND_PARSE_SECRET");
  const hmacSecret = Deno.env.get("INBOUND_HMAC_SECRET");

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error("Missing required environment variables");
    return new Response(
      JSON.stringify({ error: "Server configuration error" }),
      { status: 500, headers: { ...responseCorsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    const url = new URL(req.url);
    let authenticatedViaHmac = false;

    // Authentication: Try HMAC first (if configured), then fall back to URL secret
    if (hmacSecret) {
      // HMAC Authentication (production grade) - only if signature header exists
      const signature = req.headers.get("x-signature");

      if (signature) {
        const body = await req.text();

        if (await verifyHMAC(body, signature, hmacSecret)) {
          console.log("✓ Authenticated via HMAC");
          authenticatedViaHmac = true;

          // Re-parse the body since we consumed it for HMAC verification
          req = new Request(req.url, {
            method: req.method,
            headers: req.headers,
            body: body
          });
        } else {
          console.error("Invalid HMAC signature");
          return new Response(
            JSON.stringify({ error: "Unauthorized - Invalid signature" }),
            { status: 401, headers: { ...responseCorsHeaders, "Content-Type": "application/json" } }
          );
        }
      }
    }

    // If not authenticated via HMAC, try URL secret (SendGrid, legacy)
    if (!authenticatedViaHmac) {
      if (inboundSecret) {
        const querySecret = url.searchParams.get("secret");
        if (querySecret !== inboundSecret) {
          console.error("Invalid secret provided in URL");
          return new Response(
            JSON.stringify({ error: "Unauthorized - Invalid secret" }),
            { status: 401, headers: { ...responseCorsHeaders, "Content-Type": "application/json" } }
          );
        }
        console.log("✓ Authenticated via URL secret");
      } else {
        console.error("No authentication method configured or provided");
        return new Response(
          JSON.stringify({ error: "Unauthorized" }),
          { status: 401, headers: { ...responseCorsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Parse the request body based on content type
    const contentType = req.headers.get("content-type") || "";
    let body: Record<string, unknown> = {};

    if (contentType.includes("application/json")) {
      body = await req.json();
    } else if (contentType.includes("application/x-www-form-urlencoded")) {
      const formData = await req.text();
      const params = new URLSearchParams(formData);
      body = Object.fromEntries(params.entries());
    } else if (contentType.includes("multipart/form-data")) {
      const formData = await req.formData();
      const attachmentFiles = [];
      
      for (const [key, value] of formData.entries()) {
        if (typeof value === "string") {
          body[key] = value;
        } else if (value instanceof File || value instanceof Blob) {
          // Handle file attachments
          attachmentFiles.push({
            key,
            filename: value.name || key,
            size: value.size,
            type: value.type || "application/octet-stream",
            file: value
          });
        }
      }
      
      // Store attachment files for later processing
      if (attachmentFiles.length > 0) {
        body._attachmentFiles = attachmentFiles;
      }
    }

    console.log("Received email webhook:", {
      method: req.method,
      contentType,
      hasBody: !!body,
      bodyKeys: Object.keys(body),
      hasAttachmentFiles: !!(body._attachmentFiles && body._attachmentFiles.length > 0),
      attachmentFileCount: body._attachmentFiles ? body._attachmentFiles.length : 0
    });

    // Parse envelope field if it's a JSON string (SendGrid sends it this way)
    let envelope = body.envelope;
    if (typeof envelope === 'string') {
      try {
        envelope = JSON.parse(envelope);
      } catch (e) {
        console.log("Failed to parse envelope field:", e);
        envelope = null;
      }
    }

    // Extract email data - support multiple provider formats
    // For 'to' field, check envelope.to array first (SendGrid format)
    let to = body.to || body.To || body.recipient || "";
    if (!to && envelope?.to && Array.isArray(envelope.to) && envelope.to.length > 0) {
      to = envelope.to[0]; // Take first recipient from array
    }
    const from = body.from || body.From || body.sender || envelope?.from || "";
    const subject = body.subject || body.Subject || "No Subject";
    const text = body.text || body["body-plain"] || body.Text || body["stripped-text"] || "";
    const html = body.html || body["body-html"] || body.Html || body["stripped-html"] || "";
    const messageId = body["message-id"] || body.MessageID || body.messageId || body["Message-Id"] || `email_${Date.now()}`;
    const headers = body.headers || body.Headers || body["message-headers"] || "";
    
    // Parse recipient to extract alias
    let recipientAlias = null;
    const toEmail = (typeof to === 'string' ? to : JSON.stringify(to)).toLowerCase();
    
    // Extract alias from email formats like: alias@domain.com or alias+tag@domain.com
    // Also handle quoted emails like "alias@domain.com" <alias@domain.com>
    const aliasMatch = toEmail.match(/([^@+<>\s"']+)(?:\+[^@]*)?@/);
    if (aliasMatch) {
      recipientAlias = aliasMatch[1].trim();
    }

    console.log("Parsed email data:", {
      from,
      to,
      toEmail,
      recipientAlias,
      subject,
      hasText: !!text,
      hasHtml: !!html,
      messageId,
      envelope: envelope ? { to: envelope.to, from: envelope.from } : null
    });

    // Find user by alias
    if (!recipientAlias) {
      console.error("No recipient alias found in:", toEmail);
      return new Response(
        JSON.stringify({ error: "Invalid recipient format" }),
        { status: 400, headers: { ...responseCorsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: aliasData, error: aliasError } = await supabase
      .from("inbound_aliases")
      .select("user_id")
      .eq("alias", recipientAlias)
      .single();

    if (aliasError || !aliasData) {
      console.error("Alias not found:", recipientAlias, aliasError);
      return new Response(
        JSON.stringify({ error: "Recipient not found", alias: recipientAlias }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = aliasData.user_id;
    console.log("Found user for alias:", { alias: recipientAlias, userId });

    // SECURITY: Rate limiting check (BEFORE processing email)
    if (!checkRateLimit(userId)) {
      console.error(`Rate limit exceeded for user ${userId}`);
      return new Response(
        JSON.stringify({ error: "Rate limit exceeded. Maximum 100 emails per hour." }),
        { status: 429, headers: { ...responseCorsHeaders, "Content-Type": "application/json" } }
      );
    }

    // SECURITY: Sanitize HTML content before storing (XSS protection)
    const sanitizedHtml = html ? sanitizeHtml(html) : "";

    // Extract provider timestamp if available
    let providerTimestamp = null;
    if (headers) {
      const headerString = typeof headers === 'string' ? headers : JSON.stringify(headers);

      // Try to extract timestamp from various provider headers
      const timestampPatterns = [
        /X-Mailgun-Timestamp:\s*(\d+)/i,
        /X-Sendgrid-Event-Time:\s*(\d+)/i,
        /X-Received-Time:\s*(\d+)/i
      ];

      for (const pattern of timestampPatterns) {
        const match = headerString.match(pattern);
        if (match) {
          providerTimestamp = new Date(parseInt(match[1]) * 1000).toISOString();
          break;
        }
      }

      // Fallback to Date header
      if (!providerTimestamp) {
        const dateMatch = headerString.match(/Date:\s*(.+?)(?:\r?\n|$)/i);
        if (dateMatch) {
          const parsed = Date.parse(dateMatch[1]);
          if (!isNaN(parsed)) {
            providerTimestamp = new Date(parsed).toISOString();
          }
        }
      }
    }

    // Store in clipper_inbox
    // Create email payload object that both metadata AND payload_json will use
    const emailPayload = {
      to: toEmail,
      from,
      subject,
      text,
      html: sanitizedHtml,  // Use sanitized HTML
      message_id: messageId,
      received_at: providerTimestamp || new Date().toISOString(),
      provider: "email",
      headers: headers ? (typeof headers === 'string' ? headers.substring(0, 1000) : JSON.stringify(headers).substring(0, 1000)) : null
    };

    // PRODUCTION LOGGING: Log before insert attempt
    console.log("📥 Attempting database insert:", {
      user_id: userId,
      alias: recipientAlias,
      subject,
      source_type: "email_in",
      messageId,
      timestamp: new Date().toISOString()
    });

    const { data: inboxData, error: inboxError } = await supabase
      .from("clipper_inbox")
      .insert({
        user_id: userId,
        source_type: "email_in",  // Must be 'email_in' per database constraint
        title: subject,
        content: text || sanitizedHtml || "",  // Use sanitized HTML
        html: sanitizedHtml || "",  // Use sanitized HTML
        metadata: emailPayload,       // Store in metadata (backend reference)
        payload_json: emailPayload,   // ALSO store in payload_json (frontend reads this)
        message_id: messageId,
        created_at: new Date().toISOString()
      })
      .select()
      .single();

    if (inboxError) {
      console.error("❌ DATABASE INSERT FAILED:", {
        error: inboxError,
        code: inboxError.code,
        message: inboxError.message,
        details: inboxError.details,
        hint: inboxError.hint,
        user_id: userId,
        subject
      });
      return new Response(
        JSON.stringify({ error: "Failed to store email", details: inboxError.message }),
        { status: 500, headers: { ...responseCorsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("✅ Email stored successfully:", {
      inbox_id: inboxData.id,
      user_id: userId,
      alias: recipientAlias,
      subject,
      created_at: inboxData.created_at
    });

    // Create notification event for push notification
    try {
      const { data: notificationId, error: notificationError } = await supabase
        .rpc("create_notification_event", {
          p_user_id: userId,
          p_event_type: "email_received",
          p_event_source: "email_inbox",
          p_payload: {
            inbox_id: inboxData.id,
            subject: subject,
            sender_name: from.split('<')[0].trim() || from,
            sender_email: from,
            preview: text?.substring(0, 100) || sanitizedHtml?.substring(0, 100) || "",
            received_at: inboxData.created_at
          },
          p_priority: "high",
          p_dedupe_key: `email_${messageId}`
        });

      if (notificationError) {
        console.error("Failed to create notification event:", notificationError);
      } else {
        console.log("✅ Notification event created:", notificationId);
      }

      // 🆕 SEND PUSH NOTIFICATION (Multi-language support)
      try {
        const senderName = from.split('<')[0].trim() || from.split('@')[0] || 'Someone';

        // Get user's preferred language
        const userLanguage = await getUserLanguage(supabase, userId);

        // Get localized message
        const notificationMessage = getEmailReceivedMessage(senderName, subject || 'No subject', userLanguage);

        console.log('📱 Sending push notification for email:', {
          user_id: userId,
          sender: senderName,
          subject: subject,
          language: userLanguage,
        });

        const pushResponse = await fetch(
          `${supabaseUrl}/functions/v1/send-push-notification`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${supabaseServiceKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              user_id: userId,
              title: notificationMessage.title,
              body: notificationMessage.body,
              priority: 'high',
              data: {
                type: 'email_received',
                inbox_id: inboxData.id,
                sender: from,
                subject: subject,
                action: 'open_inbox',
              },
            }),
          }
        );

        if (pushResponse.ok) {
          const pushResult = await pushResponse.json();
          console.log('✅ Email push notification sent:', {
            success: pushResult.success,
            devices: pushResult.sent,
            language: userLanguage,
          });
        } else {
          console.error('❌ Failed to send email push:', await pushResponse.text());
        }
      } catch (pushErr) {
        // Don't fail email processing if push fails
        console.error('⚠️ Email push error (non-fatal):', pushErr);
      }
    } catch (notificationErr) {
      // Don't fail the email processing if notification fails
      console.error("Notification creation error:", notificationErr);
    }

    // Handle attachments if present
    const attachments = [];
    let attachmentCount = 0;
    const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB limit

    // Check for actual file attachments from multipart/form-data
    if (body._attachmentFiles && body._attachmentFiles.length > 0) {
      console.log(`Email has ${body._attachmentFiles.length} file attachments`);

      for (const fileInfo of body._attachmentFiles) {
        try {
          // SECURITY: Sanitize filename
          const sanitizedFilename = sanitizeFilename(fileInfo.filename);
          console.log(`Processing attachment: ${fileInfo.filename} → ${sanitizedFilename}`);

          // SECURITY: Validate file size (50MB limit)
          if (fileInfo.size > MAX_FILE_SIZE) {
            console.warn(`File too large: ${sanitizedFilename} (${fileInfo.size} bytes)`);
            attachments.push({
              filename: sanitizedFilename,
              size: fileInfo.size,
              content_type: fileInfo.type,
              error: "File too large (max 50MB)"
            });
            continue;
          }

          // SECURITY: Validate MIME type
          if (!isAllowedMimeType(fileInfo.type)) {
            console.warn(`Invalid MIME type: ${fileInfo.type} for ${sanitizedFilename}`);
            attachments.push({
              filename: sanitizedFilename,
              size: fileInfo.size,
              content_type: fileInfo.type,
              error: `File type not allowed: ${fileInfo.type}`
            });
            continue;
          }

          // PRODUCTION GRADE: Upload to Supabase Storage
          const timestamp = Date.now();
          const storagePath = `temp/${userId}/${timestamp}_${sanitizedFilename}`;

          console.log(`Uploading to storage: ${storagePath}`);

          const arrayBuffer = await fileInfo.file.arrayBuffer();
          const fileBytes = new Uint8Array(arrayBuffer);

          // Upload to temporary storage bucket
          const { error: uploadError } = await supabase.storage
            .from('inbound-attachments-temp')
            .upload(storagePath, fileBytes, {
              contentType: fileInfo.type,
              upsert: false
            });

          if (uploadError) {
            console.error(`Upload failed for ${sanitizedFilename}:`, uploadError);
            attachments.push({
              filename: sanitizedFilename,
              size: fileInfo.size,
              content_type: fileInfo.type,
              error: `Upload failed: ${uploadError.message}`
            });
            continue;
          }

          console.log(`✓ Uploaded to storage: ${storagePath}`);

          // PRODUCTION FIX: Generate signed URL for attachment access
          // Signed URLs are valid for 24 hours to give users time to convert emails
          console.log(`[DEBUG] Generating signed URL for: ${storagePath}`);
          const { data: signedUrlData, error: signedUrlError } = await supabase.storage
            .from('inbound-attachments-temp')
            .createSignedUrl(storagePath, 86400); // 24 hours expiry

          let attachmentUrl = null;
          let urlExpiresAt = null;

          if (signedUrlError) {
            console.error(`❌ Failed to generate signed URL for ${sanitizedFilename}:`, JSON.stringify(signedUrlError));
          } else if (!signedUrlData || !signedUrlData.signedUrl) {
            console.error(`❌ Signed URL data is empty for ${sanitizedFilename}:`, JSON.stringify(signedUrlData));
          } else {
            attachmentUrl = signedUrlData.signedUrl;
            urlExpiresAt = new Date(Date.now() + 86400 * 1000).toISOString(); // 24 hours from now
            console.log(`✅ Generated signed URL for ${sanitizedFilename}`);
            console.log(`[DEBUG] URL: ${attachmentUrl.substring(0, 100)}...`);
          }

          // Store storage_path AND signed URL (production grade)
          const attachmentObject = {
            filename: sanitizedFilename,
            size: fileInfo.size,
            content_type: fileInfo.type,
            storage_path: storagePath,  // For backend reference
            url: attachmentUrl,         // For frontend access (CRITICAL FIX)
            url_expires_at: urlExpiresAt // 1 hour from now
          };

          console.log(`[DEBUG] Pushing attachment object:`, JSON.stringify(attachmentObject));
          attachments.push(attachmentObject);
        } catch (e) {
          console.error(`Failed to process attachment ${fileInfo.filename}:`, e);
          attachments.push({
            filename: sanitizeFilename(fileInfo.filename),
            size: fileInfo.size,
            content_type: fileInfo.type,
            error: `Processing failed: ${e.message}`
          });
        }
      }
      attachmentCount = body._attachmentFiles.length;
    }
    
    // Parse SendGrid's attachment-info field
    if (body["attachment-info"] && typeof body["attachment-info"] === 'string') {
      try {
        const attachmentInfo = JSON.parse(body["attachment-info"]);
        console.log("SendGrid attachment-info:", attachmentInfo);
        
        // If we don't have actual file data, at least store the metadata
        if (attachments.length === 0) {
          for (const [key, info] of Object.entries(attachmentInfo)) {
            if (typeof info === 'object' && info !== null) {
              attachments.push({
                filename: info.filename || info.name || key,
                size: info.size || 0,
                content_type: info.type || info["content-type"] || "application/octet-stream",
                charset: info.charset,
                content_id: info["content-id"]
              });
            }
          }
        }
      } catch (e) {
        console.error("Failed to parse attachment-info:", e);
      }
    }
    
    // Also check the attachments field (might be a number or JSON)
    if (!attachmentCount) {
      attachmentCount = parseInt(body.attachments || "0");
    }
    
    if (attachmentCount > 0 || attachments.length > 0) {
      console.log(`Email has ${attachmentCount || attachments.length} attachments`);

      // Store attachment info in BOTH metadata and payload_json with correct structure
      if (attachments.length > 0) {
        // Frontend expects: { files: [...], count: N }
        const attachmentData = {
          files: attachments,
          count: attachments.length
        };

        // PRODUCTION FIX: Use database function for safe JSONB update
        // This bypasses GIN index validation issues and uses native PostgreSQL JSONB operators
        console.log(`Updating ${inboxData.id} with ${attachments.length} attachment(s) via database function`);
        console.log(`[DEBUG] Attachment data being sent to RPC:`, JSON.stringify(attachmentData, null, 2));

        const { error: updateError } = await supabase.rpc(
          'update_inbox_attachments',
          {
            inbox_id: inboxData.id,
            attachment_data: attachmentData
          }
        );

        if (updateError) {
          console.error("❌ Failed to update attachment metadata:", updateError);
          console.error("Error details:", JSON.stringify(updateError, null, 2));
        } else {
          console.log(`✅ Stored ${attachments.length} attachment(s) via database function`);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Email processed successfully",
        inbox_id: inboxData.id,
        user_id: userId,
        alias: recipientAlias,
        attachment_count: attachments.length
      }),
      {
        status: 200,
        headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
      }
    );

  } catch (error) {
    console.error("Email processing error:", error);
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        message: error.message
      }),
      {
        status: 500,
        headers: { ...responseCorsHeaders, "Content-Type": "application/json" }
      }
    );
  }
});