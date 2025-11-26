import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:duru_notes/data/local/app_db.dart';

/// Migration 41: Convert NoteReminders.id from INTEGER to TEXT (UUID)
///
/// This migration addresses a critical schema mismatch between local (INT) and remote (UUID).
/// It converts all existing reminder IDs to UUIDs and updates foreign key references.
///
/// Changes:
/// 1. NoteReminders.id: INTEGER AUTO INCREMENT → TEXT (UUID)
/// 2. NoteTasks.reminder_id: INTEGER → TEXT (UUID)
/// 3. Migrates all existing data
/// 4. Updates foreign key references
/// 5. Recreates indexes
class Migration41ReminderUuid {
  static const _uuid = Uuid();

  static Future<void> apply(AppDb db) async {
    debugPrint('[Migration 41] Starting reminder UUID migration...');

    // Step 1: Create new table with UUID IDs
    await db.customStatement('''
      CREATE TABLE note_reminders_new (
        id TEXT PRIMARY KEY NOT NULL,
        note_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        body TEXT NOT NULL DEFAULT '',
        type INTEGER NOT NULL,
        remind_at INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        latitude REAL,
        longitude REAL,
        radius REAL,
        location_name TEXT,
        recurrence_pattern INTEGER NOT NULL DEFAULT 0,
        recurrence_interval INTEGER NOT NULL DEFAULT 1,
        recurrence_end_date INTEGER,
        snoozed_until INTEGER,
        snooze_count INTEGER NOT NULL DEFAULT 0,
        notification_title TEXT,
        notification_body TEXT,
        notification_image TEXT,
        time_zone TEXT,
        created_at INTEGER NOT NULL,
        last_triggered INTEGER,
        trigger_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Step 2: Migrate existing reminder data with UUID generation
    final reminders = await db
        .customSelect('SELECT * FROM note_reminders')
        .get();
    debugPrint('[Migration 41] Migrating ${reminders.length} reminders...');

    final uuidMap = <int, String>{}; // Maps old INT ID → new UUID

    for (final reminder in reminders) {
      final oldId = reminder.read<int>('id');
      final newId = _uuid.v4();
      uuidMap[oldId] = newId;

      await db.customStatement(
        '''
        INSERT INTO note_reminders_new (
          id, note_id, user_id, title, body, type, remind_at, is_active,
          latitude, longitude, radius, location_name, recurrence_pattern,
          recurrence_interval, recurrence_end_date, snoozed_until, snooze_count,
          notification_title, notification_body, notification_image, time_zone,
          created_at, last_triggered, trigger_count
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          newId,
          reminder.read<String>('note_id'),
          reminder.read<String>('user_id'),
          reminder.read<String>('title'),
          reminder.read<String>('body'),
          reminder.read<int>('type'),
          reminder.readNullable<int>('remind_at'),
          reminder.read<int>('is_active'),
          reminder.readNullable<double>('latitude'),
          reminder.readNullable<double>('longitude'),
          reminder.readNullable<double>('radius'),
          reminder.readNullable<String>('location_name'),
          reminder.read<int>('recurrence_pattern'),
          reminder.read<int>('recurrence_interval'),
          reminder.readNullable<int>('recurrence_end_date'),
          reminder.readNullable<int>('snoozed_until'),
          reminder.read<int>('snooze_count'),
          reminder.readNullable<String>('notification_title'),
          reminder.readNullable<String>('notification_body'),
          reminder.readNullable<String>('notification_image'),
          reminder.readNullable<String>('time_zone'),
          reminder.read<int>('created_at'),
          reminder.readNullable<int>('last_triggered'),
          reminder.read<int>('trigger_count'),
        ],
      );
    }

    debugPrint(
      '[Migration 41] Generated UUIDs for ${uuidMap.length} reminders',
    );

    // Step 3: Update NoteTasks foreign key references
    // First, create new note_tasks table with TEXT reminder_id
    await db.customStatement('''
      CREATE TABLE note_tasks_new (
        id TEXT PRIMARY KEY NOT NULL,
        note_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        content_encrypted TEXT NOT NULL,
        labels_encrypted TEXT,
        notes_encrypted TEXT,
        encryption_version INTEGER NOT NULL DEFAULT 1,
        status INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 1,
        due_date INTEGER,
        completed_at INTEGER,
        completed_by TEXT,
        position INTEGER NOT NULL DEFAULT 0,
        content_hash TEXT NOT NULL,
        reminder_id TEXT,
        estimated_minutes INTEGER,
        actual_minutes INTEGER,
        parent_task_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        deleted_by TEXT
      )
    ''');

