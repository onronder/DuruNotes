# Production-Grade Code Duplication Refactoring Plan

## Executive Summary
This document outlines a systematic approach to eliminate 3,365+ duplicate code blocks across the Duru Notes codebase, with an estimated reduction of 60-70% in duplicated code and significant improvements in maintainability.

## Timeline Overview
- **Phase 1** (Week 1-2): Critical Service Layer Refactoring
- **Phase 2** (Week 3-4): UI Component Consolidation  
- **Phase 3** (Week 5): Testing & Validation
- **Total Duration**: 5 weeks
- **Estimated Effort**: 120-160 developer hours

---

## Phase 1: Critical Service Layer Refactoring (Week 1-2)

### 1. Reminder Services Consolidation
**Impact**: ~600+ lines | **Priority**: CRITICAL | **Risk**: HIGH

#### Current State
- 4 separate reminder services with duplicated logic
- Inconsistent permission handling
- Repeated notification scheduling code
- Duplicated analytics tracking

#### Implementation Plan

##### Step 1.1: Create Base Reminder Service (Day 1-2)
```dart
// lib/services/reminders/base_reminder_service.dart
abstract class BaseReminderService {
  // Shared dependencies
  final FlutterLocalNotificationsPlugin plugin;
  final AppDb db;
  final AppLogger logger = LoggerFactory.instance;
  final AnalyticsService analytics = AnalyticsFactory.instance;
  
  // Common permission management
  Future<bool> requestNotificationPermissions();
  Future<bool> hasNotificationPermissions();
  
  // Shared database operations
  Future<int?> createReminderInDb(NoteRemindersCompanion companion);
  Future<void> updateReminderStatus(int id, ReminderStatus status);
  
  // Common notification scheduling
  Future<void> scheduleNotification(ReminderNotificationData data);
  List<AndroidNotificationAction> getNotificationActions();
  
  // Analytics tracking
  void trackReminderEvent(String event, Map<String, dynamic> properties);
  
  // Template methods for subclasses
  Future<int?> createReminder(ReminderConfig config);
  Future<void> cancelReminder(int id);
}
```

##### Step 1.2: Refactor Individual Services (Day 3-4)
```dart
// lib/services/reminders/recurring_reminder_service.dart
class RecurringReminderService extends BaseReminderService {
  @override
  Future<int?> createReminder(ReminderConfig config) {
    // Only recurring-specific logic here
    validateRecurrence(config);
    final id = await super.createReminderInDb(config.toCompanion());
    await scheduleRecurringNotification(id, config);
    return id;
  }
}
```

##### Step 1.3: Update Reminder Coordinator (Day 5)
```dart
// lib/services/reminders/reminder_coordinator.dart
class ReminderCoordinator {
  late final BaseReminderService recurringService;
  late final BaseReminderService geofenceService;
  late final BaseReminderService snoozeService;
  
  // Unified permission handling
  Future<bool> requestPermissions(ReminderType type) {
    return type == ReminderType.location 
      ? geofenceService.requestLocationPermissions()
      : BaseReminderService.requestNotificationPermissions();
  }
}
```

#### Testing Requirements
- [ ] Unit tests for BaseReminderService
- [ ] Integration tests for each specialized service
- [ ] Permission flow testing on iOS/Android
- [ ] Migration testing for existing reminders

#### Rollback Plan
- Feature flag: `use_legacy_reminder_services`
- Parallel run both implementations for 1 week
- A/B test with 10% of users initially

---

### 2. Permission Management Service
**Impact**: ~150 lines | **Priority**: HIGH | **Risk**: MEDIUM

#### Implementation Plan

##### Step 2.1: Create Unified Permission Manager (Day 6)
```dart
// lib/services/permission_manager.dart
class PermissionManager {
  static final instance = PermissionManager._();
  
  Future<PermissionStatus> request(PermissionType type) async {
    switch (type) {
      case PermissionType.notification:
        return _requestNotifications();
      case PermissionType.location:
        return _requestLocation();
      case PermissionType.microphone:
        return _requestMicrophone();
      case PermissionType.camera:
        return _requestCamera();
    }
  }
  
  Future<bool> hasPermission(PermissionType type);
  Stream<PermissionStatus> observePermission(PermissionType type);
  
  // Platform-specific handling
  Future<PermissionStatus> _requestNotifications() {
    if (Platform.isIOS) {
      return _requestIOSNotifications();
    }
    return _requestAndroidNotifications();
  }
}
```

