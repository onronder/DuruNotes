import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/data/local/app_db.dart'
    show TaskPriority, TaskStatus;
import 'package:duru_notes/models/local_folder.dart';
import 'package:duru_notes/models/note_task.dart' as legacy;
import 'package:duru_notes/ui/widgets/analytics/unified_metric_card.dart';
import 'package:duru_notes/ui/widgets/folders/folder_item_base.dart';
import 'package:duru_notes/ui/widgets/settings/settings_components.dart';
import 'package:duru_notes/ui/widgets/shared/dialog_actions.dart';
import 'package:duru_notes/ui/widgets/shared/dialog_header.dart';
import 'package:duru_notes/ui/widgets/tasks/task_widget_adapter.dart';
import 'package:duru_notes/ui/widgets/tasks/task_widget_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 3 Integration Tests', () {
    group('Complete Dialog Flow', () {
      testWidgets('Dialog with header and actions works together', (
        tester,
      ) async {
        bool confirmed = false;
        bool cancelled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DialogHeader(
                      title: 'Confirm Action',
                      icon: Icons.warning,
                      onClose: () => cancelled = true,
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Are you sure you want to proceed?'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: DialogActionRowExtensions.destructive(
                        onConfirm: () => confirmed = true,
                        onCancel: () => cancelled = true,
                        confirmText: 'Delete',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Verify all elements render
        expect(find.text('Confirm Action'), findsOneWidget);
        expect(find.byIcon(Icons.warning), findsOneWidget);
        expect(find.text('Are you sure you want to proceed?'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Test interaction
        await tester.tap(find.text('Delete'));
        expect(confirmed, isTrue);
        expect(cancelled, isFalse);
      });
    });

    group('Task Management Flow', () {
      testWidgets('Task list with multiple display modes', (tester) async {
        final now = DateTime.now();
        final tasks = [
          legacy.UiNoteTask(
            id: '1',
            content: 'Task 1',
            priority: legacy.UiTaskPriority.high,
            createdAt: now,
            updatedAt: now,
          ),
          legacy.UiNoteTask(
            id: '2',
            content: 'Task 2',
            status: legacy.UiTaskStatus.completed,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final callbacks = _RecordingCallbacks();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: tasks
                    .map(
                      (task) => TaskWidgetFactory.create(
                        mode: TaskDisplayMode.list,
                        uiTask: task,
                        callbacks: callbacks,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );

        // Verify tasks render
        expect(find.text('Task 1'), findsOneWidget);
        expect(find.text('Task 2'), findsOneWidget);

        // High-priority chip rendered for first task
        expect(find.text('High'), findsOneWidget);

        // Completed task checkbox reflects status
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value,
          isFalse,
        );
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value,
          isTrue,
        );
      });

      testWidgets('Task interaction callbacks work correctly', (tester) async {
        final now = DateTime.now();
        final task = legacy.UiNoteTask(
          id: 'test-task',
          content: 'Interactive Task',
          createdAt: now,
          updatedAt: now,
        );

        final callbacks = _RecordingCallbacks();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TaskWidgetFactory.create(
                mode: TaskDisplayMode.list,
                uiTask: task,
                callbacks: callbacks,
              ),
            ),
          ),
        );

        // Test checkbox toggle
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(callbacks.lastStatusChangeId, equals('test-task'));
        expect(callbacks.lastStatus, equals(TaskStatus.completed));

        // Test edit tap
        await tester.tap(find.text('Interactive Task'));
        await tester.pump();
        expect(callbacks.lastEditedTaskId, equals('test-task'));
      });
    });

    group('Folder Navigation Flow', () {
      testWidgets('Folder hierarchy with expand/collapse', (tester) async {
        bool expanded = false;

        final folder = LocalFolder(
          id: '1',
          name: 'Documents',
          hasChildren: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return FolderListItem(
                    folder: folder,
                    isExpanded: expanded,
                    onExpand: () => setState(() => expanded = !expanded),
                    noteCount: 10,
                  );
                },
              ),
            ),
          ),
        );

        // Verify initial state
        expect(find.text('Documents'), findsOneWidget);
        expect(find.text('10'), findsOneWidget);
        expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);

        // Test expand
        await tester.tap(find.byIcon(Icons.keyboard_arrow_right));
        await tester.pump();

        expect(expanded, isTrue);
        expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      });
    });

    group('Analytics Dashboard Flow', () {
      testWidgets('Complete analytics dashboard renders', (tester) async {
        final metrics = [
          MetricCardConfig.simple(
            title: 'Total Notes',
            value: '156',
            icon: Icons.note,
          ),
          MetricCardConfig.withTrend(
            title: 'Weekly Tasks',
            value: '42',
            trend: 15.5,
            icon: Icons.task,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    QuickStatsWidget(metrics: metrics, crossAxisCount: 2),
                    const SizedBox(height: 16),
                    StreakCard(
                      currentStreak: 7,
                      bestStreak: 30,
                      title: 'Daily Notes',
                      icon: Icons.edit_note,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Verify all metrics render
        expect(find.text('Total Notes'), findsOneWidget);
        expect(find.text('156'), findsOneWidget);
        expect(find.text('Weekly Tasks'), findsOneWidget);
        expect(find.text('42'), findsOneWidget);
        expect(find.text('+15.5%'), findsOneWidget);

        // Verify streak card
        expect(find.text('Daily Notes'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
        expect(find.text('Best: 30 days'), findsOneWidget);
      });
    });

    group('Settings Screen Flow', () {
      testWidgets('Complete settings screen with all components', (
        tester,
      ) async {
        bool darkMode = false;
        String selectedTheme = 'light';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return ListView(
                    children: [
                      SettingsAccountHeader(
                        name: 'John Doe',
                        email: 'john@example.com',
                        onTap: () {},
                      ),
                      SettingsSection(
                        title: 'Appearance',
                        children: [
                          SettingsSwitchTile(
                            icon: Icons.dark_mode,
                            title: 'Dark Mode',
                            value: darkMode,
                            onChanged: (value) =>
                                setState(() => darkMode = value),
                          ),
                          SettingsRadioTile<String>(
                            icon: Icons.light_mode,
                            title: 'Light Theme',
                            value: 'light',
                            groupValue: selectedTheme,
                            onChanged: (value) =>
                                setState(() => selectedTheme = value!),
                          ),
                          SettingsRadioTile<String>(
                            icon: Icons.dark_mode,
                            title: 'Dark Theme',
                            value: 'dark',
                            groupValue: selectedTheme,
                            onChanged: (value) =>
                                setState(() => selectedTheme = value!),
                          ),
                        ],
                      ),
                      SettingsSection(
                        title: 'About',
                        children: [
                          SettingsNavigationTile(
                            icon: Icons.info,
                            title: 'App Info',
                            badge: 'v2.0',
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SettingsVersionFooter(
                        appName: 'Duru Notes',
                        version: '2.0.0',
                        buildNumber: '100',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // Verify all sections render
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('john@example.com'), findsOneWidget);
        expect(find.text('APPEARANCE'), findsOneWidget);
        expect(find.text('Dark Mode'), findsOneWidget);
        expect(find.text('ABOUT'), findsOneWidget);
        expect(find.text('App Info'), findsOneWidget);
        expect(find.text('v2.0'), findsOneWidget);
        expect(find.text('Duru Notes'), findsOneWidget);

        // Test dark mode toggle
        await tester.tap(find.byType(Switch).first);
        await tester.pump();
        expect(darkMode, isTrue);

        // Test radio selection
        await tester.tap(find.text('Dark Theme'));
        await tester.pump();
        expect(selectedTheme, equals('dark'));
      });
    });

    group('Feature Flag Integration', () {
      testWidgets('Components respect feature flags', (tester) async {
        final flags = FeatureFlags.instance;

        // Test with flags enabled
        flags.setOverride('use_refactored_components', true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  if (flags.isEnabled('use_refactored_components')) {
                    return const Text('New Components');
                  } else {
                    return const Text('Legacy Components');
                  }
                },
              ),
            ),
          ),
        );

        expect(find.text('New Components'), findsOneWidget);
        expect(find.text('Legacy Components'), findsNothing);

        // Test with flags disabled
        flags.setOverride('use_refactored_components', false);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  if (flags.isEnabled('use_refactored_components')) {
                    return const Text('New Components');
                  } else {
                    return const Text('Legacy Components');
                  }
                },
              ),
            ),
          ),
        );

        expect(find.text('New Components'), findsNothing);
        expect(find.text('Legacy Components'), findsOneWidget);

        // Clear overrides
        flags.clearOverrides();
      });
    });

    group('Cross-Component Integration', () {
      testWidgets('Multiple component types work together', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Integration Test')),
              body: ListView(
                children: [
                  // Task section
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TaskWidgetFactory.create(
                    mode: TaskDisplayMode.compact,
                    uiTask: legacy.UiNoteTask(
                      id: '1',
                      content: 'Review documents',
                      priority: legacy.UiTaskPriority.high,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                    callbacks: const _NoopCallbacks(),
                  ),

                  // Folder section
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Folders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  CompactFolderItem(
                    folder: LocalFolder(
                      id: '1',
                      name: 'Work',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                    noteCount: 25,
                  ),

                  // Analytics section
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: UnifiedMetricCard.simple(
                      title: 'Completed',
                      value: '85%',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Verify all sections render correctly
        expect(find.text('Integration Test'), findsOneWidget);
        expect(find.text('Tasks'), findsOneWidget);
        expect(find.text('Review documents'), findsOneWidget);
        expect(find.text('Folders'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('25'), findsOneWidget);
        expect(find.text('Statistics'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('85%'), findsOneWidget);
      });
    });
  });
}

class _RecordingCallbacks implements UnifiedTaskCallbacks {
  String? lastStatusChangeId;
  TaskStatus? lastStatus;
  String? lastPriorityChangeId;
  TaskPriority? lastPriority;
  String? lastEditedTaskId;
  String? lastDeletedTaskId;
  String? lastContentChangeId;
  String? lastDueDateChangeId;
  DateTime? lastDueDate;

  @override
  Future<void> onStatusChanged(String taskId, TaskStatus newStatus) async {
    lastStatusChangeId = taskId;
    lastStatus = newStatus;
  }

  @override
  Future<void> onPriorityChanged(
    String taskId,
    TaskPriority newPriority,
  ) async {
    lastPriorityChangeId = taskId;
    lastPriority = newPriority;
  }

  @override
  Future<void> onContentChanged(String taskId, String newContent) async {
    lastContentChangeId = taskId;
  }

  @override
  Future<void> onDeleted(String taskId) async {
    lastDeletedTaskId = taskId;
  }

  @override
  void onEdit(String taskId) {
    lastEditedTaskId = taskId;
  }

  @override
  Future<void> onDueDateChanged(String taskId, DateTime? newDate) async {
    lastDueDateChangeId = taskId;
    lastDueDate = newDate;
  }
}

class _NoopCallbacks implements UnifiedTaskCallbacks {
  const _NoopCallbacks();

  @override
  Future<void> onStatusChanged(String taskId, TaskStatus newStatus) async {}

  @override
  Future<void> onPriorityChanged(
    String taskId,
    TaskPriority newPriority,
  ) async {}

  @override
  Future<void> onContentChanged(String taskId, String newContent) async {}

  @override
  Future<void> onDeleted(String taskId) async {}

  @override
  void onEdit(String taskId) {}

  @override
  Future<void> onDueDateChanged(String taskId, DateTime? newDate) async {}
}
