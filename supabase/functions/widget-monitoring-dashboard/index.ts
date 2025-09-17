/**
 * Monitoring Dashboard for Quick Capture Widget
 * Provides real-time metrics and analytics
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Parse request
    const url = new URL(req.url)
    const endpoint = url.pathname.split('/').pop()

    switch (endpoint) {
      case 'metrics':
        return await getMetrics(supabase)
      case 'analytics':
        return await getAnalytics(supabase)
      case 'errors':
        return await getErrors(supabase)
      case 'performance':
        return await getPerformance(supabase)
      case 'usage':
        return await getUsageStats(supabase)
      case 'health':
        return await getHealthStatus(supabase)
      default:
        return new Response(
          JSON.stringify({ error: 'Invalid endpoint' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
  } catch (error) {
    console.error('Dashboard error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// ============================================
// METRICS ENDPOINTS
// ============================================

async function getMetrics(supabase: any) {
  const now = new Date()
  const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000)
  const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)

  // Get capture metrics
  const { data: captureMetrics } = await supabase
    .from('analytics_events')
    .select('*')
    .eq('event_name', 'widget.quick_capture.capture_completed')
    .gte('created_at', oneDayAgo.toISOString())

  // Get error metrics
  const { data: errorMetrics } = await supabase
    .from('analytics_events')
    .select('*')
    .eq('event_name', 'widget.quick_capture.error')
    .gte('created_at', oneDayAgo.toISOString())

  // Get rate limit metrics
  const { data: rateLimitMetrics } = await supabase
    .from('rate_limits')
    .select('*')
    .gte('updated_at', oneDayAgo.toISOString())

  // Calculate key metrics
  const metrics = {
    daily: {
      total_captures: captureMetrics?.length || 0,
      total_errors: errorMetrics?.length || 0,
      error_rate: captureMetrics?.length 
        ? ((errorMetrics?.length || 0) / captureMetrics.length * 100).toFixed(2) 
        : 0,
      rate_limit_hits: rateLimitMetrics?.filter(r => r.count >= 10).length || 0,
    },
    weekly: await getWeeklyMetrics(supabase, oneWeekAgo),
    realtime: {
      active_users: await getActiveUsers(supabase),
      pending_syncs: await getPendingSyncs(supabase),
    }
  }

  return new Response(
    JSON.stringify(metrics),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

async function getAnalytics(supabase: any) {
  const now = new Date()
  const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000)

  // Get all widget events
  const { data: events } = await supabase
    .from('analytics_events')
    .select('*')
    .like('event_name', 'widget.quick_capture%')
    .gte('created_at', oneDayAgo.toISOString())
    .order('created_at', { ascending: false })
    .limit(1000)

  // Group by event type
  const eventGroups: Record<string, any[]> = {}
  events?.forEach(event => {
    const eventType = event.event_name.split('.').pop()
    if (!eventGroups[eventType]) {
      eventGroups[eventType] = []
    }
    eventGroups[eventType].push(event)
  })

  // Calculate analytics
  const analytics = {
    event_distribution: Object.keys(eventGroups).map(type => ({
      type,
      count: eventGroups[type].length,
      percentage: ((eventGroups[type].length / (events?.length || 1)) * 100).toFixed(2)
    })),
    platform_usage: await getPlatformUsage(events),
    template_usage: await getTemplateUsage(events),
    hourly_distribution: getHourlyDistribution(events),
    capture_performance: await getCapturePerformance(events),
  }

  return new Response(
    JSON.stringify(analytics),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

async function getErrors(supabase: any) {
  const now = new Date()
  const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000)

  // Get error events
  const { data: errors } = await supabase
    .from('analytics_events')
    .select('*')
    .or('event_name.eq.widget.quick_capture.error,event_name.eq.widget.quick_capture.capture_failed')
    .gte('created_at', oneDayAgo.toISOString())
    .order('created_at', { ascending: false })
    .limit(100)

  // Group errors by type
  const errorTypes: Record<string, number> = {}
  const errorDetails: any[] = []

  errors?.forEach(error => {
    const errorData = error.event_properties
    const errorType = errorData?.error_code || errorData?.context || 'unknown'
    
    errorTypes[errorType] = (errorTypes[errorType] || 0) + 1
    
    errorDetails.push({
      id: error.id,
      timestamp: error.created_at,
      type: errorType,
      message: errorData?.error || errorData?.message,
      platform: errorData?.platform,
      user_id: error.user_id,
    })
  })

  return new Response(
    JSON.stringify({
      total_errors: errors?.length || 0,
      error_types: errorTypes,
      recent_errors: errorDetails.slice(0, 20),
      error_trend: await getErrorTrend(supabase),
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

async function getPerformance(supabase: any) {
  const now = new Date()
  const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000)

  // Get performance events
  const { data: perfEvents } = await supabase
    .from('analytics_events')
    .select('*')
    .eq('event_name', 'widget.quick_capture.performance')
    .gte('created_at', oneHourAgo.toISOString())

  // Calculate performance metrics
  const metrics: Record<string, any> = {}
  
  perfEvents?.forEach(event => {
    const metric = event.event_properties?.metric
    const value = event.event_properties?.value
    
    if (metric && value) {
      if (!metrics[metric]) {
        metrics[metric] = {
          count: 0,
          total: 0,
          min: value,
          max: value,
          values: []
        }
      }
      
      metrics[metric].count++
      metrics[metric].total += value
      metrics[metric].min = Math.min(metrics[metric].min, value)
      metrics[metric].max = Math.max(metrics[metric].max, value)
      metrics[metric].values.push(value)
    }
  })

  // Calculate statistics
  Object.keys(metrics).forEach(metric => {
    const m = metrics[metric]
    m.average = m.total / m.count
    m.p50 = calculatePercentile(m.values, 50)
    m.p95 = calculatePercentile(m.values, 95)
    m.p99 = calculatePercentile(m.values, 99)
    delete m.values // Remove raw values from response
  })

  return new Response(
    JSON.stringify({
      metrics,
      thresholds: {
        capture_latency: 500,
        widget_refresh: 100,
        data_sync: 1000,
        queue_processing: 50,
      },
      degraded: Object.keys(metrics).filter(m => {
        const avg = metrics[m].average
        switch (m) {
          case 'capture_latency': return avg > 500
          case 'widget_refresh': return avg > 100
          case 'data_sync': return avg > 1000
          case 'queue_processing': return avg > 50
          default: return false
        }
      })
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

async function getUsageStats(supabase: any) {
  const now = new Date()
  const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000)
  const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
  const oneMonthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)

  // Get DAU
  const { data: dauData } = await supabase
    .from('analytics_events')
    .select('user_id')
    .eq('event_name', 'widget.quick_capture.dau')
    .gte('created_at', oneDayAgo.toISOString())

  const dau = new Set(dauData?.map(d => d.user_id) || []).size

  // Get WAU
  const { data: wauData } = await supabase
    .from('analytics_events')
    .select('user_id')
    .like('event_name', 'widget.quick_capture%')
    .gte('created_at', oneWeekAgo.toISOString())

  const wau = new Set(wauData?.map(d => d.user_id) || []).size

  // Get MAU
  const { data: mauData } = await supabase
    .from('analytics_events')
    .select('user_id')
    .like('event_name', 'widget.quick_capture%')
    .gte('created_at', oneMonthAgo.toISOString())

  const mau = new Set(mauData?.map(d => d.user_id) || []).size

  // Get feature usage
  const { data: featureData } = await supabase
    .from('analytics_events')
    .select('event_properties')
    .eq('event_name', 'widget.quick_capture.feature_usage')
    .gte('created_at', oneWeekAgo.toISOString())

  const featureUsage: Record<string, number> = {}
  featureData?.forEach(f => {
    const feature = f.event_properties?.feature
    if (feature) {
      featureUsage[feature] = (featureUsage[feature] || 0) + 1
    }
  })

  return new Response(
    JSON.stringify({
      daily_active_users: dau,
      weekly_active_users: wau,
      monthly_active_users: mau,
      engagement: {
        dau_wau_ratio: wau > 0 ? (dau / wau * 100).toFixed(2) : 0,
        wau_mau_ratio: mau > 0 ? (wau / mau * 100).toFixed(2) : 0,
      },
      feature_usage: featureUsage,
      growth: await calculateGrowth(supabase),
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

async function getHealthStatus(supabase: any) {
  const checks = {
    database: false,
    edge_function: false,
    rate_limiting: false,
    analytics: false,
  }

  // Check database
  try {
    const { error } = await supabase.from('notes').select('id').limit(1)
    checks.database = !error
  } catch {
    checks.database = false
  }

  // Check edge function (this endpoint itself)
  checks.edge_function = true

  // Check rate limiting
  try {
    const { error } = await supabase.from('rate_limits').select('id').limit(1)
    checks.rate_limiting = !error
  } catch {
    checks.rate_limiting = false
  }

  // Check analytics
  try {
    const { error } = await supabase.from('analytics_events').select('id').limit(1)
    checks.analytics = !error
  } catch {
    checks.analytics = false
  }

  const allHealthy = Object.values(checks).every(v => v)

  return new Response(
    JSON.stringify({
      status: allHealthy ? 'healthy' : 'degraded',
      checks,
      timestamp: new Date().toISOString(),
    }),
    { 
      status: allHealthy ? 200 : 503,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    }
  )
}

// ============================================
// HELPER FUNCTIONS
// ============================================

async function getWeeklyMetrics(supabase: any, oneWeekAgo: Date) {
  const { data: weeklyCaptures } = await supabase
    .from('analytics_events')
    .select('*')
    .eq('event_name', 'widget.quick_capture.capture_completed')
    .gte('created_at', oneWeekAgo.toISOString())

  return {
    total_captures: weeklyCaptures?.length || 0,
    daily_average: Math.round((weeklyCaptures?.length || 0) / 7),
  }
}

async function getActiveUsers(supabase: any) {
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000)
  
  const { data } = await supabase
    .from('analytics_events')
    .select('user_id')
    .like('event_name', 'widget.quick_capture%')
    .gte('created_at', fiveMinutesAgo.toISOString())

  return new Set(data?.map(d => d.user_id) || []).size
}

async function getPendingSyncs(supabase: any) {
  // This would check for pending offline captures
  // For now, return 0
  return 0
}

function getPlatformUsage(events: any[]) {
  const platforms: Record<string, number> = {}
  
  events?.forEach(event => {
    const platform = event.event_properties?.platform
    if (platform) {
      platforms[platform] = (platforms[platform] || 0) + 1
    }
  })
  
  return platforms
}

function getTemplateUsage(events: any[]) {
  const templates: Record<string, number> = {}
  
  events?.forEach(event => {
    const templateId = event.event_properties?.template_id
    if (templateId) {
      templates[templateId] = (templates[templateId] || 0) + 1
    }
  })
  
  return templates
}

function getHourlyDistribution(events: any[]) {
  const hours: Record<number, number> = {}
  
  events?.forEach(event => {
    const hour = new Date(event.created_at).getHours()
    hours[hour] = (hours[hour] || 0) + 1
  })
  
  return hours
}

async function getCapturePerformance(events: any[]) {
  const durations: number[] = []
  
  events?.forEach(event => {
    const duration = event.event_properties?.duration_ms
    if (duration) {
      durations.push(duration)
    }
  })
  
  if (durations.length === 0) return null
  
  durations.sort((a, b) => a - b)
  
  return {
    count: durations.length,
    min: durations[0],
    max: durations[durations.length - 1],
    average: durations.reduce((a, b) => a + b, 0) / durations.length,
    p50: calculatePercentile(durations, 50),
    p95: calculatePercentile(durations, 95),
    p99: calculatePercentile(durations, 99),
  }
}

async function getErrorTrend(supabase: any) {
  const trend: Record<string, number> = {}
  
  for (let i = 0; i < 24; i++) {
    const startHour = new Date(Date.now() - (i + 1) * 60 * 60 * 1000)
    const endHour = new Date(Date.now() - i * 60 * 60 * 1000)
    
    const { data } = await supabase
      .from('analytics_events')
      .select('id')
      .or('event_name.eq.widget.quick_capture.error,event_name.eq.widget.quick_capture.capture_failed')
      .gte('created_at', startHour.toISOString())
      .lt('created_at', endHour.toISOString())
    
    trend[startHour.getHours().toString()] = data?.length || 0
  }
  
  return trend
}

async function calculateGrowth(supabase: any) {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  
  const yesterday = new Date(today)
  yesterday.setDate(yesterday.getDate() - 1)
  
  const lastWeek = new Date(today)
  lastWeek.setDate(lastWeek.getDate() - 7)
  
  // Get today's users
  const { data: todayUsers } = await supabase
    .from('analytics_events')
    .select('user_id')
    .eq('event_name', 'widget.quick_capture.dau')
    .gte('created_at', today.toISOString())
  
  const todayCount = new Set(todayUsers?.map(d => d.user_id) || []).size
  
  // Get yesterday's users
  const { data: yesterdayUsers } = await supabase
    .from('analytics_events')
    .select('user_id')
    .eq('event_name', 'widget.quick_capture.dau')
    .gte('created_at', yesterday.toISOString())
    .lt('created_at', today.toISOString())
  
  const yesterdayCount = new Set(yesterdayUsers?.map(d => d.user_id) || []).size
  
  // Get last week's users
  const { data: lastWeekUsers } = await supabase
    .from('analytics_events')
    .select('user_id')
    .eq('event_name', 'widget.quick_capture.dau')
    .gte('created_at', lastWeek.toISOString())
    .lt('created_at', yesterday.toISOString())
  
  const lastWeekCount = new Set(lastWeekUsers?.map(d => d.user_id) || []).size / 7
  
  return {
    daily: yesterdayCount > 0 ? ((todayCount - yesterdayCount) / yesterdayCount * 100).toFixed(2) : 0,
    weekly: lastWeekCount > 0 ? ((todayCount - lastWeekCount) / lastWeekCount * 100).toFixed(2) : 0,
  }
}

function calculatePercentile(values: number[], percentile: number): number {
  if (values.length === 0) return 0
  
  const index = Math.ceil((percentile / 100) * values.length) - 1
  return values[Math.max(0, index)]
}