##### Step 2.2: Migrate Services (Day 7)
```dart
// Before
final status = await Permission.notification.request();

// After  
final status = await PermissionManager.instance.request(PermissionType.notification);
```

---

### 3. Block Editor Consolidation
**Impact**: ~300+ lines | **Priority**: HIGH | **Risk**: HIGH

#### Implementation Plan

##### Step 3.1: Analyze Differences (Day 8)
- Document feature differences between implementations
- Identify which features are actually used
- Create deprecation plan for unused features

##### Step 3.2: Create Unified Block Editor (Day 9-10)
```dart
// lib/ui/widgets/blocks/unified_block_editor.dart
class UnifiedBlockEditor extends ConsumerStatefulWidget {
  // Merge best features from both implementations
  final List<NoteBlock> blocks;
  final Function(List<NoteBlock>) onBlocksChanged;
  final BlockEditorConfig config;
  
  // Feature flags for gradual migration
  final bool useAdvancedFeatures;
  final bool enableTaskSync;
}

// lib/ui/widgets/blocks/block_editor_config.dart
class BlockEditorConfig {
  final bool allowReordering;
  final bool showBlockSelector;
  final bool enableMarkdown;
  final BlockTheme? theme;
}
```

##### Step 3.3: Migration Strategy (Day 11)
```dart
// Temporary wrapper for backward compatibility
class BlockEditor extends StatelessWidget {
  @Deprecated('Use UnifiedBlockEditor instead')
  BlockEditor({required this.blocks, required this.onChanged}) {
    // Redirect to unified implementation
    return UnifiedBlockEditor(
      blocks: blocks,
      onBlocksChanged: onChanged,
      config: BlockEditorConfig.legacy(),
    );
  }
}
```

---

## Phase 2: UI Component Consolidation (Week 3-4)

### 4. Dialog Action Components
**Impact**: ~280 lines | **Priority**: MEDIUM | **Risk**: LOW

#### Implementation Plan

##### Step 4.1: Create Reusable Dialog Components (Day 12)
```dart
// lib/ui/widgets/shared/dialog_actions.dart
class DialogActionRow extends StatelessWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String? cancelText;
  final String? confirmText;
  final bool isConfirmDestructive;
  final bool isConfirmDisabled;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onCancel != null)
          TextButton(
            onPressed: onCancel,
            child: Text(cancelText ?? 'Cancel'),
          ),
        const SizedBox(width: 8),
        if (onConfirm != null)
          FilledButton(
            onPressed: isConfirmDisabled ? null : onConfirm,
            style: isConfirmDestructive 
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
            child: Text(confirmText ?? 'Confirm'),
          ),
      ],
    );
  }
}

// lib/ui/widgets/shared/dialog_header.dart  
class DialogHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback? onClose;
  final Widget? trailing;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) trailing!,
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }
}
```

##### Step 4.2: Migrate Dialogs (Day 13-14)
```dart
// Before (task_metadata_dialog.dart)
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancel'),
    ),
    const SizedBox(width: 8),
    FilledButton(
      onPressed: _taskContent.trim().isEmpty ? null : _save,
      child: Text(widget.isNewTask ? 'Create' : 'Save'),
    ),
  ],
)

// After
DialogActionRow(
  onCancel: () => Navigator.of(context).pop(),
  onConfirm: _save,
  confirmText: widget.isNewTask ? 'Create' : 'Save',
  isConfirmDisabled: _taskContent.trim().isEmpty,
)
```

---

### 5. Task Row Widget Patterns
**Impact**: ~600+ lines | **Priority**: MEDIUM | **Risk**: MEDIUM

#### Implementation Plan

