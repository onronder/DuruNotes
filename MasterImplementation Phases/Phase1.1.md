---
**Document**: Phase 1.1 - Soft Delete & Trash System Implementation Plan
**Version**: 1.3.0
**Created**: 2025-11-02
**Last Updated**: 2025-11-17T14:45:00Z
**Previous Version**: 1.2.0 (2025-11-16)
**Author**: Claude Code AI Assistant
**Git Commit**: eacd756f
**Status**: ✅ **COMPLETE + TESTED** (Service layer bypass fix in progress - Phases 2-4)
**Related Documents**:
  - MASTER_IMPLEMENTATION_PLAN.md v2.2.0
  - ARCHITECTURE_VIOLATIONS.md v1.1.0
  - AUDIT_LOG.md v1.1.0
  - test/architecture/repository_pattern_test.dart (NEW - automated detection)
  - test/services/enhanced_task_service_isolation_test.dart (UPDATED - comprehensive coverage)

**CHANGELOG**:
- 1.3.0 (2025-11-17): Phase 1 test coverage complete
  - Created architecture enforcement test (repository_pattern_test.dart)
  - Expanded service test coverage (11 new tests, 12/13 passing)
  - Bug validated: deleteTask test FAILS (confirms hard delete instead of soft delete)
  - Ready for Phase 2-4 implementation (fix service layer bypass)
- 1.2.0 (2025-11-16): Updated to reflect actual implementation status. Soft-delete timestamps, TrashScreen, and purge automation are complete. Only service layer bypass remains.
- 1.1.0 (2025-11-05): Added audit comment noting boolean-only implementation
- 1.0 (2025-11-02): Original implementation plan

---

# Phase 1.1: Soft Delete & Trash System Implementation Plan

## ✅ Implementation Status (Updated 2025-11-16)

**COMPLETED**: This phase is ✅ **fully implemented** with one remaining issue:

✅ **Completed Features**:
- Soft delete timestamps (`deleted_at`, `scheduled_purge_at`) - migration_40
- TrashScreen UI with restore/delete actions - lib/ui/trash_screen.dart
- Repository layer soft delete - all repositories use timestamp-based soft delete
- Purge automation - purge_scheduler_service.dart with 30-day retention
- Supabase migrations aligned with local schema

⚠️ **Remaining Issue**: Service layer bypass (FIX IN PROGRESS - Phases 2-4)
- **File**: lib/services/enhanced_task_service.dart:305
- **Problem**: Bypasses repository pattern, calls AppDb.deleteTaskById() directly (hard delete)
- **Impact**: Tasks deleted via this service skip trash system
- **Test Coverage**: ✅ Phase 1 Complete (commit 359f30d1)
  - Architecture test detects violations automatically
  - Service test proves bug exists (deleteTask test FAILS)
  - 23 violations detected: 18 in EnhancedTaskService, 5 in TaskReminderBridge
- **Fix Plan**: See ARCHITECTURE_VIOLATIONS.md v1.1.0, AUDIT_LOG.md v1.1.0
  - Phase 2: Fix read operations (14 violations)
  - Phase 3: Fix update operations (5 violations)
  - Phase 4: Fix delete operation (1 CRITICAL violation)

---

## Overview of Soft Delete & Trash System

Soft Delete allows us to mark notes (and related entities) as deleted without permanently removing data. Instead of immediately purging records from the database, we set timestamps (`deleted_at`, `scheduled_purge_at`) indicating the item is in "Trash." This gives users the ability to recover accidentally deleted notes and satisfies data retention policies until permanent deletion occurs (addressed in Phase 1.3, Purge Automation). The Trash system provides a user-visible area where all soft-deleted items reside. The implementation spans the entire stack: database schema, data access layer, synchronization logic, and UI.

**✅ Implementation completed in migration_40** - This plan document remains for reference and to guide the service layer bypass fix.

Database Schema and Migrations (Local & Remote)

Our schema already includes a boolean deleted flag in core tables: notes, folders, and note_tasks (tasks) have a deleted BOOLEAN DEFAULT false column both in the cloud (Supabase) and local SQLite (Drift)
GitHub
GitHub
. This means the structural support for soft deletion is largely in place. Key steps for the database layer:

