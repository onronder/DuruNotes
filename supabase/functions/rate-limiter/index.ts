import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RateLimitRequest {
  email: string
  action: 'check' | 'record_success' | 'record_failure'
  error_message?: string
  ip_address?: string
  user_agent?: string
}

interface RateLimitResponse {
  allowed: boolean
  attempts_remaining: number
  is_locked: boolean
  lockout_until?: string
  retry_after_seconds?: number
  message: string
}

// Rate limiting configuration
const MAX_FAILED_ATTEMPTS = 5
const LOCKOUT_DURATION_MINUTES = 15
const ATTEMPT_WINDOW_MINUTES = 30

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Parse request body
    const body: RateLimitRequest = await req.json()
    const { email, action, error_message, ip_address, user_agent } = body

    if (!email || !action) {
      return new Response(
        JSON.stringify({ error: 'Email and action are required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    const now = new Date()
    const windowStart = new Date(now.getTime() - ATTEMPT_WINDOW_MINUTES * 60 * 1000)

    switch (action) {
      case 'check': {
        // Check if user can attempt login
        const lockStatus = await checkAccountLockout(supabaseClient, email, now, windowStart)
        
        return new Response(
          JSON.stringify(lockStatus),
          { 
            status: lockStatus.allowed ? 200 : 429,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      case 'record_success': {
        // Record successful login
        await recordLoginAttempt(supabaseClient, {
          email,
          success: true,
          attempt_time: now.toISOString(),
          ip_address,
          user_agent
        })

        // Clean up old attempts
        await cleanupOldAttempts(supabaseClient)

        return new Response(
          JSON.stringify({ 
            message: 'Success recorded',
            allowed: true,
            attempts_remaining: MAX_FAILED_ATTEMPTS,
            is_locked: false
          }),
          { 
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      case 'record_failure': {
        // Record failed login
        await recordLoginAttempt(supabaseClient, {
          email,
          success: false,
          error_message,
          attempt_time: now.toISOString(),
          ip_address,
          user_agent
        })

        // Check new lockout status after recording failure
        const lockStatus = await checkAccountLockout(supabaseClient, email, now, windowStart)

        return new Response(
          JSON.stringify(lockStatus),
          { 
            status: lockStatus.allowed ? 200 : 429,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      default:
        return new Response(
          JSON.stringify({ error: 'Invalid action' }),
          { 
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
    }

  } catch (error) {
    console.error('Rate limiter error:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        // In case of error, allow the request (fail open for availability)
        allowed: true,
        attempts_remaining: MAX_FAILED_ATTEMPTS,
        is_locked: false,
        message: 'Rate limiting temporarily unavailable'
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

async function checkAccountLockout(
  client: any, 
  email: string, 
  now: Date, 
  windowStart: Date
): Promise<RateLimitResponse> {
  try {
    // Get failed attempts in the current window
    const { data: attempts, error } = await client
      .from('login_attempts')
      .select('attempt_time, success')
      .eq('email', email)
      .gte('attempt_time', windowStart.toISOString())
      .order('attempt_time', { ascending: false })

    if (error) {
      console.error('Database error:', error)
      // Fail open - allow request if we can't check
      return {
        allowed: true,
        attempts_remaining: MAX_FAILED_ATTEMPTS,
        is_locked: false,
        message: 'Rate limiting check failed - allowing request'
      }
    }

    if (!attempts || attempts.length === 0) {
      return {
        allowed: true,
        attempts_remaining: MAX_FAILED_ATTEMPTS,
        is_locked: false,
        message: 'No recent attempts'
      }
    }

    // Count consecutive failed attempts from most recent
    let consecutiveFailures = 0
    let lastAttemptTime: Date | null = null

    for (const attempt of attempts) {
      const attemptTime = new Date(attempt.attempt_time)
      
      if (!lastAttemptTime) {
        lastAttemptTime = attemptTime
      }
      
      if (attempt.success) {
        // Stop counting at first successful login
        break
      } else {
        consecutiveFailures++
      }
    }

    // Check if account should be locked
    if (consecutiveFailures >= MAX_FAILED_ATTEMPTS && lastAttemptTime) {
      const lockoutEnd = new Date(lastAttemptTime.getTime() + LOCKOUT_DURATION_MINUTES * 60 * 1000)
      
      if (now < lockoutEnd) {
        const retryAfterSeconds = Math.ceil((lockoutEnd.getTime() - now.getTime()) / 1000)
        
        return {
          allowed: false,
          attempts_remaining: 0,
          is_locked: true,
          lockout_until: lockoutEnd.toISOString(),
          retry_after_seconds: retryAfterSeconds,
          message: `Account locked. Try again in ${Math.ceil(retryAfterSeconds / 60)} minutes`
        }
      }
    }

    // Account not locked - calculate remaining attempts
    const attemptsRemaining = Math.max(0, MAX_FAILED_ATTEMPTS - consecutiveFailures)
    
    return {
      allowed: attemptsRemaining > 0,
      attempts_remaining: attemptsRemaining,
      is_locked: false,
      message: attemptsRemaining > 0 
        ? `${attemptsRemaining} attempts remaining`
        : 'No attempts remaining in current window'
    }

  } catch (error) {
    console.error('Error checking account lockout:', error)
    // Fail open
    return {
      allowed: true,
      attempts_remaining: MAX_FAILED_ATTEMPTS,
      is_locked: false,
      message: 'Error checking lockout status - allowing request'
    }
  }
}

async function recordLoginAttempt(client: any, attempt: {
  email: string
  success: boolean
  error_message?: string
  attempt_time: string
  ip_address?: string
  user_agent?: string
}) {
  try {
    const { error } = await client
      .from('login_attempts')
      .insert(attempt)

    if (error) {
      console.error('Error recording login attempt:', error)
    }
  } catch (error) {
    console.error('Error recording login attempt:', error)
  }
}

async function cleanupOldAttempts(client: any) {
  try {
    const cutoffDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) // 7 days ago
    
    const { error } = await client
      .from('login_attempts')
      .delete()
      .lt('attempt_time', cutoffDate.toISOString())

    if (error) {
      console.error('Error cleaning up old attempts:', error)
    }
  } catch (error) {
    console.error('Error cleaning up old attempts:', error)
  }
}

/* To deploy this function:

1. Install Supabase CLI: npm install -g supabase
2. Login to Supabase: supabase login
3. Navigate to your project: cd your-project
4. Deploy function: supabase functions deploy rate-limiter

The function will be available at:
https://your-project-ref.supabase.co/functions/v1/rate-limiter

Example usage:

POST https://your-project-ref.supabase.co/functions/v1/rate-limiter
Content-Type: application/json
Authorization: Bearer your-anon-key

{
  "email": "user@example.com",
  "action": "check"
}

Response:
{
  "allowed": true,
  "attempts_remaining": 5,
  "is_locked": false,
  "message": "No recent attempts"
}
*/