##### Step 5.1: Create Base Task Widget (Day 15-16)
```dart
// lib/ui/widgets/tasks/base_task_widget.dart
abstract class BaseTaskWidget extends StatelessWidget {
  final NoteTask task;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  
  // Shared UI components
  Widget buildCheckbox(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompleted = task.status == TaskStatus.completed;
    
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border.all(
            color: isCompleted
                ? getPriorityColor(task.priority)
                : colorScheme.outline,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
          color: isCompleted
              ? getPriorityColor(task.priority)
              : Colors.transparent,
        ),
        child: isCompleted
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
  
  Widget buildPriorityIndicator(BuildContext context);
  Widget buildDueDateChip(BuildContext context);
  Color getPriorityColor(TaskPriority priority);
}

// lib/ui/widgets/tasks/task_list_item.dart
class TaskListItem extends BaseTaskWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: buildCheckbox(context),
        title: Text(task.content),
        subtitle: buildDueDateChip(context),
        trailing: buildPriorityIndicator(context),
        onTap: onEdit,
      ),
    );
  }
}
```

##### Step 5.2: Create Task Widget Factory (Day 17)
```dart
// lib/ui/widgets/tasks/task_widget_factory.dart
class TaskWidgetFactory {
  static Widget create({
    required TaskDisplayMode mode,
    required NoteTask task,
    required TaskCallbacks callbacks,
  }) {
    switch (mode) {
      case TaskDisplayMode.list:
        return TaskListItem(task: task, ...callbacks);
      case TaskDisplayMode.tree:
        return TaskTreeNode(task: task, ...callbacks);
      case TaskDisplayMode.card:
        return TaskCard(task: task, ...callbacks);
      case TaskDisplayMode.compact:
        return CompactTaskItem(task: task, ...callbacks);
    }
  }
}
```

---

### 6. Folder UI Components
**Impact**: ~400+ lines | **Priority**: MEDIUM | **Risk**: LOW

#### Implementation Plan

##### Step 6.1: Create Folder Widget System (Day 18)
```dart
// lib/ui/widgets/folders/folder_item_base.dart
abstract class BaseFolderItem extends StatelessWidget {
  final LocalFolder folder;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onExpand;
  
  Widget buildIcon(BuildContext context) {
    return Icon(
      isExpanded ? Icons.folder_open : Icons.folder,
      color: isSelected 
        ? Theme.of(context).colorScheme.primary
        : null,
    );
  }
  
  Widget buildTitle(BuildContext context) {
    return Text(
      folder.name,
      style: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }
}
```

---

### 7. Analytics Card Components
**Impact**: ~450 lines | **Priority**: LOW | **Risk**: LOW

#### Implementation Plan

##### Step 7.1: Create Unified Metric Card (Day 19)
```dart
// lib/ui/widgets/analytics/unified_metric_card.dart
class UnifiedMetricCard extends StatelessWidget {
  final MetricCardConfig config;
  
  factory UnifiedMetricCard.simple({
    required String title,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return UnifiedMetricCard(
      config: MetricCardConfig.simple(
        title: title,
        value: value,
        icon: icon,
        color: color,
      ),
    );
  }
  
  factory UnifiedMetricCard.withTrend({
    required String title,
    required String value,
    required double trend,
    required IconData icon,
  }) {
    return UnifiedMetricCard(
      config: MetricCardConfig.withTrend(
        title: title,
        value: value,
        trend: trend,
        icon: icon,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: config.elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(config.borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(config.padding),
        child: _buildContent(context),
      ),
    );
  }
}
```

---

### 8. Chart Configuration Patterns
**Impact**: ~300 lines | **Priority**: LOW | **Risk**: LOW

#### Implementation Plan

##### Step 8.1: Create Chart Builders (Day 20)
```dart
// lib/ui/widgets/charts/chart_builders.dart
class ChartBuilders {
  static LineChartData buildLineChart({
    required List<FlSpot> spots,
    required ChartTheme theme,
    ChartConfig? config,
  }) {
    final effectiveConfig = config ?? ChartConfig.defaults();
    
    return LineChartData(
      gridData: _buildGridData(theme, effectiveConfig),
      titlesData: _buildTitlesData(theme, effectiveConfig),
      borderData: _buildBorderData(theme, effectiveConfig),
      lineBarsData: [_buildLineBarData(spots, theme, effectiveConfig)],
      minY: effectiveConfig.minY ?? 0,
      maxY: effectiveConfig.maxY ?? _calculateMaxY(spots),
    );
  }
  
  static FlGridData _buildGridData(ChartTheme theme, ChartConfig config) {
    return FlGridData(
      show: config.showGrid,
      drawVerticalLine: config.drawVerticalLines,
      horizontalInterval: config.horizontalInterval,
      getDrawingHorizontalLine: (value) => FlLine(
        color: theme.gridColor.withOpacity(config.gridOpacity),
        strokeWidth: config.gridStrokeWidth,
      ),
    );
  }
}
```