Verify Schema: Confirm that the deleted field exists on all relevant tables:

Remote Postgres (Supabase): public.notes.deleted, public.folders.deleted, public.note_tasks.deleted – all default to false
GitHub
GitHub
.

Local Drift DB: LocalNotes.deleted, LocalFolders.deleted, NoteTasks.deleted – all default to false in the schema
GitHub
GitHub
.

Add Indexes (if not present): Ensure efficient queries by indexing the deleted flag. Supabase schema already defines an index on (user_id, deleted) for notes (and similarly for tasks if needed)
GitHub
. If Drift doesn’t have equivalent indexes, consider adding them in a migration for local queries performance.

Migration Alignment: If any deleted column is missing or was added in a newer schema version, create migration scripts:

Local DB: Bump the Drift database version and add the deleted columns with default false. Write a Drift migration that uses m.addColumn() for each new column, and backfill default values (existing rows should be marked as not deleted).

Remote DB: If the production Supabase lacks a deleted field on any table, write a SQL migration (in supabase/migrations/) to alter the table and add deleted BOOLEAN NOT NULL DEFAULT false with an index on it. Also update any RLS policies if needed (though typically the existing RLS user_id = auth.uid() suffices).

Both migrations should be applied in tandem to keep local and remote schemas in sync
GitHub
. Document these changes and update the schema blueprint and runbook accordingly to avoid future drift
GitHub
.

Data Integrity: Verify that adding these columns or toggling their values does not violate constraints. For example, deleted is a simple flag, so no foreign-key issues are introduced. We should ensure that no logic (like triggers) on the DB tries to cascade deletes – since we now soft-delete, we likely disable or avoid using ON DELETE CASCADE in this context (the schema uses it only for actual user or folder deletion relationships
GitHub
GitHub
).

Default Values: All new deleted flags should default to false for new entries. Confirm that any existing rows (if migrating an existing user base) are treated as false by default (migration will set default and backfill). This ensures nothing suddenly appears “deleted” after deployment.

By ensuring the schema is prepared, we lay the groundwork for implementing soft deletion logic without leaving holes. The alignment between local and remote DB is critical – both schemas must mirror each other
GitHub
 to prevent sync issues or data type mismatches.

Data Model & Repository Layer Updates

With the schema ready, we update the data models and repository methods to use the soft-delete flag:

Local Models: Update domain models or mappers so that the deleted property is loaded from the DB and accessible in code. For instance, ensure LocalNote, LocalFolder, and NoteTask models include a bool deleted field. (From the codebase, it appears LocalNote.deleted, LocalFolder.deleted, etc. already exist given our schema definitions
GitHub
GitHub
, but verify that domain layer (e.g., Note entity or any converters) carries this flag as well.)

Repository Methods (CRUD): Modify all create/read/update/delete methods in notes, folders, and tasks repositories:

Create/Update: When creating or updating items, typically deleted remains false. Just ensure these operations do not inadvertently reset the flag. If an update operation should never resurrect a deleted note unless explicitly intended, we might enforce that it doesn’t implicitly set deleted=false unless it’s a restore action.

Delete Note: Instead of permanently removing a note’s record, implement it as a soft delete. For example, in NotesRepository.deleteNote() (or equivalent), perform an update on the note setting deleted = true and update the timestamps. In the local DB, that means using a Drift update query to set the flag. In the remote, we will sync this via the Supabase API (covered in Sync section below). If the code previously had a direct deletion (like a delete SQL or removing from Drift), replace that with flagging. Also mark any in-memory state as deleted if necessary (or simply reload from DB with filters).

Delete Folder: Similarly, update FolderRepository.deleteFolder() to soft-delete the folder. This likely means setting the folder’s deleted flag to true. Important: Decide how to handle notes inside that folder. Options:

Easiest approach is to also soft-delete all notes within the folder (cascading delete to trash). This aligns with user expectations that deleting a folder sends its contents to Trash as well. To do this, find all notes in that folder (e.g., query local Note-Folder relation for that folder’s notes) and set each note’s deleted = true. This can be done at the repository/service layer in a loop. We should also propagate those deletions to remote. This approach keeps notes hidden from all normal views (since they’ll be marked deleted). If the user restores the folder later, we’d need to restore its notes too (we’ll handle restore logic separately).

