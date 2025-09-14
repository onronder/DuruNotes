import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Extract provider timestamp from headers
function extractProviderTimestamp(headers: string): number | null {
  if (!headers) return null;
  
  // Mailgun: X-Mailgun-Timestamp (Unix timestamp)
  const mailgunMatch = headers.match(/X-Mailgun-Timestamp:\s*(\d+)/i);
  if (mailgunMatch) {
    return parseInt(mailgunMatch[1]) * 1000; // Convert to milliseconds
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

// Normalize alias (remove plus addressing, etc)
function normalizeAlias(email: string): string {
  const [localPart] = email.split("@");
  if (!localPart) return "";
  
  // Remove plus addressing (e.g., alias+tag@domain -> alias@domain)
  let normalized = localPart.split("+")[0];
  
  return normalized.toLowerCase();
}

serve(async (req) => {
  // Start timing immediately
  const t_recv = Date.now();
  const edge_region = Deno.env.get("DENO_REGION") || "unknown";
  const project_ref = Deno.env.get("SUPABASE_PROJECT_REF") || "unknown";
  
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }

  let messageId: string | undefined;
  let aliasNorm: string | undefined;
  let t_provider: number | null = null;
  let t_insert: number | undefined;

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const inboundSecret = Deno.env.get("INBOUND_PARSE_SECRET");

    if (!supabaseUrl || !serviceKey) {
      console.error("Missing Supabase config");
      return new Response("Server Misconfigured", { status: 500, headers: corsHeaders });
    }

    // Simple secret verification
    const url = new URL(req.url);
    const providedSecret = url.searchParams.get("secret");
    
    if (!inboundSecret || providedSecret !== inboundSecret) {
      return new Response("Unauthorized", { status: 401, headers: corsHeaders });
    }

    // Parse form data - minimal processing
    const formData = await req.formData();
    
    // Extract critical fields only
    const envelope = (formData.get("envelope") as string) ?? "";
    const toField = (formData.get("to") as string) ?? "";
    const headers = (formData.get("headers") as string) ?? "";
    
    // Extract provider timestamp from headers
    t_provider = extractProviderTimestamp(headers);
    
    // Fast recipient extraction
    let recipientEmail = "";
    if (envelope) {
      try {
        const env = JSON.parse(envelope);
        if (env?.to?.[0]) {
          recipientEmail = String(env.to[0]).toLowerCase();
        }
      } catch {
        // Silent fail, use fallback
      }
    }
    
    if (!recipientEmail && toField) {
      const m = toField.match(/<([^>]+)>/) || toField.match(/([^\s,;]+@[^\s,;]+)/);
      if (m) recipientEmail = m[1].toLowerCase();
    }
    
    if (!recipientEmail) {
      // No recipient, return fast
      return new Response("OK", { status: 200, headers: corsHeaders });
    }

    // Extract and normalize alias
    const [localPart] = recipientEmail.split("@");
    if (!localPart) {
      return new Response("OK", { status: 200, headers: corsHeaders });
    }
    
    aliasNorm = normalizeAlias(recipientEmail);

    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, serviceKey);

    // Fast alias lookup - single query
    const { data: aliasRow, error: aliasErr } = await supabase
      .from("inbound_aliases")
      .select("user_id")
      .eq("alias", aliasNorm)
      .maybeSingle();

    if (aliasErr) {
      console.error("Alias lookup error:", aliasErr);
      return new Response("Temporary error", { status: 500, headers: corsHeaders });
    }
    
    if (!aliasRow?.user_id) {
      // Unknown alias, silently accept
      return new Response("OK", { status: 200, headers: corsHeaders });
    }
    
    const userId: string = aliasRow.user_id;

    // Extract Message-ID for deduplication
    if (headers) {
      const m = headers.match(/Message-I[dD]:\s*<([^>]+)>/i);
      if (m) messageId = m[1];
    }
    
    // Generate ID if not present
    if (!messageId) {
      messageId = `gen-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    }

    // Build minimal payload - defer heavy processing
    const payload = {
      to: recipientEmail,
      from: (formData.get("from") as string) ?? "",
      subject: (formData.get("subject") as string) ?? "(no subject)",
      text: (formData.get("text") as string) ?? undefined,
      html: (formData.get("html") as string) ?? undefined,
      message_id: messageId,
      headers: headers.length < 10000 ? headers : undefined,
      received_at: new Date().toISOString(),
      // Mark attachments as pending (processed by app later)
      attachments_pending: formData.has("attachment1"),
      provider_timestamp: t_provider ? new Date(t_provider).toISOString() : undefined,
    };

    // Fast insert - let unique index handle duplicates
    const { error: insErr } = await supabase
      .from("clipper_inbox")
      .insert({
        user_id: userId,
        source_type: "email_in",
        // New structure fields
        title: payload.subject || 'Email',
        content: payload.text || '',
        html: payload.html || null,
        metadata: {
          to: payload.to,
          from: payload.from,
          headers: payload.headers,
          received_at: payload.received_at,
          attachments_pending: payload.attachments_pending,
          provider_timestamp: payload.provider_timestamp,
          attachments: payload.attachments, // Include if present
        },
        // Backward compatibility - keep payload_json
        payload_json: payload,
        message_id: messageId,
      });

    t_insert = Date.now();

    // Log structured latency data
    const latencyLog = {
      event: "email_in_latency",
      msg_id: messageId,
      t_provider_to_edge_ms: t_provider ? t_recv - t_provider : null,
      t_edge_to_insert_ms: t_insert - t_recv,
      t_total_edge_ms: Date.now() - t_recv,
      project_ref,
      edge_region,
      alias_norm: aliasNorm,
      source: "email_in",
      duplicate: insErr?.code === "23505",
    };
    
    console.log(JSON.stringify(latencyLog));

    if (insErr) {
      if (insErr.code === "23505") {
        // Duplicate - still success
        return new Response("OK", { status: 200, headers: corsHeaders });
      }
      console.error("DB insert failed:", { code: insErr.code, message: insErr.message });
      return new Response("Temporary error", { status: 500, headers: corsHeaders });
    }

    // Broadcast inbox change (fallback when DB replication is unavailable)
    try {
      const broadcastRes = await fetch(`${supabaseUrl}/realtime/v1/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': serviceKey,
          'Authorization': `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          topic: `realtime:inbox_realtime_${userId}`,
          event: 'broadcast',
          payload: { event: 'inbox_changed', user_id: userId },
        }),
      });
      console.log(JSON.stringify({ event: 'broadcast_sent', ok: broadcastRes.ok }));
    } catch (e) {
      console.log(JSON.stringify({ event: 'broadcast_failed', error: String(e) }));
    }

    // Trigger push notification for new email
    if (!insErr || insErr.code !== "23505") {
      // Only trigger notification if it's not a duplicate
      try {
        // Create notification event
        await supabase.rpc("create_notification_event", {
          p_user_id: userId,
          p_event_type: "email_received",
          p_event_source: "email_in",
          p_payload: {
            inbox_id: messageId,
            from: payload.from,
            subject: payload.subject,
            preview: payload.text ? payload.text.substring(0, 100) : "",
            has_attachments: payload.attachments_pending || false,
            received_at: payload.received_at,
          },
          p_priority: "high",
          p_dedupe_key: `email_${messageId}`,
        });
        
        console.log(JSON.stringify({
          event: "notification_triggered",
          type: "email_received",
          user_id: userId,
          msg_id: messageId,
        }));
      } catch (notifErr) {
        // Log but don't fail the request
        console.error(JSON.stringify({
          event: "notification_trigger_failed",
          error: String(notifErr),
          user_id: userId,
          msg_id: messageId,
        }));
      }
    }

    // Return immediately - attachments handled asynchronously by app
    return new Response("OK", { status: 200, headers: corsHeaders });
    
  } catch (e) {
    // Log error with timing
    const errorLog = {
      event: "email_in_error",
      msg_id: messageId || "unknown",
      t_total_edge_ms: Date.now() - t_recv,
      project_ref,
      edge_region,
      alias_norm: aliasNorm || "unknown",
      source: "email_in",
      error: String(e),
    };
    console.error(JSON.stringify(errorLog));
    
    return new Response("Temporary error", { status: 500, headers: corsHeaders });
  }
});
