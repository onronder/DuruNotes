# Quick Capture Widget - Alerting Rules

## Alert Configuration

### Critical Alerts (P1)

#### 1. Service Availability
```yaml
alert: WidgetServiceDown
condition: health_status != "healthy" for 5 minutes
severity: critical
channels: [pagerduty, slack-critical]
action: Page on-call engineer immediately
```

#### 2. High Error Rate
```yaml
alert: HighErrorRate
condition: error_rate > 10% for 10 minutes
severity: critical
channels: [pagerduty, slack-critical, email]
action: Investigate error logs immediately
```

#### 3. Database Connection Failed
```yaml
alert: DatabaseConnectionFailed
condition: database_health == false for 2 minutes
severity: critical
channels: [pagerduty, slack-critical]
action: Check database status and connection
```

### High Priority Alerts (P2)

#### 4. Performance Degradation
```yaml
alert: CaptureLatencyHigh
condition: capture_latency_p95 > 1000ms for 15 minutes
severity: high
channels: [slack-alerts, email]
action: Review performance metrics
```

#### 5. Rate Limiting Spike
```yaml
alert: RateLimitingSpike
condition: rate_limit_hits > 100 per hour
severity: high
channels: [slack-alerts]
action: Review usage patterns, consider limit adjustment
```

#### 6. Offline Queue Backup
```yaml
alert: OfflineQueueBackup
condition: offline_queue_size > 100 for 30 minutes
severity: high
channels: [slack-alerts, email]
action: Check sync service status
```

### Medium Priority Alerts (P3)

#### 7. Widget Refresh Slow
```yaml
alert: WidgetRefreshSlow
condition: widget_refresh_p95 > 500ms for 30 minutes
severity: medium
channels: [slack-monitoring]
action: Monitor and optimize if persistent
```

#### 8. Low User Engagement
```yaml
alert: LowEngagement
condition: dau_wau_ratio < 20% for 3 days
severity: medium
channels: [slack-product, email]
action: Review user feedback and usage patterns
```

#### 9. Template Usage Imbalance
```yaml
alert: TemplateUsageImbalance
condition: single_template_usage > 80% of total
severity: medium
channels: [slack-product]
action: Consider template improvements
```

### Low Priority Alerts (P4)

#### 10. Memory Usage Warning
```yaml
alert: MemoryUsageWarning
condition: memory_usage > 80% for 1 hour
severity: low
channels: [slack-monitoring]
action: Monitor for escalation
```

#### 11. Analytics Event Delay
```yaml
alert: AnalyticsEventDelay
condition: analytics_processing_delay > 5 minutes
severity: low
channels: [slack-monitoring]
action: Check analytics pipeline
```

## Alert Channels

### PagerDuty
- Critical alerts only
- 24/7 on-call rotation
- Escalation after 5 minutes

### Slack Channels
- `#alerts-critical`: P1 alerts
- `#alerts-high`: P2 alerts  
- `#monitoring`: P3/P4 alerts
- `#product-metrics`: Usage alerts

### Email
- Engineering team for P1/P2
- Product team for usage metrics
- Weekly summary reports

## Alert Response Playbooks

### P1 Response (Critical)
1. Acknowledge alert within 5 minutes
2. Join incident channel
3. Assess impact and scope
4. Implement immediate mitigation
5. Root cause analysis
6. Post-mortem within 48 hours

### P2 Response (High)
1. Acknowledge within 30 minutes
2. Investigate root cause
3. Implement fix or mitigation
4. Update monitoring if needed

### P3/P4 Response (Medium/Low)
1. Review during business hours
2. Track in issue tracker
3. Address in next sprint if needed

## Monitoring Thresholds

### Performance Thresholds
```javascript
const thresholds = {
  capture_latency: {
    p50: 200,  // ms
    p95: 500,  // ms
    p99: 1000  // ms
  },
  widget_refresh: {
    p50: 50,   // ms
    p95: 100,  // ms
    p99: 200   // ms
  },
  data_sync: {
    p50: 500,  // ms
    p95: 1000, // ms
    p99: 2000  // ms
  },
  queue_processing: {
    per_item: 50  // ms
  }
}
```

### Error Rate Thresholds
```javascript
const errorThresholds = {
  critical: 10,  // % - Page immediately
  high: 5,       // % - Alert team
  warning: 2,    // % - Monitor closely
  baseline: 0.5  // % - Normal operation
}
```

### Usage Thresholds
```javascript
const usageThresholds = {
  dau: {
    min: 100,     // Minimum expected DAU
    growth: -10   // % daily decline triggers alert
  },
  engagement: {
    dau_wau: 20,  // % minimum ratio
    wau_mau: 40   // % minimum ratio
  },
  rate_limits: {
    per_user: 10,     // per minute
    total_hourly: 100 // system-wide
  }
}
```

## Alert Suppression Rules

### Maintenance Windows
- Scheduled: Tuesdays 2-4 AM UTC
- Suppress non-critical alerts
- Pre-announce in #engineering

### Known Issues
- Track in issue tracker
- Suppress duplicate alerts
- Update when resolved

### Flapping Prevention
- Require 3 consecutive failures
- 5-minute cooldown after recovery
- Aggregate similar alerts

## Metrics Collection

### Data Sources
1. **Application Metrics**
   - Flutter app telemetry
   - Platform channel events
   - Widget lifecycle events

2. **Backend Metrics**
   - Edge function logs
   - Database queries
   - API response times

3. **Infrastructure Metrics**
   - CPU/Memory usage
   - Network latency
   - Storage utilization

### Collection Intervals
- Real-time: Errors, critical events
- 1-minute: Performance metrics
- 5-minute: Usage statistics
- Hourly: Aggregated reports
- Daily: Trend analysis

## Dashboard Access

### Production Dashboard
- URL: `https://dashboard.durunotes.com/widget-monitoring`
- Auth: SSO required
- Refresh: Real-time

### Key Metrics Display
1. **Health Overview**
   - Service status indicators
   - Error rate graph
   - Active user count

2. **Performance Metrics**
   - Latency percentiles
   - Throughput graphs
   - Queue status

3. **Usage Analytics**
   - DAU/WAU/MAU trends
   - Feature adoption
   - Platform distribution

4. **Error Analysis**
   - Error type breakdown
   - Error trends
   - Recent errors log

## Alert Testing

### Weekly Alert Test
```bash
# Test all alert channels
./scripts/test_alerts.sh

# Test specific alert
./scripts/test_alerts.sh --alert HighErrorRate
```

### Alert Validation
- Verify delivery to all channels
- Confirm escalation paths
- Test response playbooks
- Update contact lists

## Continuous Improvement

### Monthly Review
- Alert accuracy (false positive rate)
- Response times
- Threshold adjustments
- New alert requirements

### Quarterly Planning
- Capacity planning based on growth
- Infrastructure scaling needs
- Alert automation improvements
- Tool evaluation

---

*Last Updated: [Current Date]*
*Version: 1.0.0*
*Owner: Platform Team*