Alternatively, one might orphan the notes (remove their folder association) so they appear in a general list. However, that could confuse users, and given we have a Trash system, the cascade-to-trash is cleaner. We will implement the cascade soft-delete for folder contents, but also ensure this is done in a single transaction locally to avoid partial state if the app crashes mid-way.

Delete Task: For tasks (to-do items) tied to notes, apply soft deletion as well. If a user deletes a checklist item (task) from a note, mark it as deleted=true in the NoteTasks table rather than removing it. The repository method deleteTask() should update the row’s flag. Because tasks are usually displayed within a note, we might not expose “Trash” for individual tasks in the UI. But marking them ensures consistency and that the deletion syncs across devices (and we could potentially allow undo in the future). If a whole note is deleted, tasks within it can either be left as-is (since the note being deleted will hide them anyway) or also marked deleted for completeness. It’s reasonable to mark them too, especially to avoid them showing up in any “all tasks” views or search results. This can be done in a similar cascade when a note is trashed.

Other Entities: Check if other entities should have soft-delete (e.g., attachments, templates):

Attachments: The attachments table (if implemented for file attachments) does not currently have a deleted field in the schema we saw. If attachments exist and a note is deleted, we need to prevent orphaned files. In Phase 1.1, we can choose to immediately hard-delete attachments when a note is trashed (to free storage), or mark them in metadata and remove on purge. Since attachments might contain user data, better to treat them like note content: perhaps remove them only upon permanent deletion to allow restoration if note is restored. Because we lack a deleted flag for attachments, one strategy is to delete the file data but keep a record, or add a deleted column in a future migration. For now, we can document this and possibly include attachment cleanup in Phase 1.3 purge.

Tags / Note relationships: Tags (note_tags table) and note-folder relations likely can remain intact for now. A note in trash can keep its tag links and folder ID for restoration. These linked records don’t show up in UI because the note itself is filtered out. We should, however, ensure that any queries for tags or folders exclude notes that are deleted. For example, if counting notes per tag or listing notes in a folder, filter out deleted ones. This is something to audit in repository queries.

Query Filtering: All read operations that fetch active notes/tasks/folders must exclude deleted items by default. This is crucial so that trashed items do not appear in normal lists, searches, or counts:

e.g. NotesRepository.getAllNotes() or folder listing queries should include a condition like WHERE deleted = false
GitHub
. In Drift, that means adding .where((note) => note.deleted.equals(false)) to the query builder. In SQL or Supabase queries, add deleted = false in the WHERE clause or use the query builder’s .eq('deleted', false) (as we see in fetchAllActiveIds() in the Supabase API code
GitHub
).

Ensure this filtering is added to all relevant methods: listing notes, getting notes by folder, searching notes, retrieving tasks, etc. This may involve auditing each repository function. (The security roadmap already planned to add userId filters; we should simultaneously make sure deleted filters are present where appropriate to avoid showing items that should be trashed.)

Edge case: If we have any logic for “get note by ID” (for opening a note detail), we might allow fetching even if it’s deleted (for example, if the user tries to open a note from trash or via a direct link). But by default UI won’t offer that outside trash. It’s okay for repository to still retrieve it (maybe with a specific flag or method) but standard flows should not include deleted items.

Repository Restore Method: It’s wise to add a method for restoring a soft-deleted item (notes or folders). This would simply set deleted = false on that item (and potentially on related child items). For now, we can plan to use the same upsert logic (in reverse) to “undelete.” Even if UI for restore is minimal in this phase, having the function ready and tested will simplify hooking it up when needed.

By updating the repository layer thoroughly, we enforce the soft delete invariants application-wide. This prevents any accidental hard deletions and ensures any part of the app that reads data respects the Trash state. We also reduce technical debt by handling all these cases now, rather than discovering later that “deleted” items are leaking into views.

Sync & Supabase Integration

Since Duru Notes uses a cloud sync (Supabase) plus local storage, our soft delete actions must propagate to and from the server properly:

Upsert vs. Delete API: In the Supabase remote API, instead of calling a delete RPC or REST endpoint, we will use an upsert with the deleted flag. From the code, we have SupabaseNoteApi.upsertEncryptedNote and upsertEncryptedFolder which already accept a deleted parameter
GitHub
GitHub
. We should leverage these:

When a user deletes a note, the app should call upsertEncryptedNote(id: noteId, ..., deleted: true) – this updates or inserts the note row on Supabase with deleted=true (and a new updated_at). The server’s RLS ensures the user owns it, and any other devices will get this update on next sync.

Similarly, deleting a folder should call upsertEncryptedFolder(id: folderId, ..., deleted: true)
GitHub
.

Batch updates: If we are trashing multiple notes at once (e.g. a folder with many notes), we may call upsert for each note. This could be slow if done individually. If the API or supabase Dart library allows batch upserts, that would be ideal; otherwise, ensure to queue them properly in our sync queue (so they all get sent).

Receiving Deletions: Update the sync logic that pulls down remote changes (e.g. something like fetchEncryptedNotes in SupabaseNoteApi). This should already fetch the deleted field for notes and folders
GitHub
GitHub
. We must ensure that when processing incoming data:

If a note comes in with deleted=true, our sync service should mark the corresponding local note as deleted (or remove it from local if we prefer). Likely we will do the same upsert on the local side: if the note exists, update its deleted flag and save. If the note is not found locally (e.g., was created and deleted on another device while this one was offline), we might insert it in local DB just to keep a record (with deleted flag) or skip creating it? It might be simpler to still insert it (so that if later we implement a 30-day purge, the local device knows of it for consistency).

If a note was restored on another device (deleted went from true back to false), treat that as just a normal update – sync will set deleted=false on local, making it visible again.

If the remote returns an item with deleted=false that we have locally marked deleted (possible conflict scenario: e.g., user deletes note on Device A (no connectivity), but edits the same note on Device B), our sync conflict resolution should decide which state wins. Generally, last updated timestamp should resolve it. Since marking deleted also updates updated_at, whichever operation happened last will have later updated_at. We should implement accordingly: if a “deleted” record has a newer timestamp than a modification, we accept the deletion (thus discarding the other edit in effect, perhaps with a merge strategy or warning).

Ensure that the PendingOps or sync queue logic recognizes “delete” ops differently. For example, if our PendingOps table currently has entries like kind = 'delete_note', we may not actually call a delete API but rather convert that pending op to an upsert (deleted:true). We might refine the sync logic to unify create/update/delete under a single upsert mechanism: i.e., treat a delete op as just an update with flag. This way, we don’t need separate handling in offline queue aside from marking the type (maybe for logging).

Supabase Policies: Because we are not truly deleting rows, they remain in the user’s table. Our RLS policies (notes_owner, etc.) already restrict access by user_id
GitHub
, so no other user can see them. We should double-check that having many “deleted” rows doesn’t affect any security concerns. It should not, as they are still tied to the user.

Storage & Backups: Soft deletes mean data accumulates until purged. For Phase 1.1, that’s acceptable (short term). We might want to monitor if a huge number of deleted items could slow sync. However, our fetch queries can fetch only deleted=false for normal sync (like fetchAllActiveIds() filters to active notes only
GitHub
). If we implement a way to retrieve trashed items on demand (like when user opens Trash view, we might fetch deleted=true items), we can use a separate query or parameter for that.

Consistency Checks: Implement any needed checks to ensure consistency:

For example, if a note is marked deleted and a user creates a new note with the same title or moves a note with a conflicting ID, etc., ensure no issues. Typically, primary keys prevent duplicate IDs; we reuse the same note record for soft delete, so no duplicates arise.

If the user permanently deletes something on one device (when we add that feature), ensure the other devices handle the actual deletion (e.g., maybe the item disappears from both local DB and Supabase). That’s Phase 1.3’s concern, but keep in mind for how we design the sync: possibly a separate “hard delete” operation might simply be represented as a soft delete followed by a purge event.

Testing Sync: After implementation, test scenarios:

Delete a note on Device A, sync Device B -> Note should disappear from Device B’s main list and appear in Device B’s Trash.