---

### 9. Settings Screen Patterns
**Impact**: ~200 lines | **Priority**: LOW | **Risk**: LOW

#### Implementation Plan

##### Step 9.1: Create Settings Components (Day 21)
```dart
// lib/ui/widgets/settings/settings_tile.dart
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive 
      ? theme.colorScheme.error
      : theme.colorScheme.onSurface;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
    );
  }
}

// lib/ui/widgets/settings/settings_section.dart
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: children),
        ),
      ],
    );
  }
}
```

---

## Phase 3: Testing & Validation (Week 5)

### Testing Strategy

#### Unit Testing (Day 22-23)
```dart
// test/services/base_reminder_service_test.dart
void main() {
  group('BaseReminderService', () {
    test('should handle permissions correctly', () async {
      final service = MockReminderService();
      final hasPermission = await service.hasNotificationPermissions();
      expect(hasPermission, isTrue);
    });
    
    test('should track analytics events', () async {
      final analytics = MockAnalyticsService();
      final service = TestReminderService(analytics: analytics);
      
      await service.createReminder(testConfig);
      
      verify(analytics.event(
        AnalyticsEvents.reminderSet,
        properties: any,
      )).called(1);
    });
  });
}
```

#### Integration Testing (Day 24)
```dart
// integration_test/reminder_flow_test.dart
void main() {
  testWidgets('Complete reminder flow', (tester) async {
    // Test creating reminder
    await tester.pumpWidget(MyApp());
    await tester.tap(find.byIcon(Icons.add_alarm));
    await tester.pumpAndSettle();
    
    // Verify UI updates
    expect(find.text('Reminder set'), findsOneWidget);
    
    // Verify database
    final reminders = await database.getAllReminders();
    expect(reminders.length, 1);
  });
}
```

#### Performance Testing (Day 25)
- Measure app startup time before/after refactoring
- Profile memory usage with new components
- Test scroll performance with refactored lists

---

## Migration & Rollout Plan

### Week 1-2: Development Environment
- Implement Phase 1 changes
- Run automated tests
- Code review by senior developers

### Week 3-4: Staging Environment  
- Deploy to staging
- QA team testing
- Performance benchmarking
- Fix identified issues

### Week 5: Production Rollout
- **Day 1**: Enable for internal team (dogfooding)
- **Day 3**: Roll out to 5% of users
- **Day 5**: Expand to 25% of users
- **Day 7**: Full rollout if metrics are green

### Feature Flags
```dart
// lib/core/feature_flags.dart
class FeatureFlags {
  static bool get useUnifiedReminders => 
    RemoteConfig.getBool('use_unified_reminders') ?? false;
    
  static bool get useNewBlockEditor =>
    RemoteConfig.getBool('use_new_block_editor') ?? false;
    
  static bool get useRefactoredComponents =>
    RemoteConfig.getBool('use_refactored_components') ?? false;
}
```

---

## Risk Mitigation

### High-Risk Areas
1. **Reminder Services**: Affects core functionality
   - Mitigation: Extensive testing, gradual rollout
   
2. **Block Editor**: User-facing, complex component
   - Mitigation: A/B testing, maintain legacy version

### Rollback Procedures
1. **Immediate Rollback** (< 1 hour)
   - Disable feature flags
   - Revert to previous version
   
2. **Gradual Rollback** (1-24 hours)
   - Reduce rollout percentage
   - Fix issues in parallel
   - Re-deploy fixed version

---

## Success Metrics

### Code Quality Metrics
- [ ] Duplication reduced by 60-70%
- [ ] Test coverage increased to 80%+
- [ ] Cyclomatic complexity reduced by 30%
- [ ] Build time reduced by 10-15%

### Performance Metrics
- [ ] App startup time ≤ 2 seconds
- [ ] Memory usage reduced by 5-10%
- [ ] Scroll performance: 60 FPS maintained

