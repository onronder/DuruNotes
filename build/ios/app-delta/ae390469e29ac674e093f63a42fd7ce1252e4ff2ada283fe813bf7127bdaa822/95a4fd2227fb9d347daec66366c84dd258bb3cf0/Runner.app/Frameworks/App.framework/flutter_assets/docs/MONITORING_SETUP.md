# Monitoring & Analytics Setup Guide

This guide explains how to set up crash reporting and analytics for Duru Notes using Sentry and privacy-safe analytics.

## Overview

Duru Notes implements comprehensive monitoring and analytics with:
- **Crash Reporting**: Sentry for production crash capture with breadcrumbs
- **Analytics**: Privacy-safe feature usage tracking and funnel analytics
- **Logging**: Unified logging interface with multiple backends
- **Error Boundaries**: Widget-level error containment and recovery

## Architecture

### Components

1. **Environment Configuration**: Centralized config management
2. **App Logger**: Unified logging interface (Console/Sentry backends)
3. **Analytics Service**: Privacy-safe event tracking
4. **Error Boundaries**: Widget error containment
5. **Global Error Handlers**: Catch-all error reporting

### Privacy & Compliance

- ✅ **No PII Tracking**: Email, names, content automatically filtered
- ✅ **Sampling**: Configurable analytics sampling rates
- ✅ **Environment Isolation**: Dev/staging/prod separation
- ✅ **Content Privacy**: Only metadata tracked (length, word count)
- ✅ **Opt-out Ready**: Easy disable via environment flags

## Setup Instructions

### 1. Sentry Setup