Restore a note on Device B, sync Device A -> Note reappears in main list on A.

Delete a folder with notes on one device -> on second device, folder and its notes should all be marked deleted.

Ensure no duplicate note entries are created in local DB on these syncs (the upsert by primary key should just update).

Verify that creating a new note (with a new UUID) that happens to match an old deleted note’s title doesn’t resurrect anything weird (shouldn’t, since ID differs).

By handling sync carefully, we avoid data divergence or user confusion across devices. The soft delete system will then function seamlessly in an online/offline scenario.

Frontend/UI Changes – Trash Management

To expose this feature to users, we need to update the UI with a Trash section and appropriate actions:

Trash as a Special Folder/View: Introduce a “Trash” entry in the app’s navigation (likely alongside folders). It appears the app already accounts for special folder types like Trash in the UI (e.g., seeing specialType: 'trash' with a trash icon in folder UI code)
GitHub
. If not already, create a special folder or menu item labeled "Trash":

This could be implemented by treating Trash as a virtual folder that, when selected, displays all items where deleted=true. We don’t necessarily have a physical “Trash” folder row in the database (and we might not want one, since we have a flag). Instead, the app can recognize folder.specialType == 'trash' and load items accordingly.

If we do choose to represent Trash as an actual folder row (some apps do this to allow moving notes in/out by changing folder), we could create a reserved folder with e.g. name="Trash" and a flag in its metadata marking it special. But given we have a dedicated flag on each note, a virtual approach is simpler: we can filter notes by deleted=true for the Trash view, ignoring their folder associations.

Implementation: In the folder list widget, ensure there is a Trash item (perhaps added by the app if not in DB). Mark it with isSpecial=true, specialType='trash' to get the trash icon
GitHub
. Selecting it should trigger a view state where we query notes with deleted flag instead of normal folder notes. The folder id filter can be ignored in this case, using a separate repository call like getDeletedNotes().

Listing Trashed Items: Create UI to list trashed items. Likely similar to the note list UI, but:

Possibly show notes from all folders combined (since they’re deleted, their original hierarchy is less important). We could group by their original folder name for context, but that’s a nice-to-have.

Show maybe a subtitle or badge “Trash” or an indicator that these are deleted. Could use a slightly grayed-out style or a trash icon next to each.

If including other item types: We mainly expect notes (and possibly folders) to appear. If a folder was deleted, we might either show it in the Trash list as a folder entry (and allow restoring or deleting it). This could be done by listing deleted folders too. Alternatively, we might not list folders separately in Trash; instead, if a folder is deleted, all its notes are in Trash and restoring them might effectively restore the folder (especially if we keep folder metadata).

For simplicity, we can list both deleted notes and folders in one Trash view. But mixing might confuse users. Another approach: the Trash “folder” could have two tabs or sections: “Notes” and “Folders.” Or just list everything chronologically by deletion date (if we track that).

Deletion timestamp: We currently have only a boolean flag and an updated_at. We can infer deletion time from updated_at of a trashed item (since we set updated_at when flagging it). To display “Deleted on X date” or to purge after 30 days, this is fine. If needed, we might later add a dedicated deleted_at field for clarity, but it’s not strictly necessary now.

User Actions in Trash: Provide controls to manage trashed items:

Restore: Allow users to select a deleted note or folder and “Restore” it. Restoring a note means simply flipping its deleted flag back to false (and updating updated_at). In the UI, this could be a button or swipe action labeled “Restore.” When tapped:

If restoring a note: we should also consider if its folder was deleted. If the note’s parent folder is still existing (not deleted), we can restore just the note and put it back. If the parent folder was also deleted, we have a couple options:

Restore the note without its folder (place it in an appropriate default location, e.g., the root or Inbox, and inform the user the original folder no longer exists), or

Prompt the user to restore the parent folder as well (or automatically do so). The latter might be more intuitive if the folder was in Trash too – maybe the user should restore the folder first, but we can streamline by checking and asking.

If restoring a folder: we should restore all notes that were in it (if we trashed them originally). This can be done behind the scenes: iterate through notes with that folderId and set deleted=false. Alternatively, prompt user or mention that contents will be restored. We should ensure the folder’s parent hierarchy (if any parent folder) is not deleted; if it is, that parent might also need restoration (this gets into multi-level restoration – perhaps for Phase 2 if we implement nested folders).

