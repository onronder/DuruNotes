import 'dart:async';
import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/ui/enhanced_task_list_screen.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';

/// Service for handling deep links from notifications to specific app content
typedef Reader = T Function<T>(ProviderListenable<T> provider);

class DeepLinkService {
  DeepLinkService(this._ref, {
    required Reader read,
  }) : _read = read;

  final Ref _ref;
  final Reader _read;
  AppLogger get _logger => _ref.read(loggerProvider);

  /// Handle deep link from notification
  Future<void> handleDeepLink({
    required BuildContext context,
    required String payload,
  }) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'task_reminder':
          await _handleTaskReminderLink(context, data);
          break;
        case 'note_reminder':
          await _handleNoteReminderLink(context, data);
          break;
        case 'task':
          await _handleTaskLink(context, data);
          break;
        case 'note':
          await _handleNoteLink(context, data);
          break;
        default:
          _logger.warning('Unknown deep link type: $type');
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to handle deep link',
        error: e,
        stackTrace: stack,
        data: {'payload': payload},
      );
    }
  }

  /// Handle task reminder notification link
  Future<void> _handleTaskReminderLink(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final taskId = data['taskId'] as String?;
    final noteId = data['noteId'] as String?;

    if (taskId != null) {
      await _openTaskDetails(context, taskId, noteId);
    } else if (noteId != null) {
      await _openNote(context, noteId);
    } else {
      // Fallback: open task list
      await _openTaskList(context);
    }
  }

  /// Handle note reminder notification link
  Future<void> _handleNoteReminderLink(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final noteId = data['noteId'] as String?;

    if (noteId != null) {
      await _openNote(context, noteId);
    }
  }

  /// Handle direct task link
  Future<void> _handleTaskLink(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final taskId = data['taskId'] as String?;
    final noteId = data['noteId'] as String?;

    if (taskId != null) {
      await _openTaskDetails(context, taskId, noteId);
    }
  }

  /// Handle direct note link
  Future<void> _handleNoteLink(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final noteId = data['noteId'] as String?;

    if (noteId != null) {
      await _openNote(context, noteId);
    }
  }

  /// Open task details (either in note context or task list)
  Future<void> _openTaskDetails(
    BuildContext context,
    String taskId,
    String? noteId,
  ) async {
    try {
      final db = _read(appDbProvider);
      final task = await db.getTaskById(taskId);

      if (task == null) {
        _showTaskNotFoundMessage(context);
        return;
      }

      if (noteId != null && noteId != 'standalone') {
        // Open in note context
        await _openNoteWithTaskHighlight(context, noteId, taskId);
      } else {
        // Open task list and show task details
        await _openTaskListWithTaskHighlight(context, taskId);
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to open task details',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId, 'noteId': noteId},
      );
      _showErrorMessage(context, 'Could not open task');
    }
  }

  /// Open note editor
  Future<void> _openNote(BuildContext context, String noteId) async {
    try {
      final notesRepo = _read(notesRepositoryProvider);
      final note = await notesRepo.getNote(noteId);

      if (note == null) {
        _showNoteNotFoundMessage(context);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ModernEditNoteScreen(
            noteId: note.id,
            initialTitle: note.title,
            initialBody: note.body,
          ),
        ),
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to open note',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId},
      );
      _showErrorMessage(context, 'Could not open note');
    }
  }

  /// Open note with specific task highlighted
  Future<void> _openNoteWithTaskHighlight(
    BuildContext context,
    String noteId,
    String taskId,
  ) async {
    try {
      final notesRepo = _read(notesRepositoryProvider);
      final note = await notesRepo.getNote(noteId);

      if (note == null) {
        _showNoteNotFoundMessage(context);
        return;
      }

      // Get task details for highlighting
      final db = _read(appDbProvider);
      final task = await db.getTaskById(taskId);

      // Open note with task highlighting
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ModernEditNoteScreen(
            noteId: note.id,
            initialTitle: note.title,
            initialBody: note.body,
            highlightTaskId: taskId,
            highlightTaskContent: task?.content,
          ),
        ),
      );

      // Show a toast indicating which task triggered the notification
      if (task != null) {
        _showTaskHighlightMessage(context, task.content);
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to open note with task highlight',
        error: e,
        stackTrace: stack,
        data: {'noteId': noteId, 'taskId': taskId},
      );
      _showErrorMessage(context, 'Could not open note');
    }
  }

  /// Open task list
  Future<void> _openTaskList(BuildContext context) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => const EnhancedTaskListScreen(),
        ),
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to open task list',
        error: e,
        stackTrace: stack,
      );
      _showErrorMessage(context, 'Could not open task list');
    }
  }

  /// Open task list with specific task highlighted
  Future<void> _openTaskListWithTaskHighlight(
    BuildContext context,
    String taskId,
  ) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => const EnhancedTaskListScreen(),
        ),
      );

      // Show a toast indicating which task triggered the notification
      _showTaskHighlightMessage(context, taskId);
    } catch (e, stack) {
      _logger.error(
        'Failed to open task list with task highlight',
        error: e,
        stackTrace: stack,
        data: {'taskId': taskId},
      );
      _showErrorMessage(context, 'Could not open task list');
    }
  }

  /// Handle task notification actions (complete, snooze, etc.)
  Future<void> handleTaskNotificationAction({
    required String action,
    required String payload,
  }) async {
    try {
      final enhancedTaskService = _read(enhancedTaskServiceProvider);
      await enhancedTaskService.handleTaskNotificationAction(
        action: action,
        payload: payload,
      );

      _logger.info('Handled task notification action', data: {
        'action': action,
        'payload': payload,
      });
    } catch (e, stack) {
      _logger.error(
        'Failed to handle task notification action',
        error: e,
        stackTrace: stack,
        data: {'action': action, 'payload': payload},
      );
    }
  }

  /// Show task not found message
  void _showTaskNotFoundMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task not found or has been deleted'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// Show note not found message
  void _showNoteNotFoundMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note not found or has been deleted'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// Show task highlight message
  void _showTaskHighlightMessage(BuildContext context, String taskContent) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.task_alt, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Task: $taskContent',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show generic error message
  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Create deep link URL for task
  String createTaskDeepLink(String taskId, {String? noteId}) {
    final data = {
      'type': 'task',
      'taskId': taskId,
      if (noteId != null) 'noteId': noteId,
    };
    return 'durunotes://task?data=${Uri.encodeComponent(jsonEncode(data))}';
  }

  /// Create deep link URL for note
  String createNoteDeepLink(String noteId) {
    final data = {
      'type': 'note',
      'noteId': noteId,
    };
    return 'durunotes://note?data=${Uri.encodeComponent(jsonEncode(data))}';
  }

  /// Create deep link URL for task reminder
  String createTaskReminderDeepLink(String taskId, String noteId) {
    final data = {
      'type': 'task_reminder',
      'taskId': taskId,
      'noteId': noteId,
    };
    return 'durunotes://reminder?data=${Uri.encodeComponent(jsonEncode(data))}';
  }
}
