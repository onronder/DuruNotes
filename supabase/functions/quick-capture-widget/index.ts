/**
 * Quick Capture Widget Edge Function
 * Production-grade implementation with comprehensive error handling,
 * rate limiting, validation, and monitoring
 * 
 * @author Senior Architect
 * @version 1.0.0
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

// ============================================
// TYPE DEFINITIONS
// ============================================

interface QuickCaptureRequest {
  text: string
  templateId?: string
  attachments?: string[]
  platform: 'ios' | 'android' | 'web'
  metadata?: Record<string, unknown>
}

interface QuickCaptureResponse {
  success: boolean
  noteId?: string
  message: string
  error?: string
  errorCode?: string
}

interface RateLimitData {
  count: number
  window_start: string
}

interface ValidationError {
  field: string
  message: string
}

// ============================================
// CONSTANTS
// ============================================

const MAX_TEXT_LENGTH = 10000 // 10K characters max
const MAX_ATTACHMENTS = 10
const RATE_LIMIT_WINDOW_MS = 60000 // 1 minute
const RATE_LIMIT_MAX_REQUESTS = 10
const MAX_TITLE_LENGTH = 255

// Error codes for client handling
const ERROR_CODES = {
  UNAUTHORIZED: 'AUTH_001',
  RATE_LIMITED: 'RATE_001',
  VALIDATION_FAILED: 'VAL_001',
  NOTE_CREATION_FAILED: 'NOTE_001',
  INTERNAL_ERROR: 'INT_001',
} as const

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Validates the incoming request payload
 */
function validateRequest(body: unknown): ValidationError[] {
  const errors: ValidationError[] = []
  
  if (!body || typeof body !== 'object') {
    errors.push({ field: 'body', message: 'Invalid request body' })
    return errors
  }
  
  const req = body as QuickCaptureRequest
  
  // Validate text
  if (!req.text || typeof req.text !== 'string') {
    errors.push({ field: 'text', message: 'Text is required and must be a string' })
  } else if (req.text.trim().length === 0) {
    errors.push({ field: 'text', message: 'Text cannot be empty' })
  } else if (req.text.length > MAX_TEXT_LENGTH) {
    errors.push({ 
      field: 'text', 
      message: `Text exceeds maximum length of ${MAX_TEXT_LENGTH} characters` 
    })
  }
  
  // Validate platform
  const validPlatforms = ['ios', 'android', 'web']
  if (!req.platform || !validPlatforms.includes(req.platform)) {
    errors.push({ 
      field: 'platform', 
      message: `Platform must be one of: ${validPlatforms.join(', ')}` 
    })
  }
  
  // Validate templateId if provided
  if (req.templateId !== undefined && typeof req.templateId !== 'string') {
    errors.push({ field: 'templateId', message: 'Template ID must be a string' })
  }
  
  // Validate attachments if provided
  if (req.attachments !== undefined) {
    if (!Array.isArray(req.attachments)) {
      errors.push({ field: 'attachments', message: 'Attachments must be an array' })
    } else if (req.attachments.length > MAX_ATTACHMENTS) {
      errors.push({ 
        field: 'attachments', 
        message: `Maximum ${MAX_ATTACHMENTS} attachments allowed` 
      })
    } else if (!req.attachments.every(a => typeof a === 'string')) {
      errors.push({ field: 'attachments', message: 'All attachments must be strings' })
    }
  }
  
  return errors
}

/**
 * Sanitizes user input to prevent XSS and injection attacks
 */
function sanitizeInput(text: string): string {
  // Remove any potential script tags or malicious content
  return text
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    .replace(/javascript:/gi, '')
    .replace(/on\w+\s*=/gi, '') // Remove event handlers
    .trim()
}

/**
 * Generates a title from the note content
 */