Execution: the restore action will call repository method to update local DB and add a sync op (which will upsert to Supabase with deleted=false). Upon success, update UI (remove from trash list, show in normal list).

Permanent Delete: Eventually we need the ability to permanently remove items from Trash (either one by one or empty all). While automatic purge is slated for Phase 1.3, we should also consider a manual “Delete Forever” option for users who don’t want to wait or have sensitive data. In Phase 1.1, we can implement the groundwork:

At minimum, design the UI for it (e.g., a trash can icon labeled “Delete Forever” on each item, and a bulk “Empty Trash” action).

If we decide to implement it now: the action would permanently remove the note/folder from both local and remote DB. This involves deleting the row from Drift and calling Supabase to delete the row from Postgres (or perhaps setting a flag and then a server function purges it – but direct deletion is straightforward since user owns the row). We must be careful: once deleted, the data is irrecoverable (barring backups), so confirm with the user via a dialog “This will permanently delete the item(s). Are you sure?”.

If we postpone actual deletion to Phase 1.3, we might omit exposing this in UI now. Alternatively, implement Empty Trash which simply triggers the same purge logic early. Given Phase 1.3 is only a few weeks later, it might be acceptable to only allow restore and rely on auto-purge, to reduce complexity now. We will opt to implement restore now and schedule permanent delete for Phase 1.3, ensuring no data loss until we’ve tested that thoroughly.

Visual feedback: When a user deletes a note or folder (sends to Trash), provide confirmation like a Snackbar: “Note moved to Trash. [Undo]”. The Undo action could simply call restore internally if within a short timeframe. Implementing Undo is optional but enhances UX and is easy since we have soft delete (just flip flag back). This is a low-cost addition that does not add technical debt and can be considered.

Badge/Count: Optionally, show a count of items in Trash (e.g., “Trash (5)”) in the UI to remind users. This could be as simple as counting notes where deleted=true for the current user. Since this is not critical and could be done with a quick query, we can add if time permits.

Deleting from other contexts: Ensure any place that allows deletion uses the new mechanism:

For example, if there’s a note detail screen with a “Delete” option, or multi-select delete in note list, or swiping a note to delete – all these should call the updated soft-delete logic.

If there’s a UI to delete a task (like a context menu on a checklist item), ensure it triggers the soft-delete for the task (or at least removes it from UI while marking the DB).

If templates or other objects can be deleted by user, consider if they should go to Trash or be permanently removed. Possibly user-created templates could also be trashed with a flag (though our template table didn’t have deleted). For consistency, maybe treat them separately for now (since templates might not be as critical to restore). We’ll focus Trash on core content (notes, folders, tasks).

Error Handling & Empty States: In the Trash view, handle the case of no items (show “No items in Trash” message). Also handle failure cases – e.g., if a restore fails to sync (network issues), we might keep the item in Trash and show an error to user. The app’s sync queue will likely retry the op. We should ensure the UI reflects the eventual state (perhaps optimistic update with fallback if sync fails).

Localization/UI text: Add appropriate labels for “Move to Trash”, “Restore from Trash”, “Empty Trash” etc., and ensure they are translated properly (since the repo has localization files).

By updating the UI, we complete the loop for the user: they can delete items (which go to Trash), view them in Trash, and restore if needed. This significantly improves user trust (they won’t fear losing data by accident) and lays the foundation for compliance features (like showing what will be deleted permanently).

Cascading Effects & Consistency Considerations

To implement this without incurring future debt, we must consider how soft delete interacts with all related data and future requirements:

Cascading Deletes vs. Orphans: As mentioned, when deleting complex structures (folders with notes, notes with tasks, etc.), our approach is to cascade the soft delete to contained items. This ensures consistency – e.g., you won’t have a note that is not marked deleted while its parent folder is deleted (which would make it effectively invisible but still “active” in the DB). Our implementation will:

Mark notes as deleted when their containing folder is deleted. Possibly mark tasks as deleted when their parent note is deleted.