    // Migrate task data, updating reminder_id references
    final tasks = await db.customSelect('SELECT * FROM note_tasks').get();
    debugPrint(
      '[Migration 41] Updating ${tasks.length} task reminder references...',
    );

    int updatedTaskCount = 0;
    int orphanedTaskCount = 0;

    for (final task in tasks) {
      final oldReminderId = task.readNullable<int>('reminder_id');
      String? newReminderId;

      if (oldReminderId != null) {
        newReminderId = uuidMap[oldReminderId];
        if (newReminderId != null) {
          updatedTaskCount++;
        } else {
          // Orphaned reminder reference - will be set to null
          orphanedTaskCount++;
          debugPrint(
            '[Migration 41] WARNING: Task ${task.read<String>('id')} had invalid reminder_id=$oldReminderId',
          );
        }
      }

      await db.customStatement(
        '''
        INSERT INTO note_tasks_new (
          id, note_id, user_id, content_encrypted, labels_encrypted, notes_encrypted,
          encryption_version, status, priority, due_date, completed_at, completed_by,
          position, content_hash, reminder_id, estimated_minutes, actual_minutes,
          parent_task_id, created_at, updated_at, deleted_at, deleted_by
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          task.read<String>('id'),
          task.read<String>('note_id'),
          task.read<String>('user_id'),
          task.read<String>('content_encrypted'),
          task.readNullable<String>('labels_encrypted'),
          task.readNullable<String>('notes_encrypted'),
          task.read<int>('encryption_version'),
          task.read<int>('status'),
          task.read<int>('priority'),
          task.readNullable<int>('due_date'),
          task.readNullable<int>('completed_at'),
          task.readNullable<String>('completed_by'),
          task.read<int>('position'),
          task.read<String>('content_hash'),
          newReminderId, // Updated UUID or null
          task.readNullable<int>('estimated_minutes'),
          task.readNullable<int>('actual_minutes'),
          task.readNullable<String>('parent_task_id'),
          task.read<int>('created_at'),
          task.read<int>('updated_at'),
          task.readNullable<int>('deleted_at'),
          task.readNullable<String>('deleted_by'),
        ],
      );
    }

    debugPrint(
      '[Migration 41] Updated $updatedTaskCount task references, found $orphanedTaskCount orphaned references',
    );

    // Step 4: Drop old tables and rename new ones
    await db.customStatement('DROP TABLE note_reminders');
    await db.customStatement(
      'ALTER TABLE note_reminders_new RENAME TO note_reminders',
    );

    await db.customStatement('DROP TABLE note_tasks');
    await db.customStatement('ALTER TABLE note_tasks_new RENAME TO note_tasks');

    // Step 5: Recreate indexes
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_note_user ON note_reminders(note_id, user_id)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_active ON note_reminders(user_id, is_active)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_reminders_remind_at ON note_reminders(remind_at) WHERE is_active = 1',
    );

    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tasks_note ON note_tasks(note_id)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tasks_user ON note_tasks(user_id)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tasks_status ON note_tasks(status)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tasks_due_date ON note_tasks(due_date) WHERE due_date IS NOT NULL',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_note_tasks_position ON note_tasks(position)',
    );

    // Step 6: Clean up pending_ops for reminders (old IDs invalid, will re-sync)
    await db.customStatement(
      "DELETE FROM pending_ops WHERE kind = 'upsert_reminder' OR kind = 'delete_reminder'",
    );

    // Enqueue all reminders for fresh upload with new UUIDs
    for (final entry in uuidMap.entries) {
      await db.customStatement(
        '''
        INSERT INTO pending_ops (user_id, entity_id, kind, payload, created_at)
        SELECT user_id, ?, 'upsert_reminder', '{}', ?
        FROM note_reminders
        WHERE id = ?
        ''',
        [
          entry.value,
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          entry.value,
        ],
      );
    }

    debugPrint('[Migration 41] ✅ Reminder UUID migration complete');
    debugPrint(
      '[Migration 41] Summary: ${reminders.length} reminders migrated, $updatedTaskCount task references updated',
    );
  }
}