function generateTitle(text: string, templateId?: string): string {
  const now = new Date()
  const timestamp = now.toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
  
  // Template-specific titles
  if (templateId) {
    const templateTitles: Record<string, string> = {
      'meeting': `Meeting Notes - ${timestamp}`,
      'todo': `Quick Todo - ${timestamp}`,
      'idea': `Idea - ${timestamp}`,
    }
    if (templateTitles[templateId]) {
      return templateTitles[templateId]
    }
  }
  
  // Extract first line or first 50 chars as title
  const firstLine = text.split('\n')[0].trim()
  const titleText = firstLine.length > 50 
    ? firstLine.substring(0, 47) + '...'
    : firstLine
  
  return titleText || `Quick Capture - ${timestamp}`
}

/**
 * Applies template to the captured text
 */
function applyTemplate(text: string, templateId: string): string {
  const templates: Record<string, string> = {
    'meeting': `## Meeting Notes

Date: ${new Date().toLocaleDateString()}
Time: ${new Date().toLocaleTimeString()}

### Attendees
- 

### Agenda
${text}

### Action Items
- [ ] 

### Notes
`,
    'todo': `## Quick Todo

- [ ] ${text}

Due: 
Priority: Medium
Status: Pending

### Notes
`,
    'idea': `## Idea

${text}

### Next Steps
1. Research feasibility
2. Create prototype
3. Get feedback

### Resources Needed
- 

### Impact
`,
  }
  
  return templates[templateId] || text
}

/**
 * Checks and updates rate limit for a user
 */
async function checkRateLimit(
  supabase: SupabaseClient,
  userId: string
): Promise<{ allowed: boolean; remaining: number }> {
  const rateLimitKey = `widget_capture:${userId}`
  
  try {
    // Get current rate limit data
    const { data: rateLimitData, error: fetchError } = await supabase
      .from('rate_limits')
      .select('count, window_start')
      .eq('key', rateLimitKey)
      .single()
    
    const now = new Date()
    const windowStart = rateLimitData?.window_start 
      ? new Date(rateLimitData.window_start)
      : new Date(now.getTime() - RATE_LIMIT_WINDOW_MS)
    
    // Check if we're still in the same window
    const inSameWindow = now.getTime() - windowStart.getTime() < RATE_LIMIT_WINDOW_MS
    
    if (rateLimitData && inSameWindow) {
      // Check if limit exceeded
      if (rateLimitData.count >= RATE_LIMIT_MAX_REQUESTS) {
        return { 
          allowed: false, 
          remaining: 0 
        }
      }
      
      // Increment counter
      const { error: updateError } = await supabase
        .from('rate_limits')
        .update({ 
          count: rateLimitData.count + 1,
          updated_at: now.toISOString()
        })
        .eq('key', rateLimitKey)
      
      if (updateError) {
        console.error('Rate limit update error:', updateError)
      }
      
      return { 
        allowed: true, 
        remaining: RATE_LIMIT_MAX_REQUESTS - rateLimitData.count - 1 
      }
    } else {
      // Start new window
      const { error: upsertError } = await supabase
        .from('rate_limits')
        .upsert({
          key: rateLimitKey,
          count: 1,
          window_start: now.toISOString(),
          updated_at: now.toISOString()
        })
      
      if (upsertError) {
        console.error('Rate limit upsert error:', upsertError)
      }
      
      return { 
        allowed: true, 
        remaining: RATE_LIMIT_MAX_REQUESTS - 1 
      }
    }
  } catch (error) {
    // On error, allow the request but log for monitoring
    console.error('Rate limit check error:', error)
    return { allowed: true, remaining: -1 }
  }
}

/**
 * Tracks analytics event
 */
async function trackAnalytics(
  supabase: SupabaseClient,
  userId: string,
  eventType: string,
  properties: Record<string, unknown>
): Promise<void> {
  try {
    await supabase.from('analytics_events').insert({
      user_id: userId,
      event_type: eventType,
      properties,
      created_at: new Date().toISOString(),
    })
  } catch (error) {
    // Don't fail the request if analytics fails
    console.error('Analytics tracking error:', error)
  }
}

