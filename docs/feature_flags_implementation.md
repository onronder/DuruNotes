# Feature Flags Implementation

## Overview
Feature flags have been properly wired up to enable gradual rollout of refactored components. The system now supports switching between legacy and refactored implementations at runtime.

## Current Feature Flags

All flags are currently **ENABLED** for development (`true`):

1. **`use_unified_reminders`** - Use refactored reminder services
2. **`use_new_block_editor`** - Use hierarchical todo blocks
3. **`use_refactored_components`** - Use all refactored components
4. **`use_unified_permission_manager`** - Use unified permission manager

## Implementation Details

### 1. Core Feature Flag System
- **Location**: `lib/core/feature_flags.dart`
- **Purpose**: Central management of feature toggles
- **Features**:
  - Singleton pattern for global access
  - Override capability for testing
  - Placeholder for remote config integration

### 2. Feature-Flagged Providers
Created multiple provider systems to support feature flags:

#### Main Providers
- **`lib/providers/unified_reminder_provider.dart`**
  - Switches between legacy and refactored reminder coordinators
  
- **`lib/providers/feature_flagged_providers.dart`**
  - Central hub for all feature-flagged providers
  - Includes helper extensions for easy access
  - Logs feature flag decisions for debugging

#### Updated Providers
- **`lib/providers.dart`**
  - Modified `taskReminderBridgeProvider` to check feature flags
  - Imports feature flag system

### 3. UI Component Factories
- **`lib/ui/widgets/blocks/feature_flagged_block_factory.dart`**
  - Factory for creating block widgets based on feature flags
  - Switches between legacy and hierarchical todo blocks
  - Provides unified block editor selection

### 4. App Initialization
- **`lib/main.dart`**
  - Added feature flag initialization
  - Logs feature flag state in debug mode
  - Tracks feature flag usage in analytics

## How It Works

### Service Selection Flow
```
App Start
  ↓
Initialize Feature Flags
  ↓
Check Flag Value
  ↓
If `use_unified_reminders` = true
  → Use Refactored ReminderCoordinator
  → Use Refactored Services
Else
  → Use Legacy ReminderCoordinator
  → Use Legacy Services
```

### UI Component Selection Flow
```
Widget Creation Request
  ↓
Check Feature Flags
  ↓
If `use_new_block_editor` = true
  → Create HierarchicalTodoBlockWidget
  → Use Enhanced Features
Else
  → Create TodoBlockWidget
  → Use Legacy Features
```

## Usage Examples

### In Providers
```dart
final reminderCoordinator = featureFlags.useUnifiedReminders
    ? ref.watch(unifiedReminderCoordinatorProvider)
    : ref.watch(reminderCoordinatorProvider);
```

### In Widgets
```dart
final widget = FeatureFlaggedBlockFactory.createTodoBlock(
  block: block,
  noteId: noteId,
  // ... other params
);
```

### Checking Flags
```dart
if (FeatureFlags.instance.useRefactoredComponents) {
  // Use new implementation
} else {
  // Use legacy implementation
}
```

## Debug Output

When running in debug mode, the app logs:
```
[FeatureFlags] ✅ Using REFACTORED ReminderCoordinator
[FeatureFlags] ✅ Using HIERARCHICAL TodoBlockWidget
[FeatureFlags] ✅ Using UNIFIED BlockEditor
```

## Testing

### Toggling Flags for Testing
```dart
// In test setup
FeatureFlags.instance.setOverride('use_unified_reminders', false);

// Run tests with legacy implementation

// Clear overrides
FeatureFlags.instance.clearOverrides();
```

### A/B Testing Setup
The system is ready for A/B testing:
1. Connect to Firebase Remote Config
2. Update `updateFromRemoteConfig()` method
3. Set percentage rollouts
4. Monitor analytics events

## Analytics Tracking

Feature flag usage is automatically tracked:
- `feature_flags_initialized` - Logged at app start
- `app.feature_enabled` - Logged when features are used
- Individual service analytics track which implementation is active

## Migration Strategy

### Phase 1: Development (Current)
- All flags enabled
- Refactored components active
- Legacy code still available

### Phase 2: Staging
- Gradual rollout to internal testers
- Monitor for issues
- Quick rollback capability

### Phase 3: Production
- Percentage-based rollout
- Monitor performance metrics
- Full migration when stable

### Phase 4: Cleanup
- Remove legacy code
- Remove feature flags
- Simplify codebase

## Benefits

1. **Risk Mitigation** - Easy rollback if issues arise
2. **Gradual Rollout** - Test with subset of users
3. **A/B Testing** - Compare performance
4. **No Deploy Required** - Toggle via remote config
5. **Debug Visibility** - Clear logging of active features

## Next Steps

1. **Connect to Remote Config**
   - Firebase Remote Config integration
   - Real-time flag updates

2. **Add Metrics**
   - Performance comparison
   - Error rate monitoring
   - User engagement tracking

3. **Create Dashboard**
   - Feature flag status
   - Rollout percentage
   - User segment targeting

## Verification

Run the verification script:
```bash
./scripts/verify_feature_flags.sh
```

This checks that:
- Feature flags are properly defined
- Providers use feature flags
- UI components check flags
- Analytics tracking is in place
