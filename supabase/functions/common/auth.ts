/**
 * Authentication Helper Module
 * Provides HMAC verification and authentication utilities
 */

import { encode } from "https://deno.land/std@0.224.0/encoding/hex.ts";

export interface AuthConfig {
  hmacSecret?: string;
  allowedIps?: string;
  legacySecret?: string; // For backward compatibility
}

/**
 * Verify HMAC-SHA256 signature
 */
export async function verifyHmacSignature(
  payload: string,
  signature: string,
  secret: string
): Promise<boolean> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const msgData = encoder.encode(payload);
  
  const key = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  
  const signatureBuffer = await crypto.subtle.sign("HMAC", key, msgData);
  const expectedSig = encode(new Uint8Array(signatureBuffer));
  
  // Constant-time comparison to prevent timing attacks
  if (expectedSig.length !== signature.length) {
    return false;
  }
  
  let result = 0;
  for (let i = 0; i < expectedSig.length; i++) {
    result |= expectedSig.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  
  return result === 0;
}

/**
 * Extract client IP from request headers
 */
export function getClientIp(req: Request): string | null {
  // Cloudflare
  const cf = req.headers.get("cf-connecting-ip");
  if (cf) return cf;
  
  // Standard proxy headers
  const xff = req.headers.get("x-forwarded-for");
  if (xff) {
    return xff.split(",")[0].trim();
  }
  
  // Real IP header
  const realIp = req.headers.get("x-real-ip");
  if (realIp) return realIp;
  
  return null;
}

/**
 * Check if IP is in allow list
 */
export function isIpAllowed(ip: string | null, allowList?: string): boolean {
  // If no allow list configured, allow all
  if (!allowList) return true;
  
  // If we can't determine IP, deny for security
  if (!ip) return false;
  
  const allowed = new Set(
    allowList.split(",").map(s => s.trim()).filter(s => s.length > 0)
  );
  
  return allowed.has(ip);
}

/**
 * Authenticate webhook request
 */
export async function authenticateWebhook(
  req: Request,
  config: AuthConfig
): Promise<{ authenticated: boolean; method: string; error?: string }> {
  // Check HMAC signature (preferred)
  const webhookSignature = req.headers.get("x-webhook-signature");
  const hmacSignature = req.headers.get("x-hmac-signature");
  const signature = webhookSignature || hmacSignature;
  
  if (signature && config.hmacSecret) {
    const payload = await req.clone().text();
    const isValid = await verifyHmacSignature(payload, signature, config.hmacSecret);
    
    if (isValid) {
      return { authenticated: true, method: "hmac" };
    } else {
      return { 
        authenticated: false, 
        method: "hmac", 
        error: "Invalid HMAC signature" 
      };
    }
  }
  
  // Check IP allow list (if configured)
  if (config.allowedIps) {
    const clientIp = getClientIp(req);
    if (!isIpAllowed(clientIp, config.allowedIps)) {
      return { 
        authenticated: false, 
        method: "ip", 
        error: `IP ${clientIp} not in allow list` 
      };
    }
  }
  
  // Fallback to query string secret (deprecated, for backward compatibility)
  if (config.legacySecret) {
    const url = new URL(req.url);
    if (url.searchParams.get("secret") === config.legacySecret) {
      return { authenticated: true, method: "legacy_secret" };
    }
  }
  
  return { 
    authenticated: false, 
    method: "none", 
    error: "No valid authentication method" 
  };
}

/**
 * Extract and validate JWT from request
 */
export function extractJwt(req: Request): string | null {
  const authHeader = req.headers.get("authorization");
  if (!authHeader) return null;
  
  const parts = authHeader.split(" ");
  if (parts.length !== 2 || parts[0].toLowerCase() !== "bearer") {
    return null;
  }
  
  return parts[1];
}
