import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function clientIp(req: Request): string | null {
  const cf = req.headers.get("cf-connecting-ip");
  if (cf) return cf;
  const xff = req.headers.get("x-forwarded-for");
  return xff ? xff.split(",")[0].trim() : null;
}

function ipAllowed(ip: string | null, allowedCsv?: string): boolean {
  if (!allowedCsv) return true; // disabled if not set
  if (!ip) return false;
  const allowed = new Set(allowedCsv.split(",").map((s) => s.trim()));
  return allowed.has(ip);
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const inboundSecret = Deno.env.get("INBOUND_PARSE_SECRET");
    const allowedIps = Deno.env.get("INBOUND_ALLOWED_IPS"); // optional CSV

    if (!supabaseUrl || !serviceKey) {
      console.error("Missing Supabase config");
      return new Response("Server Misconfigured", { status: 500, headers: corsHeaders });
    }

    // Gate 1: shared secret
    const url = new URL(req.url);
    if (!inboundSecret || url.searchParams.get("secret") !== inboundSecret) {
      return new Response("Unauthorized", { status: 401, headers: corsHeaders });
    }

    // Gate 2 (optional): IP allow-list
    const ip = clientIp(req);
    if (!ipAllowed(ip, allowedIps)) {
      return new Response("Forbidden", { status: 403, headers: corsHeaders });
    }

    const supabase = createClient(supabaseUrl, serviceKey);

    // Parse multipart form
    const formData = await req.formData();

    const toField    = (formData.get("to") as string) ?? "";
    const fromField  = (formData.get("from") as string) ?? "";
    const subject    = (formData.get("subject") as string) ?? "";
    const textBody   = (formData.get("text") as string) ?? "";
    const htmlBody   = (formData.get("html") as string) ?? "";
    const headers    = (formData.get("headers") as string) ?? "";
    const spamScore  = (formData.get("spam_score") as string) ?? "";
    const envelope   = (formData.get("envelope") as string) ?? "";

    // Prefer exact recipient from envelope
    let recipientEmail = "";
    if (envelope) {
      try {
        const env = JSON.parse(envelope);
        if (env?.to && Array.isArray(env.to) && env.to.length > 0) {
          recipientEmail = String(env.to[0]).toLowerCase();
        }
      } catch (e) {
        console.warn("Envelope parse failed:", e);
      }
    }
    // Fallback: parse "to"
    if (!recipientEmail && toField) {
      const m = toField.match(/<([^>]+)>/) || toField.match(/([^\s,;]+@[^\s,;]+)/);
      if (m) recipientEmail = m[1].toLowerCase();
    }
    if (!recipientEmail) {
      console.warn("No recipient; ignoring");
      return new Response("OK", { status: 200, headers: corsHeaders });
    }

    // Extract alias (local-part)
    const [localPart] = recipientEmail.split("@");
    if (!localPart) return new Response("OK", { status: 200, headers: corsHeaders });

    // Map alias -> user
    const { data: aliasRow, error: aliasErr } = await supabase
      .from("inbound_aliases")
      .select("user_id")
      .eq("alias", localPart)
      .maybeSingle();

    if (aliasErr) {
      console.error("Alias lookup error:", aliasErr);
      // transient → allow SendGrid retry
      return new Response("Temporary error", { status: 500, headers: corsHeaders });
    }
    if (!aliasRow?.user_id) {
      console.log("Unknown alias:", localPart);
      // unknown → do NOT retry
      return new Response("OK", { status: 200, headers: corsHeaders });
    }
    const userId: string = aliasRow.user_id;

    // Extract Message-ID (case-insensitive)
    let messageId: string | undefined;
    if (headers) {
      const m = headers.match(/Message-Id:\s*<([^>]+)>/i) || headers.match(/Message-ID:\s*<([^>]+)>/i);
      if (m) messageId = m[1];
    }

    // Attachments
    const attachCount = parseInt(((formData.get("attachments") as string) ?? "0"), 10) || 0;
    const attachments: { filename: string; type: string; size: number; path?: string }[] = [];

    let attachInfo: any = {};
    if (attachCount > 0) {
      try {
        const infoStr = formData.get("attachment-info") as string;
        if (infoStr) attachInfo = JSON.parse(infoStr);
      } catch (e) {
        console.warn("attachment-info parse failed:", e);
      }

      const emailFolder = `${userId}/${Date.now()}-${(messageId ?? "nomid").slice(0, 12)}`;
      const MAX_SIZE = 50 * 1024 * 1024; // 50MB
      const blocked = new Set(['application/x-dosexec', 'application/x-msdownload', 'application/x-msdos-program']);

      for (let i = 1; i <= attachCount; i++) {
        const file = formData.get(`attachment${i}`);
        if (file instanceof File) {
          const info = attachInfo[`attachment${i}`] ?? {};
          const filename = info.filename || file.name || `attachment${i}`;
          const type     = info.type || file.type || "application/octet-stream";
          const size     = file.size;

          // Skip oversized attachments
          if (size > MAX_SIZE) {
            console.warn('Skipping oversized attachment', { name: filename, size: size });
            continue;
          }

          // Skip blocked MIME types
          if (blocked.has(type.toLowerCase())) {
            console.warn('Skipping blocked MIME type', { name: filename, type: type });
            continue;
          }

          const filePath = `${emailFolder}/${filename}`;
          const { error: upErr } = await supabase.storage
            .from("inbound-attachments")
            .upload(filePath, file, { contentType: type, upsert: false });

          if (upErr) {
            console.error("Attachment upload failed:", filePath, upErr);
          } else {
            attachments.push({ filename, type, size, path: filePath }); // store path only
          }
        }
      }
    }

    // Build payload JSON
    const payload = {
      to: recipientEmail,
      from: fromField,
      subject: subject || "(no subject)",
      text: textBody || undefined,
      html: htmlBody || undefined,
      message_id: messageId,
      spam_score: spamScore || undefined,
      headers: headers && headers.length < 10000 ? headers : undefined,
      attachments: attachments.length > 0 ? { count: attachments.length, files: attachments } : undefined,
      received_at: new Date().toISOString(),
    };

    // Insert inbox row (user-scoped unique index handles duplicates)
    const { error: insErr } = await supabase
      .from("clipper_inbox")
      .insert({
        user_id: userId,
        source_type: "email_in",
        payload_json: payload,
        message_id: messageId ?? null,
      });

    if (insErr) {
      if (insErr.code === "23505") {
        console.log("Duplicate message, skipping:", messageId);
        return new Response("OK", { status: 200, headers: corsHeaders });
      }
      console.error("DB insert failed:", insErr);
      return new Response("Temporary error", { status: 500, headers: corsHeaders });
    }

    return new Response("OK", { status: 200, headers: corsHeaders });
  } catch (e) {
    console.error("Unhandled email_inbox error:", e);
    return new Response("Temporary error", { status: 500, headers: corsHeaders });
  }
});
