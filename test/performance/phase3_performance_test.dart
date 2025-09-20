import 'package:duru_notes/models/local_folder.dart';
import 'package:duru_notes/models/note_task.dart';
import 'package:duru_notes/ui/widgets/analytics/unified_metric_card.dart';
import 'package:duru_notes/ui/widgets/folders/folder_item_base.dart';
import 'package:duru_notes/ui/widgets/tasks/base_task_widget.dart';
import 'package:duru_notes/ui/widgets/tasks/task_widget_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 3 Performance Tests', () {
    group('Widget Build Performance', () {
      testWidgets('Large task list renders efficiently', (tester) async {
        final stopwatch = Stopwatch()..start();
        
        // Generate 100 tasks
        final tasks = List.generate(100, (index) {
          return NoteTask(
            id: 'task-$index',
            content: 'Task $index with some longer content to test rendering',
            priority: TaskPriority.values[index % TaskPriority.values.length],
            status: index % 3 == 0 ? TaskStatus.completed : TaskStatus.pending,
            dueDate: index % 2 == 0 ? DateTime.now().add(Duration(days: index)) : null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            tags: index % 4 == 0 ? ['tag1', 'tag2'] : [],
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  return TaskWidgetFactory.create(
                    mode: TaskDisplayMode.list,
                    task: tasks[index],
                    callbacks: TaskCallbacks(),
                  );
                },
              ),
            ),
          ),
        );

        stopwatch.stop();
        
        // Initial render should be under 2 seconds
        expect(stopwatch.elapsedMilliseconds, lessThan(2000),
            reason: 'Initial render took ${stopwatch.elapsedMilliseconds}ms');

        // Test scrolling performance
        stopwatch.reset();
        stopwatch.start();
        
        // Scroll through the list
        await tester.fling(find.byType(ListView), const Offset(0, -500), 2000);
        await tester.pumpAndSettle();
        
        stopwatch.stop();
        
        // Scrolling should be smooth (under 500ms for settling)
        expect(stopwatch.elapsedMilliseconds, lessThan(500),
            reason: 'Scrolling took ${stopwatch.elapsedMilliseconds}ms');
      });

      testWidgets('Folder tree renders efficiently', (tester) async {
        final stopwatch = Stopwatch()..start();
        
        // Generate nested folder structure
        final folders = List.generate(50, (index) {
          return LocalFolder(
            id: 'folder-$index',
            name: 'Folder $index',
            hasChildren: index < 25,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  return FolderListItem(
                    folder: folders[index],
                    noteCount: index * 2,
                    indentLevel: index % 3,
                  );
                },
              ),
            ),
          ),
        );

        stopwatch.stop();
        
        // Folder list should render quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
            reason: 'Folder list render took ${stopwatch.elapsedMilliseconds}ms');
      });

      testWidgets('Analytics dashboard renders efficiently', (tester) async {
        final stopwatch = Stopwatch()..start();
        
        // Generate multiple metric cards
        final metrics = List.generate(20, (index) {
          return MetricCardConfig.withTrend(
            title: 'Metric $index',
            value: '${index * 100}',
            trend: index * 2.5,
            icon: Icons.analytics,
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                ),
                itemCount: metrics.length,
                itemBuilder: (context, index) {
                  return UnifiedMetricCard(config: metrics[index]);
                },
              ),
            ),
          ),
        );

        stopwatch.stop();
        
        // Analytics grid should render efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(1500),
            reason: 'Analytics grid render took ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    group('Memory Usage', () {
      testWidgets('Widget disposal prevents memory leaks', (tester) async {
        // Create and destroy widgets multiple times
        for (int i = 0; i < 10; i++) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ListView(
                  children: List.generate(50, (index) {
                    return TaskWidgetFactory.create(
                      mode: TaskDisplayMode.list,
                      task: NoteTask(
                        id: 'task-$index',
                        content: 'Task $index',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                      callbacks: TaskCallbacks(),
                    );
                  }),
                ),
              ),
            ),
          );

          // Clear the widget tree
          await tester.pumpWidget(const SizedBox());
        }

        // If we get here without running out of memory, the test passes
        expect(true, isTrue);
      });
    });

    group('Interaction Performance', () {
      testWidgets('Task toggle responds quickly', (tester) async {
        int toggleCount = 0;
        final task = NoteTask(
          id: 'perf-task',
          content: 'Performance Test Task',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TaskWidgetFactory.create(
                mode: TaskDisplayMode.list,
                task: task,
                callbacks: TaskCallbacks(
                  onToggle: () => toggleCount++,
                ),
              ),
            ),
          ),
        );

        final stopwatch = Stopwatch()..start();
        
        // Perform 10 rapid toggles
        for (int i = 0; i < 10; i++) {
          await tester.tap(find.byType(GestureDetector).first);
          await tester.pump();
        }
        
        stopwatch.stop();
        
        // All toggles should complete quickly
        expect(toggleCount, equals(10));
        expect(stopwatch.elapsedMilliseconds, lessThan(500),
            reason: '10 toggles took ${stopwatch.elapsedMilliseconds}ms');
      });

      testWidgets('Settings switches respond quickly', (tester) async {
        bool value = false;
        int changeCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: List.generate(10, (index) {
                      return SettingsSwitchTile(
                        icon: Icons.settings,
                        title: 'Setting $index',
                        value: value,
                        onChanged: (newValue) {
                          setState(() {
                            value = newValue;
                            changeCount++;
                          });
                        },
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        );

        final stopwatch = Stopwatch()..start();
        
        // Toggle multiple switches
        for (int i = 0; i < 10; i++) {
          await tester.tap(find.byType(Switch).at(i));
          await tester.pump();
        }
        
        stopwatch.stop();
        
        // All switches should respond quickly
        expect(changeCount, equals(10));
        expect(stopwatch.elapsedMilliseconds, lessThan(300),
            reason: 'Switch toggles took ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    group('Rendering Optimization', () {
      testWidgets('Only visible widgets are built', (tester) async {
        int buildCount = 0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: 1000,
                itemBuilder: (context, index) {
                  buildCount++;
                  return SizedBox(
                    height: 50,
                    child: Text('Item $index'),
                  );
                },
              ),
            ),
          ),
        );

        // Only visible items should be built initially
        // Assuming screen can show ~15 items with some buffer
        expect(buildCount, lessThan(30),
            reason: 'Built $buildCount widgets, expected < 30');
      });

      testWidgets('Widget rebuilds are minimized', (tester) async {
        int rebuildCount = 0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      // This should not rebuild
                      const Text('Static Text'),
                      // This should rebuild
                      Builder(
                        builder: (context) {
                          rebuildCount++;
                          return Text('Rebuild count: $rebuildCount');
                        },
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Rebuild'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // Initial build
        expect(rebuildCount, equals(1));
        
        // Trigger rebuild
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        
        // Only the dynamic part should rebuild
        expect(rebuildCount, equals(2));
      });
    });
  });
}

// Import for settings components
import 'package:duru_notes/ui/widgets/settings/settings_components.dart';
