/**
 * Email Inbox Function - Fixed Version
 * Handles incoming emails with secret authentication
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const inboundSecret = Deno.env.get("INBOUND_PARSE_SECRET");

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error("Missing required environment variables");
    return new Response(
      JSON.stringify({ error: "Server configuration error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    // Check secret in query params
    const url = new URL(req.url);
    const querySecret = url.searchParams.get("secret");
    
    if (inboundSecret && querySecret !== inboundSecret) {
      console.error("Invalid secret provided");
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse the request body based on content type
    const contentType = req.headers.get("content-type") || "";
    let body: any = {};

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
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
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
    const { data: inboxData, error: inboxError } = await supabase
      .from("clipper_inbox")
      .insert({
        user_id: userId,
        source_type: "email_in",  // Must be 'email_in' per database constraint
        title: subject,
        content: text || html || "",
        html: html || "",
        metadata: {
          from,
          to: toEmail,
          message_id: messageId,
          received_at: providerTimestamp || new Date().toISOString(),
          provider: "email",
          headers: headers ? (typeof headers === 'string' ? headers.substring(0, 1000) : JSON.stringify(headers).substring(0, 1000)) : null
        },
        message_id: messageId,
        created_at: new Date().toISOString()
      })
      .select()
      .single();

    if (inboxError) {
      console.error("Failed to store email:", inboxError);
      return new Response(
        JSON.stringify({ error: "Failed to store email", details: inboxError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("Email stored successfully:", inboxData.id);

    // Handle attachments if present
    const attachments = [];
    let attachmentCount = 0;
    
    // Check for actual file attachments from multipart/form-data
    if (body._attachmentFiles && body._attachmentFiles.length > 0) {
      console.log(`Email has ${body._attachmentFiles.length} file attachments`);
      
      for (const fileInfo of body._attachmentFiles) {
        try {
          // Convert file to base64 for storage
          const arrayBuffer = await fileInfo.file.arrayBuffer();
          const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));
          
          attachments.push({
            filename: fileInfo.filename,
            size: fileInfo.size,
            content_type: fileInfo.type,
            content: base64  // Store base64 encoded content
          });
        } catch (e) {
          console.error(`Failed to process attachment ${fileInfo.filename}:`, e);
          // Still record the attachment metadata even if we can't get the content
          attachments.push({
            filename: fileInfo.filename,
            size: fileInfo.size,
            content_type: fileInfo.type,
            error: "Failed to process content"
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
      
      // Store attachment info in metadata
      if (attachments.length > 0) {
        const { error: updateError } = await supabase
          .from("clipper_inbox")
          .update({
            metadata: {
              ...inboxData.metadata,
              attachments: attachments,
              attachment_count: attachments.length
            }
          })
          .eq("id", inboxData.id);
          
        if (updateError) {
          console.error("Failed to update attachment metadata:", updateError);
        } else {
          console.log(`Stored ${attachments.length} attachment(s) in metadata`);
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
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
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
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});