### Business Metrics
- [ ] No increase in crash rate (< 0.1%)
- [ ] No increase in user complaints
- [ ] Developer velocity increased by 20%

---

## Documentation Requirements

### Developer Documentation
- [ ] Architecture decision records (ADRs)
- [ ] Migration guide for each component
- [ ] API documentation for new base classes
- [ ] Example implementations

### Code Documentation
```dart
/// Base class for all reminder services.
/// 
/// This class provides common functionality for different types of reminders
/// including permission management, database operations, and analytics.
/// 
/// Subclasses should override [createReminder] to implement specific logic.
/// 
/// Example:
/// ```dart
/// class MyReminderService extends BaseReminderService {
///   @override
///   Future<int?> createReminder(ReminderConfig config) {
///     // Implementation
///   }
/// }
/// ```
abstract class BaseReminderService {
  // ...
}
```

---

## Team Responsibilities

### Development Team
- **Lead Developer**: Architecture, code reviews
- **Senior Developer 1**: Service layer refactoring
- **Senior Developer 2**: UI component consolidation
- **Junior Developer**: Testing, documentation

### QA Team
- Test plan creation
- Manual testing
- Regression testing
- Performance testing

### DevOps Team
- Feature flag configuration
- Monitoring setup
- Rollout orchestration
- Rollback procedures

---

## Monitoring & Alerting

### Key Metrics to Monitor
```yaml
# monitoring/refactoring_alerts.yaml
alerts:
  - name: reminder_creation_failure_rate
    threshold: 5%
    action: page_on_call
    
  - name: block_editor_crash_rate
    threshold: 1%
    action: rollback_immediately
    
  - name: memory_usage_increase
    threshold: 20%
    action: investigate
    
  - name: api_latency_increase
    threshold: 500ms
    action: scale_up
```

### Dashboard Setup
- Real-time error rates
- Performance metrics
- User engagement metrics
- A/B test results

---

## Post-Implementation Review

### Week 6: Retrospective
- What went well?
- What could be improved?
- Lessons learned
- Documentation updates

### Success Criteria Validation
- [ ] All success metrics met
- [ ] No critical bugs in production
- [ ] Positive developer feedback
- [ ] Improved development velocity

---

## Appendix A: File Structure After Refactoring

```
lib/
├── services/
│   ├── reminders/
│   │   ├── base_reminder_service.dart
│   │   ├── recurring_reminder_service.dart
│   │   ├── geofence_reminder_service.dart
│   │   ├── snooze_reminder_service.dart
│   │   └── reminder_coordinator.dart
│   └── permission_manager.dart
├── ui/
│   └── widgets/
│       ├── shared/
│       │   ├── dialog_actions.dart
│       │   ├── dialog_header.dart
│       │   └── base_components.dart
│       ├── tasks/
│       │   ├── base_task_widget.dart
│       │   ├── task_list_item.dart
│       │   ├── task_tree_node.dart
│       │   └── task_widget_factory.dart
│       ├── blocks/
│       │   └── unified_block_editor.dart
│       ├── analytics/
│       │   └── unified_metric_card.dart
│       └── charts/
│           └── chart_builders.dart
```

---

## Appendix B: Migration Checklist

### Pre-Migration
- [ ] Create feature flags
- [ ] Set up monitoring
- [ ] Backup production database
- [ ] Document current behavior
- [ ] Create rollback plan

### During Migration
- [ ] Run tests continuously
- [ ] Monitor error rates
- [ ] Check performance metrics
- [ ] Gather user feedback
- [ ] Document issues

### Post-Migration
- [ ] Remove old code
- [ ] Update documentation
- [ ] Close related tickets
- [ ] Schedule retrospective
- [ ] Plan next improvements

---

## Conclusion

This refactoring plan addresses all 9 identified duplication areas with a systematic, low-risk approach. The phased implementation allows for continuous validation and easy rollback if issues arise. Expected benefits include:

- **60-70% reduction** in code duplication
- **Improved maintainability** and developer velocity
- **Better performance** through optimized components
- **Reduced bug surface area** through centralized logic
- **Enhanced testability** with clear component boundaries

The total investment of 120-160 hours over 5 weeks will yield long-term benefits in code quality, team productivity, and application reliability.