// ============================================
// MAIN HANDLER
// ============================================

serve(async (req) => {
  // Track request start time for performance monitoring
  const startTime = Date.now()
  
  try {
    // ============================================
    // CORS HANDLING
    // ============================================
    
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
    }
    
    // Handle preflight requests
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }
    
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Method not allowed',
          errorCode: ERROR_CODES.VALIDATION_FAILED,
          message: 'Only POST requests are allowed'
        } as QuickCaptureResponse),
        { 
          status: 405,
          headers: { 
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        }
      )
    }
    
    // ============================================
    // AUTHENTICATION
    // ============================================
    
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'No authorization header',
          errorCode: ERROR_CODES.UNAUTHORIZED,
          message: 'Authentication required'
        } as QuickCaptureResponse),
        {
          status: 401,
          headers: { 
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        }
      )
    }
    
    // Initialize Supabase client with auth header
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
    
    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error('Missing Supabase configuration')
    }
    
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    
    // Get authenticated user
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    
    if (userError || !user) {
      await trackAnalytics(supabase, 'anonymous', 'quick_capture.auth_failed', {
        error: userError?.message
      })
      
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Unauthorized',
          errorCode: ERROR_CODES.UNAUTHORIZED,
          message: 'Invalid authentication token'
        } as QuickCaptureResponse),
        {
          status: 401,
          headers: { 
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        }
      )
    }
    
    // ============================================
    // REQUEST VALIDATION
    // ============================================
    
    let body: QuickCaptureRequest
    try {
      body = await req.json()
    } catch (error) {
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Invalid JSON',
          errorCode: ERROR_CODES.VALIDATION_FAILED,
          message: 'Request body must be valid JSON'
        } as QuickCaptureResponse),
        {
          status: 400,
          headers: { 
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        }
      )
    }
    
    // Validate request payload
    const validationErrors = validateRequest(body)
    if (validationErrors.length > 0) {
      await trackAnalytics(supabase, user.id, 'quick_capture.validation_failed', {
        errors: validationErrors
      })
      
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Validation failed',
          errorCode: ERROR_CODES.VALIDATION_FAILED,
          message: validationErrors.map(e => `${e.field}: ${e.message}`).join(', ')
        } as QuickCaptureResponse),
        {
          status: 400,
          headers: { 
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        }
      )
    }
    
    // ============================================
    // RATE LIMITING
    // ============================================
    
    const { allowed, remaining } = await checkRateLimit(supabase, user.id)
    
    if (!allowed) {
      await trackAnalytics(supabase, user.id, 'quick_capture.rate_limit_hit', {
        platform: body.platform
      })
      
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Rate limit exceeded',
          errorCode: ERROR_CODES.RATE_LIMITED,
          message: 'Too many requests. Please wait a moment and try again.'
        } as QuickCaptureResponse),
        {
          status: 429,
          headers: { 
            ...corsHeaders,
            'Content-Type': 'application/json',
            'X-RateLimit-Limit': RATE_LIMIT_MAX_REQUESTS.toString(),
            'X-RateLimit-Remaining': '0',
            'X-RateLimit-Reset': new Date(Date.now() + RATE_LIMIT_WINDOW_MS).toISOString()
          }
        }
      )
    }
    
    // ============================================
    // NOTE CREATION
    // ============================================
    
    // Sanitize input
    const sanitizedText = sanitizeInput(body.text)
    
    // Apply template if specified
    const finalText = body.templateId 
      ? applyTemplate(sanitizedText, body.templateId)
      : sanitizedText
    
    // Generate title
    const title = generateTitle(sanitizedText, body.templateId)
    
    // Prepare metadata
    const noteMetadata = {
      source: 'widget',
      entry_point: body.platform,
      widget_version: '1.0.0',
      capture_timestamp: new Date().toISOString(),
      ...(body.templateId && { template_id: body.templateId }),
      ...(body.attachments?.length && { 
        attachments_count: body.attachments.length,
        attachments_pending: true 
      }),
      ...(body.metadata && { custom: body.metadata })
    }
    
    // Create note with encrypted columns
    // NOTE: In production, title_enc and props_enc should be encrypted client-side
    // For widget captures, we use a placeholder encryption that the client will re-encrypt
    const { data: note, error: noteError } = await supabase
      .from('notes')
      .insert({
        user_id: user.id,
        // These are encrypted columns - in production these should be encrypted
        // For now, we'll store them as base64 encoded strings
        title_enc: btoa(title.substring(0, MAX_TITLE_LENGTH)), // Base64 encode as placeholder
        props_enc: btoa(JSON.stringify({ content: finalText })), // Base64 encode as placeholder
        encrypted_metadata: JSON.stringify({
          ...noteMetadata,
          requires_client_reencryption: true // Flag for client to properly encrypt
        }),
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        deleted: false,
        is_pinned: false
      })
      .select()
      .single()
    
    if (noteError || !note) {
      console.error('Note creation error:', noteError)
      
      await trackAnalytics(supabase, user.id, 'quick_capture.note_creation_failed', {
        platform: body.platform,
        error: noteError?.message,
        error_code: noteError?.code
      })
      
      return new Response(
        JSON.stringify({ 
          success: false,
          error: 'Failed to create note',
          errorCode: ERROR_CODES.NOTE_CREATION_FAILED,
          message: 'Unable to save your note. Please try again.'
        } as QuickCaptureResponse),
        {
          status: 500,
          headers: { 
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        }
      )
    }
    
    // ============================================
    // ADD TAGS
    // ============================================
    
    // Add widget tag
    const tags = ['widget', 'quick-capture']
    if (body.templateId) {
      tags.push(`template-${body.templateId}`)
    }
    
    // Insert tags (ignore conflicts for existing tags)
    for (const tag of tags) {
      await supabase.from('note_tags').insert({
        note_id: note.id,
        tag: tag.toLowerCase(),
        user_id: user.id,
      }).select() // Use select to avoid conflicts
    }
    
    // ============================================
    // ANALYTICS & MONITORING
    // ============================================
    
    const processingTime = Date.now() - startTime
    
    await trackAnalytics(supabase, user.id, 'quick_capture.widget_note_created', {
      platform: body.platform,
      text_length: body.text.length,
      has_template: !!body.templateId,
      template_id: body.templateId,
      has_attachments: !!(body.attachments?.length),
      attachments_count: body.attachments?.length || 0,
      processing_time_ms: processingTime,
      rate_limit_remaining: remaining
    })
    
    // ============================================
    // SUCCESS RESPONSE
    // ============================================
    
    return new Response(
      JSON.stringify({ 
        success: true,
        noteId: note.id,
        message: 'Note created successfully'
      } as QuickCaptureResponse),
      {
        status: 200,
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json',
          'X-RateLimit-Limit': RATE_LIMIT_MAX_REQUESTS.toString(),
          'X-RateLimit-Remaining': remaining.toString(),
          'X-Processing-Time-Ms': processingTime.toString()
        }
      }
    )
    
  } catch (error) {
    // ============================================
    // ERROR HANDLING
    // ============================================
    
    console.error('Widget capture error:', error)
    
    // Try to track error analytics (may fail if Supabase is down)
    try {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? ''
      )
      await trackAnalytics(supabase, 'system', 'quick_capture.internal_error', {
        error: error.message,
        stack: error.stack
      })
    } catch {
      // Ignore analytics errors in error handler
    }
    
    return new Response(
      JSON.stringify({ 
        success: false,
        error: 'Internal server error',
        errorCode: ERROR_CODES.INTERNAL_ERROR,
        message: 'An unexpected error occurred. Please try again later.'
      } as QuickCaptureResponse),
      {
        status: 500,
        headers: { 
          'Content-Type': 'application/json',
          'X-Processing-Time-Ms': (Date.now() - (startTime || Date.now())).toString()
        }
      }
    )
  }
})