#### Create Sentry Project
1. Go to [sentry.io](https://sentry.io) and create account
2. Create new project for Flutter
3. Get your DSN from Project Settings → Client Keys

#### Configure Environment Files
Add your Sentry DSN to environment files:

```env
# staging.env
SENTRY_DSN=https://your-staging-dsn@sentry.io/project-id
CRASH_REPORTING_ENABLED=true
ANALYTICS_ENABLED=true
ANALYTICS_SAMPLING_RATE=1.0
SENTRY_TRACES_SAMPLE_RATE=0.3

# prod.env  
SENTRY_DSN=https://your-production-dsn@sentry.io/project-id
CRASH_REPORTING_ENABLED=true
ANALYTICS_ENABLED=true
ANALYTICS_SAMPLING_RATE=0.1
SENTRY_TRACES_SAMPLE_RATE=0.15
```

### 2. Environment Configuration

#### Development Environment
```env
# dev.env - Monitoring disabled for development
CRASH_REPORTING_ENABLED=false
ANALYTICS_ENABLED=false
ANALYTICS_SAMPLING_RATE=0.0
```

#### Staging Environment
```env
# staging.env - Full monitoring for testing
CRASH_REPORTING_ENABLED=true
ANALYTICS_ENABLED=true
ANALYTICS_SAMPLING_RATE=1.0    # Track all events
SENTRY_TRACES_SAMPLE_RATE=0.3  # 30% performance traces
```

#### Production Environment
```env
# prod.env - Sampled monitoring for production
CRASH_REPORTING_ENABLED=true
ANALYTICS_ENABLED=true
ANALYTICS_SAMPLING_RATE=0.1    # Track 10% of events
SENTRY_TRACES_SAMPLE_RATE=0.15 # 15% performance traces
```

### 3. Build Configuration

#### Android (build.gradle.kts)
The build flavors already include FLAVOR build config:

```kotlin
productFlavors {
    create("prod") {
        buildConfigField("String", "FLAVOR", "\"prod\"")
    }
}
```

#### iOS (xcconfig files)
Environment-specific configurations are in:
- `ios/Flutter/Dev.xcconfig`
- `ios/Flutter/Staging.xcconfig`  
- `ios/Flutter/Prod.xcconfig`

### 4. CI/CD Configuration

#### Environment Variables
Add to your CI/CD pipeline:

```yaml
# GitHub Actions / GitLab CI
env:
  SENTRY_DSN_STAGING: ${{ secrets.SENTRY_DSN_STAGING }}
  SENTRY_DSN_PROD: ${{ secrets.SENTRY_DSN_PROD }}
```

#### Build Commands
```bash
# Staging build
flutter build apk --flavor staging --dart-define=FLAVOR=staging

# Production build  
flutter build apk --flavor prod --dart-define=FLAVOR=prod
```

## Usage

### Logging

```dart
import 'package:duru_notes_app/core/monitoring/app_logger.dart';

// Info logging
logger.info('User performed search', data: {
  'query_length': query.length,
  'result_count': results.length,
});

// Error logging
logger.error('Failed to save note', 
  error: e, 
  stackTrace: stackTrace,
  data: {'note_id': noteId}
);

// Breadcrumbs for debugging context
logger.breadcrumb('Started note sync');
```

### Analytics

```dart
import 'package:duru_notes_app/services/analytics/analytics_sentry.dart';

// Track events
analytics.event(AnalyticsEvents.noteCreate, properties: {
  'note_length': 'medium',
  'has_attachments': false,
  'is_encrypted': true,
});

// Track screens
analytics.screen('HomeScreen');

// Track user actions
analytics.featureUsed('markdown_editor', properties: {
  'action': 'bold_text',
});

// Track funnels
analytics.funnelStep('user_onboarding', 'account_created');
```

### Error Boundaries

```dart
import 'package:duru_notes_app/core/monitoring/error_boundary.dart';

// Wrap entire features
class NotesListScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: NotesListView(),
      fallback: NotesErrorWidget(),
    );
  }
}

// Use extension methods
Widget build(BuildContext context) {
  return ComplexWidget()
    .withErrorBoundary()
    .withFeatureErrorBoundary('notes_list');
}
```

## Event Tracking

### Pre-defined Events

#### Authentication
- `auth.login.attempt`
- `auth.login.success`  
- `auth.login.failure`
- `auth.logout`

#### Notes
- `note.create`
- `note.edit`
- `note.delete`
- `note.view`
- `note.share`

#### Search
- `search.performed`
- `search.results`
- `search.result.clicked`

#### Features
- `feature.markdown`
- `feature.crypto`
- `feature.sync`

### Custom Properties

All properties are automatically sanitized for privacy:

```dart
// Safe properties (tracked)
analytics.event('note.create', properties: {
  'note_length': 'medium',     // ✅ Metadata only
  'word_count': 150,          // ✅ Count only
  'has_attachments': true,    // ✅ Boolean flag
});

// Unsafe properties (filtered out)
analytics.event('note.create', properties: {
  'user_email': 'user@email.com',  // ❌ PII filtered
  'note_content': 'My content',    // ❌ Content filtered
  'user_name': 'John Doe',         // ❌ PII filtered
});
```

## Testing

### Manual Testing

#### Crash Reporting
1. Add test crash in development:
```dart
ElevatedButton(
  onPressed: () => throw Exception('Test crash'),
  child: Text('Test Crash'),
)
```

2. Switch to staging/prod flavor
3. Trigger crash
4. Check Sentry dashboard for error

#### Analytics Testing
1. Enable analytics in staging
2. Perform user actions (create note, search, etc.)
3. Check Sentry breadcrumbs or implement analytics dashboard

### Unit Testing

```dart
// Test analytics sampling
test('should respect sampling rate', () {
  final analytics = SentryAnalytics();
  // Test with different sampling rates
});

// Test error boundary
testWidgets('should show fallback on error', (tester) async {
  await tester.pumpWidget(ErrorBoundary(
    child: ThrowingWidget(),
    fallback: FallbackWidget(),
  ));
  
  expect(find.byType(FallbackWidget), findsOneWidget);
});
```

## Troubleshooting

### Common Issues

#### 1. Sentry Not Receiving Events
- ✅ Check DSN is correct in environment file
- ✅ Verify environment is staging/prod (dev is filtered)
- ✅ Confirm `CRASH_REPORTING_ENABLED=true`
- ✅ Check network connectivity

#### 2. Analytics Not Working
- ✅ Verify `ANALYTICS_ENABLED=true`
- ✅ Check sampling rate > 0.0
- ✅ Confirm Sentry is configured
- ✅ Look for console logs in debug mode

#### 3. Environment Config Issues
- ✅ Ensure .env file exists in `assets/env/`
- ✅ Check file is added to `pubspec.yaml` assets
- ✅ Verify FLAVOR dart-define matches environment
- ✅ Restart app after env changes

### Debug Commands

```bash
# Check current environment
flutter run --flavor dev --dart-define=FLAVOR=dev

# Test with staging config
flutter run --flavor staging --dart-define=FLAVOR=staging

# Build with verbose logging
flutter build apk --flavor prod --dart-define=FLAVOR=prod --verbose
```

### Logs to Check

#### Initialization Logs
```
🚀 Initializing Duru Notes
Environment: production
Debug Mode: false
Sentry Configured: true
✅ All services initialized successfully
```

#### Analytics Logs
```
ℹ️ [INFO] Analytics service initialized
📝 [CONTEXT] Set context "analytics_event": {"name": "note.create"}
🍞 [BREADCRUMB] [info] Analytics event: note.create
```

## Security & Privacy

### Data Protection
- **No PII**: Personal information automatically filtered
- **Content Privacy**: Only metadata tracked (length, type)
- **Secure Transport**: All data encrypted in transit
- **Minimal Retention**: Configure Sentry retention policies

### Compliance
- **GDPR Ready**: No personal data collected by default
- **CCPA Compliant**: Clear opt-out mechanisms
- **SOC2 Compatible**: Sentry provides enterprise compliance

### Best Practices
1. **Minimize Data**: Only track essential metrics
2. **Regular Audits**: Review tracked properties quarterly
3. **Clear Policies**: Document what data is collected
4. **User Control**: Provide analytics disable option
5. **Secure Storage**: Keep DSNs in environment variables

## Maintenance

### Regular Tasks
- [ ] Review Sentry error trends monthly
- [ ] Update sampling rates based on volume
- [ ] Audit tracked properties for PII
- [ ] Monitor performance impact
- [ ] Update analytics event documentation

### Updates
- Keep `sentry_flutter` package updated
- Review Sentry release notes for breaking changes
- Test monitoring after Flutter SDK updates
- Validate environment configs after changes

## Support

For issues with monitoring setup:
1. Check this documentation
2. Review Sentry documentation
3. Test with different environments
4. Check application logs
5. Contact development team

---

**Last Updated**: January 2025  
**Version**: 1.0.0