Alternatively (or additionally), when loading notes in normal views, we can join with folder table to ensure we also hide notes whose folder is deleted (even if note’s own flag wasn’t set). But doing the cascade at deletion time is cleaner and easier to maintain. It also simplifies restore, because if the user restores the folder, we know to restore all notes (since they were all flagged).

We must ensure no infinite recursion: e.g., if we one day allow nested folders and delete a parent, cascade to children folders and notes. That is Phase 2.1 (Organization Features) potentially. For now, with a single-level folder system (assuming it’s mostly one-level plus maybe subfolders), implement accordingly. If subfolders exist, cascade down the tree.

Relationships (note_folders, note_tags): When a note is soft-deleted, we typically leave its relational links in place:

The note_folders entry linking the note to its folder remains (the note still “belongs” to that folder, albeit hidden). This is good for restoration – the note goes back to the same folder. It also means if we restore the note, it knows where to appear. We should not delete the note_folders row on soft delete. The only exception would be if we decided to orphan notes on folder deletion, which we are not doing.

note_tags linking tags to the note can also remain. The note won’t show up in tag filters because our queries will exclude deleted notes when showing tag results. But if restored, tags are intact. So leave tags as-is.

note_links (if any linking notes together) likewise remain – a link pointing to a deleted note might not be useful while it’s in Trash, but if restored, the links still work. We could consider hiding link previews if target is deleted, but that’s a minor UI detail.

Summary: Soft deleting a note doesn’t require deleting any of its relationships; just mark the note and optionally tasks/attachments.

GDPR & User Anonymization (Phase 1.2): Although Phase 1.2 is separate, implementing soft delete helps with GDPR compliance. Typically, GDPR “Right to Erasure” might mean permanently deleting user data or anonymizing it. By having a clear Trash mechanism:

We can ensure that when a user truly wants to delete their data, we have a straightforward way to purge it from Trash and the database.

Phase 1.2 might involve anonymizing any residual personal data in “deleted” content if it must be retained (or immediately purging it if requested). Since we plan Phase 1.3 to handle purge, Phase 1.2 could be about things like scrubbing user identifiers. In any case, no changes needed in Phase 1.1 for GDPR beyond what we do, but keep in mind: soft-deleted data is still personal data until purged. We should document this for compliance – it’s retained for X days in Trash unless user permanently deletes or account is deleted.

Performance and Scaling: Over time, soft deletes mean the tables will have more rows (some active, some deleted). Thanks to the deleted index, queries filtering by deleted=false remain fast
GitHub
. We should periodically purge or archive old deleted items (that’s Phase 1.3) to keep the database lean. For now, ensure the index is in place and that our queries use it (they will, if properly written).

Conflict with Archive feature: Some apps have both “Trash” and an “Archive” or “Archive folder.” If DuruNotes has an Archive (the UI code shows specialType 'archive'), that’s a separate concept (Archive might be a user-accessible way to hide notes without deleting). Make sure our Trash implementation doesn’t conflict:

For instance, if a note is archived (not sure how they flag that – possibly a special folder or a boolean isArchived), a user might then delete it. It would then be in Trash. That’s fine.

If a note is in Trash, probably exclude it from Archive or other categories entirely.

Just be aware if there’s an Archive flag in props_enc or somewhere, but likely not needed to handle explicitly here.

Logging and Monitoring: It might be useful to log deletion and restoration events for analytics or debugging (not mandatory). For instance, log an event “Note moved to Trash” with note ID, or increment a counter. Also, monitor if any errors occur during deletion cascade (e.g., failure to mark one of many notes). These logs can help find issues early and ensure no data is unintentionally left active or purged.

By considering these side effects now, we ensure the soft delete system is consistent and won’t require major rework later. Essentially, no data is truly lost until we intend it – everything is reversible, and all references remain intact behind the scenes.

Testing & Verification

Implementing is half the work; we must thoroughly test to avoid surprises in production:

Unit Tests: If the project has a testing framework, write tests for the repository/service methods:

Test that calling delete on a note sets the deleted flag in the local DB and that the note no longer appears in fetched lists of active notes.

Test that deleted notes do appear when specifically querying trash (if we create a getDeletedNotes method, test its output).

