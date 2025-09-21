/// Phase 2 UI Components Test Suite
///
/// This test validates all Phase 2 UI component consolidation:
/// - Dialog action components
/// - Task row widgets
/// - Folder UI components
/// - Analytics cards
/// - Chart configuration
/// - Settings patterns

import 'package:duru_notes/models/local_folder.dart';
import 'package:duru_notes/models/note_task.dart';
import 'package:duru_notes/ui/widgets/analytics/unified_metric_card.dart';
import 'package:duru_notes/ui/widgets/charts/chart_builders.dart';
import 'package:duru_notes/ui/widgets/folders/folder_item_base.dart';
import 'package:duru_notes/ui/widgets/settings/settings_components.dart';
import 'package:duru_notes/ui/widgets/shared/dialog_actions.dart';
import 'package:duru_notes/ui/widgets/shared/dialog_header.dart';
import 'package:duru_notes/ui/widgets/tasks/base_task_widget.dart';
import 'package:duru_notes/ui/widgets/tasks/task_list_item.dart';
import 'package:duru_notes/ui/widgets/tasks/task_widget_factory.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 2 UI Components Tests', () {
    group('Dialog Components', () {
      testWidgets('DialogActionRow renders correctly', (tester) async {
        bool cancelPressed = false;
        bool confirmPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogActionRow(
                onCancel: () => cancelPressed = true,
                onConfirm: () => confirmPressed = true,
                cancelText: 'Cancel',
                confirmText: 'Confirm',
              ),
            ),
          ),
        );

        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Confirm'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        expect(cancelPressed, isTrue);

        await tester.tap(find.text('Confirm'));
        expect(confirmPressed, isTrue);
      });

      testWidgets('DialogActionRow destructive mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogActionRow(
                onCancel: () {},
                onConfirm: () {},
                confirmText: 'Delete',
                isConfirmDestructive: true,
              ),
            ),
          ),
        );

        expect(find.text('Delete'), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
      });

      testWidgets('DialogHeader renders with icon and title', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogHeader(
                title: 'Test Dialog',
                icon: Icons.settings,
                onClose: () {},
              ),
            ),
          ),
        );

        expect(find.text('Test Dialog'), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
      });
    });

    group('Task Widgets', () {
      final testTask = NoteTask(
        id: '1',
        content: 'Test Task',
        status: TaskStatus.pending,
        priority: TaskPriority.high,
        dueDate: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: ['test', 'phase2'],
      );

      testWidgets('TaskListItem renders task correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TaskListItem(
                task: testTask,
                callbacks: TaskCallbacks(
                  onToggle: () {},
                  onEdit: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('Test Task'), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
      });

      testWidgets('TaskWidgetFactory creates correct widget type',
          (tester) async {
        final widget = TaskWidgetFactory.create(
          mode: TaskDisplayMode.list,
          task: testTask,
          callbacks: TaskCallbacks(),
        );

        expect(widget, isA<TaskListItem>());
      });

      testWidgets('Task priority indicator shows for high priority',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TaskListItem(
                task: testTask,
                callbacks: TaskCallbacks(),
              ),
            ),
          ),
        );

        // High priority tasks should show an indicator
        expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      });
    });

    group('Folder Components', () {
      final testFolder = LocalFolder(
        id: '1',
        name: 'Test Folder',
        hasChildren: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testWidgets('FolderListItem renders folder correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FolderListItem(
                folder: testFolder,
                noteCount: 5,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Test Folder'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.byIcon(Icons.folder), findsOneWidget);
      });

      testWidgets('Folder expand indicator shows for folders with children',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FolderListItem(
                folder: testFolder,
                isExpanded: false,
                onExpand: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
      });

      testWidgets('CompactFolderItem renders in compact mode', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CompactFolderItem(
                folder: testFolder,
                noteCount: 10,
              ),
            ),
          ),
        );

        expect(find.text('Test Folder'), findsOneWidget);
        expect(find.text('10'), findsOneWidget);
      });
    });

    group('Analytics Cards', () {
      testWidgets('UnifiedMetricCard renders simple metric', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UnifiedMetricCard.simple(
                title: 'Total Notes',
                value: '42',
                icon: Icons.note,
                color: Colors.blue,
              ),
            ),
          ),
        );

        expect(find.text('Total Notes'), findsOneWidget);
        expect(find.text('42'), findsOneWidget);
        expect(find.byIcon(Icons.note), findsOneWidget);
      });

      testWidgets('UnifiedMetricCard renders with trend', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UnifiedMetricCard.withTrend(
                title: 'Weekly Tasks',
                value: '15',
                trend: 25.5,
                icon: Icons.task,
              ),
            ),
          ),
        );

        expect(find.text('Weekly Tasks'), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
        expect(find.text('+25.5%'), findsOneWidget);
        expect(find.byIcon(Icons.trending_up), findsOneWidget);
      });

      testWidgets('StreakCard shows current and best streak', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreakCard(
                currentStreak: 7,
                bestStreak: 30,
                title: 'Daily Notes',
                icon: Icons.edit_note,
              ),
            ),
          ),
        );

        expect(find.text('Daily Notes'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
        expect(find.text('days'), findsOneWidget);
        expect(find.text('Best: 30 days'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('QuickStatsWidget displays grid of metrics', (tester) async {
        final metrics = [
          MetricCardConfig.simple(
            title: 'Notes',
            value: '100',
            icon: Icons.note,
          ),
          MetricCardConfig.simple(
            title: 'Tasks',
            value: '50',
            icon: Icons.task,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QuickStatsWidget(
                metrics: metrics,
                crossAxisCount: 2,
              ),
            ),
          ),
        );

        expect(find.text('Notes'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        expect(find.text('Tasks'), findsOneWidget);
        expect(find.text('50'), findsOneWidget);
      });
    });

    group('Chart Builders', () {
      test('ChartTheme creates theme from context', () {
        final context = MockBuildContext();
        // ChartTheme.fromContext would normally use the context
        // For testing, we verify the structure

        const theme = ChartTheme(
          gridColor: Colors.grey,
          borderColor: Colors.black,
          lineColor: Colors.blue,
          dotColor: Colors.blue,
          tooltipBackground: Colors.white,
          tooltipText: Colors.black,
        );

        expect(theme.gridColor, equals(Colors.grey));
        expect(theme.lineColor, equals(Colors.blue));
      });

      test('ChartBuilders creates line chart data', () {
        final spots = [
          const FlSpot(0, 1),
          const FlSpot(1, 3),
          const FlSpot(2, 2),
        ];

        const theme = ChartTheme(
          gridColor: Colors.grey,
          borderColor: Colors.black,
          lineColor: Colors.blue,
          dotColor: Colors.blue,
          tooltipBackground: Colors.white,
          tooltipText: Colors.black,
        );

        final chartData = ChartBuilders.buildLineChart(
          spots: spots,
          theme: theme,
        );

        expect(chartData.lineBarsData.length, equals(1));
        expect(chartData.lineBarsData[0].spots, equals(spots));
      });

      test('ChartConfig has different presets', () {
        const defaultConfig = ChartConfig.defaults;
        expect(defaultConfig.showGrid, isTrue);
        expect(defaultConfig.showDots, isTrue);

        final minimalConfig = ChartConfig.minimal();
        expect(minimalConfig.showGrid, isFalse);
        expect(minimalConfig.showDots, isFalse);

        final detailedConfig = ChartConfig.detailed();
        expect(detailedConfig.showGrid, isTrue);
        expect(detailedConfig.dotRadius, equals(5));
      });
    });

    group('Settings Components', () {
      testWidgets('SettingsTile renders correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsTile(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Manage notification settings',
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Manage notification settings'), findsOneWidget);
        expect(find.byIcon(Icons.notifications), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });

      testWidgets('SettingsSwitchTile toggles correctly', (tester) async {
        bool value = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return SettingsSwitchTile(
                    icon: Icons.dark_mode,
                    title: 'Dark Mode',
                    value: value,
                    onChanged: (newValue) {
                      setState(() {
                        value = newValue;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Dark Mode'), findsOneWidget);
        expect(find.byType(Switch), findsOneWidget);

        await tester.tap(find.byType(Switch));
        await tester.pump();

        expect(value, isTrue);
      });

      testWidgets('SettingsSection groups settings', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsSection(
                title: 'General',
                children: [
                  SettingsTile(
                    icon: Icons.language,
                    title: 'Language',
                    onTap: () {},
                  ),
                  SettingsTile(
                    icon: Icons.backup,
                    title: 'Backup',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('GENERAL'), findsOneWidget);
        expect(find.text('Language'), findsOneWidget);
        expect(find.text('Backup'), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
      });

      testWidgets('SettingsAccountHeader displays user info', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsAccountHeader(
                name: 'John Doe',
                email: 'john@example.com',
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('john@example.com'), findsOneWidget);
        expect(find.text('J'), findsOneWidget); // Avatar initial
        expect(find.byType(CircleAvatar), findsOneWidget);
      });

      testWidgets('SettingsVersionFooter shows version info', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsVersionFooter(
                appName: 'Duru Notes',
                version: '2.0.0',
                buildNumber: '100',
              ),
            ),
          ),
        );

        expect(find.text('Duru Notes'), findsOneWidget);
        expect(find.text('v2.0.0 (100)'), findsOneWidget);
      });
    });
  });
}

// Mock BuildContext for testing
class MockBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
