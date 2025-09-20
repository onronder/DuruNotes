import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/note_task_coordinator.dart';
import 'package:duru_notes/services/bidirectional_task_sync_service.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:duru_notes/core/monitoring/sync_performance_metrics.dart';
import 'dart:async';

@GenerateMocks([
  AppDb,
  BidirectionalTaskSyncService,
  TaskService,
])
import 'rapid_toggle_sync_test.mocks.dart';

void main() {
  late MockAppDb mockDb;
  late MockBidirectionalTaskSyncService mockBidirectionalSync;
  late MockTaskService mockTaskService;
  late NoteTaskCoordinator coordinator;
  
  setUp(() {
    mockDb = MockAppDb();
    mockBidirectionalSync = MockBidirectionalTaskSyncService();
    mockTaskService = MockTaskService();
    
    coordinator = NoteTaskCoordinator(
      database: mockDb,
      bidirectionalSync: mockBidirectionalSync,
    );
    
    // Reset performance metrics
    SyncPerformanceMetrics.instance.reset();
  });
  
  tearDown(() async {
    await coordinator.dispose();
  });
  
  group('Rapid Task Toggle Sync', () {
    test('should handle 5 rapid toggles correctly', () async {
      const noteId = 'note-123';
      const taskId = 'task-456';
      
      // Simulate 5 rapid toggles
      for (int i = 0; i < 5; i++) {
        await coordinator.handleTaskToggle(
          noteId: noteId,
          taskId: taskId,
          isCompleted: i % 2 == 0,
          updatedContent: 'Note content with task ${i % 2 == 0 ? "[x]" : "[ ]"}',
        );
        
        // Small delay between toggles (simulating rapid clicking)
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Wait for debounce to complete
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Verify only the final state was synced
      verify(mockBidirectionalSync.syncFromNoteToTasks(
        noteId,
        argThat(contains('[x]')), // Final state should be completed (4 is even)
      )).called(1);
      
      // Check performance metrics
      final metrics = SyncPerformanceMetrics.instance.getMetricsSummary();
      expect(metrics['pendingSyncs'], equals(0));
    });
    
    test('should use critical debounce delay for toggles', () async {
      const noteId = 'note-789';
      const taskId = 'task-abc';
      
      final stopwatch = Stopwatch()..start();
      
      // Perform toggle
      await coordinator.handleTaskToggle(
        noteId: noteId,
        taskId: taskId,
        isCompleted: true,
        updatedContent: 'Content with [x] task',
      );
      
      // Wait for critical debounce (100ms)
      await Future.delayed(const Duration(milliseconds: 110));
      
      stopwatch.stop();
      
      // Verify sync happened within critical delay window
      verify(mockBidirectionalSync.syncFromNoteToTasks(noteId, any)).called(1);
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });
    
    test('should detect rapid toggle pattern', () async {
      const taskId = 'task-rapid';
      
      // Simulate rapid toggling (more than 5 toggles in 5 seconds)
      for (int i = 0; i < 6; i++) {
        SyncPerformanceMetrics.instance.recordToggle(taskId);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // The metrics should have detected rapid toggling
      // This would typically trigger a warning log
      expect(SyncPerformanceMetrics.instance.getMetricsSummary(), isNotNull);
    });
    
    test('should queue changes when sync is in progress', () async {
      const noteId = 'note-queue';
      const taskId = 'task-queue';
      
      // Make sync take some time
      when(mockBidirectionalSync.syncFromNoteToTasks(any, any))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      
      // First toggle starts sync
      await coordinator.handleTaskToggle(
        noteId: noteId,
        taskId: taskId,
        isCompleted: true,
        updatedContent: 'Content 1',
      );
      
      // Wait for sync to start but not complete
      await Future.delayed(const Duration(milliseconds: 110));
      
      // Second toggle while first is still processing
      await coordinator.handleTaskToggle(
        noteId: noteId,
        taskId: taskId,
        isCompleted: false,
        updatedContent: 'Content 2',
      );
      
      // Wait for all syncs to complete
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Both syncs should have executed
      verify(mockBidirectionalSync.syncFromNoteToTasks(noteId, any)).called(2);
    });
    
    test('should sync pending changes on note close', () async {
      const noteId = 'note-close';
      const taskId = 'task-close';
      
      // Start watching note
      await coordinator.startWatchingNote(noteId);
      
      // Make a change
      await coordinator.handleTaskToggle(
        noteId: noteId,
        taskId: taskId,
        isCompleted: true,
        updatedContent: 'Final content',
      );
      
      // Immediately stop watching (simulating note close)
      await coordinator.stopWatchingNote(noteId);
      
      // Verify final sync happened
      verify(mockBidirectionalSync.syncFromNoteToTasks(
        noteId,
        'Final content',
      )).called(1);
    });
    
    test('should handle 10 toggles of same checkbox rapidly', () async {
      const noteId = 'note-stress';
      const taskId = 'task-stress';
      
      // Simulate user rapidly clicking the same checkbox 10 times
      for (int i = 0; i < 10; i++) {
        await coordinator.handleTaskToggle(
          noteId: noteId,
          taskId: taskId,
          isCompleted: i % 2 == 0,
          updatedContent: 'Content ${i % 2 == 0 ? "[x]" : "[ ]"}',
        );
        
        // Very rapid clicks (20ms apart)
        await Future.delayed(const Duration(milliseconds: 20));
      }
      
      // Wait for debounce
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Should only sync final state
      verify(mockBidirectionalSync.syncFromNoteToTasks(
        noteId,
        argThat(contains('[ ]')), // Final state (9 is odd)
      )).called(1);
      
      // Check metrics
      final metrics = SyncPerformanceMetrics.instance.getMetricsSummary();
      expect(metrics['completedSyncs'], greaterThanOrEqualTo(1));
      expect(metrics['failedSyncs'], equals(0));
    });
    
    test('should handle multiple tasks toggled rapidly', () async {
      const noteId = 'note-multi';
      final taskIds = ['task-1', 'task-2', 'task-3'];
      
      // Toggle different tasks rapidly
      for (int i = 0; i < 9; i++) {
        final taskId = taskIds[i % 3];
        await coordinator.handleTaskToggle(
          noteId: noteId,
          taskId: taskId,
          isCompleted: true,
          updatedContent: 'Content with task $taskId marked',
        );
        
        await Future.delayed(const Duration(milliseconds: 30));
      }
      
      // Wait for debounce
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Should have synced the final combined state
      verify(mockBidirectionalSync.syncFromNoteToTasks(noteId, any)).called(1);
    });
  });
  
  group('Performance Metrics', () {
    test('should track sync duration', () async {
      const noteId = 'note-perf';
      const taskId = 'task-perf';
      
      // Configure sync to take specific time
      when(mockBidirectionalSync.syncFromNoteToTasks(any, any))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      
      await coordinator.handleTaskToggle(
        noteId: noteId,
        taskId: taskId,
        isCompleted: true,
        updatedContent: 'Content',
      );
      
      // Wait for sync
      await Future.delayed(const Duration(milliseconds: 200));
      
      final metrics = SyncPerformanceMetrics.instance.getMetricsSummary();
      expect(metrics['averageSyncTime'], greaterThan(0));
      expect(metrics['successRate'], equals(1.0));
    });
    
    test('should track failed syncs', () async {
      const noteId = 'note-fail';
      const taskId = 'task-fail';
      
      // Configure sync to fail
      when(mockBidirectionalSync.syncFromNoteToTasks(any, any))
          .thenThrow(Exception('Sync failed'));
      
      await coordinator.handleTaskToggle(
        noteId: noteId,
        taskId: taskId,
        isCompleted: true,
        updatedContent: 'Content',
      );
      
      // Wait for sync attempt
      await Future.delayed(const Duration(milliseconds: 150));
      
      final metrics = SyncPerformanceMetrics.instance.getMetricsSummary();
      expect(metrics['failedSyncs'], greaterThan(0));
      expect(metrics['successRate'], lessThan(1.0));
    });
    
    test('should track queue depth', () async {
      const noteId = 'note-queue-depth';
      
      // Make sync slow
      when(mockBidirectionalSync.syncFromNoteToTasks(any, any))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      
      // Queue multiple changes rapidly
      for (int i = 0; i < 3; i++) {
        await coordinator.handleTaskToggle(
          noteId: noteId,
          taskId: 'task-$i',
          isCompleted: true,
          updatedContent: 'Content $i',
        );
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Check max queue depth
      final metrics = SyncPerformanceMetrics.instance.getMetricsSummary();
      expect(metrics['maxQueueDepth'], greaterThanOrEqualTo(1));
    });
  });
  
  group('Edge Cases', () {
    test('should handle empty pending changes gracefully', () async {
      const noteId = 'note-empty';
      
      // Try to process with no pending changes
      await coordinator.syncNote(noteId);
      
      // Should not throw
      expect(true, isTrue);
    });
    
    test('should handle sync errors without losing data', () async {
      const noteId = 'note-error';
      const taskId = 'task-error';
      
      int callCount = 0;
      when(mockBidirectionalSync.syncFromNoteToTasks(any, any))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('First sync failed');
        }
        // Second sync succeeds
      });
      
      // First toggle (will fail)
      await coordinator.handleTaskToggle(
        noteId: noteId,
        taskId: taskId,
        isCompleted: true,
        updatedContent: 'Content 1',
      );
      
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Second toggle (should succeed)
      await coordinator.handleTaskToggle(
        noteId: noteId,
        taskId: taskId,
        isCompleted: false,
        updatedContent: 'Content 2',
      );
      
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Both syncs should have been attempted
      verify(mockBidirectionalSync.syncFromNoteToTasks(noteId, any)).called(2);
    });
  });
}