Test folder deletion: ensure the folder’s flag is set and all its notes’ flags are set. Verify that after deletion, those notes are absent from normal queries. If we restore the folder in the test, verify all notes reappear and folder is back.

Test task deletion: ensure deleting a task flags it and that subsequent queries for tasks (like getTasksForNote) don’t return it (likely they should filter out deleted tasks too).

If any migration was added, test migrating from an old schema to new (for local DB migration code).

Integration/UI Testing: Manually (or via integration tests) run through user flows:

Delete a note, then check the database (local and remote) to see deleted=true.

Refresh the notes list UI – the note should disappear. Open the Trash UI – the note should be listed there.

Try restoring it via UI – it should disappear from Trash and reappear in original place. Check DB flags reverted.

Delete a folder with some notes: confirm the folder and notes move to Trash. Possibly verify a note count decrement in main views.

Edge: Delete a note that’s currently open or being edited – ensure the app handles it (maybe close the editor and show a message).

Sync scenarios as described in Sync section: simulate offline deletion and online sync to verify resilience.

Try deleting a task in a note and confirm it’s removed from UI immediately (and marked in DB). Possibly ensure that if you undo via a note’s version history or something, it can come back (if such feature exists).

Corner Cases:

Delete an item that was already deleted (shouldn’t normally happen via UI, but if user spams a button or there’s a race, ensure we handle gracefully, e.g., second deletion attempt is no-op or gives an error that item not found).

Ensure that creating a new note re-using an old title or content doesn’t accidentally reuse an old ID (shouldn’t, since we generate new UUIDs).

If using search, ensure search results exclude trashed notes (unless we later add an option to search Trash specifically).

If possible, test the case of large number of deletions (like 1000 notes) to see if any performance issues or sync bottlenecks arise.

User Experience Validation:

Confirm that the Trash feature is discoverable (e.g., the Trash folder is visible and labeled clearly).

Ensure that when Trash is empty, the UI communicates it (to avoid confusion like a blank screen).

Check that all strings are properly localized (if multilingual support is needed).

Simulate a scenario where Trash grows large and auto-purge (though Phase 1.3 will implement that) – just to foresee if UI might need a warning like “Items older than 30 days will be deleted”.

Through comprehensive testing, we can catch any missed pieces (which if left, would become technical debt). Given Phase 1.1 spans Weeks 1-4, we allocate time for iterative testing and fixes each week.

Conclusion & Next Steps

By implementing Phase 1.1 thoroughly across the stack, we gain a robust Soft Delete & Trash system with minimal technical debt. Every layer – database, sync, logic, and UI – has been addressed so that deletion is a reversible state rather than a destructive action. This not only improves user trust and app professionalism (common expectation in modern note apps) but also sets the stage for upcoming phases:

Phase 1.2 (GDPR Anonymization): With soft deletes in place, we can focus on how to handle user data deletion requests, knowing that regular deletions are already non-destructive. We might integrate an option to permanently erase or anonymize data for compliance, which will likely build on the Trash/purge mechanism.

Phase 1.3 (Purge Automation): Our soft-delete implementation will feed directly into this. We will need to implement a background job or cron (possibly using Supabase Edge Functions or an app background task) that permanently deletes items that have been in Trash beyond a retention period (e.g., 30 days) to free up space
GitHub
. Because we designed soft delete with timestamps (using updated_at as an indicator or adding a deleted_at if needed), this should be straightforward. We’ll also handle manual Empty Trash here if not done already.

Future Features: Organization (Phase 2.1) might introduce shared notes or multiple user contexts – our soft delete approach is per-user anyway. We should ensure that if multi-user collaboration is added, only the owner or authorized users can soft-delete and see the trash for a note. Also, On-Device AI or search features (Phase 2.4) should be instructed to ignore trashed content for analysis, unless explicitly included.

We will proceed to implement Phase 1.1 now, following this plan. The development will involve creating/updating the migration scripts, modifying repository methods for delete/restore, adjusting queries, and building the Trash UI and logic. Each subtask will be tracked (as per the checklist) to completion. By the end of Phase 1.1, Duru Notes will have a fully functional Trash system with no loose ends, making the codebase cleaner and the application more user-friendly.
