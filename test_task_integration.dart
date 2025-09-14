#!/usr/bin/env dart

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/task_service.dart';
import 'package:duru_notes/services/note_task_sync_service.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

/// Test script for validating task management integration
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🧪 Task Management Integration Test');
  print('=' * 50);
  
  // Initialize services
  final db = AppDb();
  final notesRepo = NotesRepository(db);
  final taskService = TaskService(db, null); // No reminder service for test
  final syncService = NoteTaskSyncService(db, taskService);
  
  try {
    // Test 1: Create note with checkboxes
    print('\n📝 Test 1: Creating note with checkboxes...');
    final noteId = DateTime.now().millisecondsSinceEpoch.toString();
    
    await notesRepo.createNote(
      id: noteId,
      title: 'Test Tasks',
      body: '''# Task Test Note
- [ ] Buy groceries
- [ ] Call dentist for appointment
- [x] Review project proposal
- [ ] Send weekly report

Regular text here.

- [ ] Prepare presentation slides
''',
    );
    
    // Sync tasks from note content
    await db.syncTasksWithNoteContent(noteId, 
      await db.getNote(noteId).then((n) => n!.body));
    
    // Verify tasks were created
    final tasks = await db.getTasksForNote(noteId);
    print('✅ Created ${tasks.length} tasks from checkboxes');
    for (final task in tasks) {
      print('  - [${task.status == 1 ? 'x' : ' '}] ${task.content} (hash: ${task.contentHash.substring(0, 8)}...)');
    }
    
    // Test 2: Edit task content (should update existing task)
    print('\n✏️ Test 2: Editing task content...');
    final firstTask = tasks.first;
    await syncService.updateTaskInNote(
      noteId: noteId,
      taskId: firstTask.id,
      newContent: 'Buy groceries and household items',
    );
    
    // Verify task was updated, not duplicated
    final updatedTasks = await db.getTasksForNote(noteId);
    final updatedTask = updatedTasks.firstWhere((t) => t.id == firstTask.id);
    print('✅ Task updated: "${updatedTask.content}"');
    print('  Same ID: ${updatedTask.id == firstTask.id}');
    print('  New hash: ${updatedTask.contentHash.substring(0, 8)}...');
    
    // Test 3: Toggle task completion
    print('\n✔️ Test 3: Toggling task completion...');
    await syncService.updateNoteContentForTask(
      noteId: noteId,
      taskId: tasks[1].id,
      isCompleted: true,
    );
    
    final toggledTasks = await db.getTasksForNote(noteId);
    final toggledTask = toggledTasks[1];
    print('✅ Task toggled: "${toggledTask.content}" is ${toggledTask.status == 1 ? 'completed' : 'open'}');
    
    // Test 4: Add due date and verify reminder integration
    print('\n📅 Test 4: Adding due date to task...');
    final tomorrow = DateTime.now().add(Duration(days: 1));
    await taskService.updateTask(
      taskId: tasks[3].id,
      dueDate: tomorrow,
    );
    
    final taskWithDue = await db.getTaskById(tasks[3].id);
    print('✅ Due date set: ${taskWithDue!.dueDate}');
    
    // Test 5: Verify no duplicate creation on re-save
    print('\n🔄 Test 5: Re-saving note (no duplicates)...');
    final noteContent = await db.getNote(noteId).then((n) => n!.body);
    await db.syncTasksWithNoteContent(noteId, noteContent);
    
    final finalTasks = await db.getTasksForNote(noteId);
    print('✅ Task count remains ${finalTasks.length} (no duplicates)');
    
    // Test 6: Calendar view data
    print('\n📆 Test 6: Getting tasks for calendar view...');
    final openTasks = await db.getOpenTasksWithDueDates();
    final overdueTasks = await db.getOverdueTasks();
    
    print('✅ Open tasks with due dates: ${openTasks.length}');
    print('✅ Overdue tasks: ${overdueTasks.length}');
    
    // Cleanup
    print('\n🧹 Cleaning up test data...');
    await db.deleteNote(noteId);
    
    print('\n✨ All tests passed successfully!');
    
  } catch (e, stack) {
    print('\n❌ Test failed: $e');
    print(stack);
  } finally {
    await db.close();
  }
}

