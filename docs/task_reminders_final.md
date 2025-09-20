Action Plan for Task System Improvements
Link Task Records to Reminders (Persist reminderId):
Issue: When a task with a due date is created or updated, the app schedules a notification (via TaskReminderBridge), but it doesn’t save the generated reminderId back onto the task record. In the code, the call to TaskService.updateTask with a reminderId is commented out as a TODO
GitHub
. Without storing this ID, the system cannot recognize an existing reminder on subsequent updates, causing duplicate reminders for the same task (because updateTaskReminder() will always create a new one instead of updating the old one
GitHub
).
Solution: Modify the task creation/updating logic to record the reminderId in the NoteTask. After calling ReminderCoordinator.createTimeReminder (which returns a new reminder’s ID), update the task with this ID. The NoteTasks table has a reminderId field for this purpose
GitHub
, and TaskService.updateTask already accepts a reminderId parameter
GitHub
. We need to pass the returned ID to that method (uncommenting or adding the parameter in TaskReminderBridge.createTaskReminder and similar places). For example, in createTaskReminder(), call:
await _taskService.updateTask(taskId: task.id, reminderId: reminderId);
(ensuring the updateTask method signature includes int? reminderId). Similarly, when snoozing a reminder, update the task with the new reminderId
GitHub
.
Expected Outcome: Each task will be linked to its reminder. On updating a task’s due date or snoozing, the app will cancel the previous reminder and set a new one using the stored ID
GitHub
GitHub
. This prevents multiple notifications for one task – edits will properly reschedule the existing reminder instead of spawning duplicates.
Complete the Reminder Scheduling UI Path:
Issue: The note editor’s task dialog allows users to set a due date and toggle a reminder (with a custom lead time), but currently that input isn’t fully acted upon. In TodoBlockWidget._saveTaskMetadata, if metadata.hasReminder is true, the code simply has a TODO instead of scheduling the reminder
GitHub
. In the hierarchical todo widget, new tasks are created with a createReminder flag but always use the default 1-hour-before timing
GitHub
. This means if a user selects “Remind me 1 day before,” the app isn’t actually scheduling it 1 day early – it either doesn’t schedule at all (in the first case) or uses the default offset (in the second case). Users may think they set a custom reminder, but only the due date notification (or a default reminder) will fire.
Solution: Honor the user’s chosen reminder time by using the EnhancedTaskService utilities. For new tasks with a custom reminder, call EnhancedTaskService.createTaskWithReminder(...) instead of the normal createTask. This method exists specifically to handle a custom reminder offset before the due date
GitHub
. It creates the task (without auto-reminder) and then schedules a reminder at the specified lead time. In our UI code, we should detect when metadata.hasReminder is true and metadata.reminderTime is set, and invoke createTaskWithReminder(noteId, content, dueDate, reminderTime, ...). For existing tasks where a reminder is being added or changed, we should call a similar update flow – e.g. if a task already exists with a due date but no reminder, and the user toggles “Remind me,” then after updating the task we should call TaskReminderBridge.createTaskReminder for that task (or have the update logic trigger it). We may extend EnhancedTaskService.updateTask to handle a reminderTime as well, or simply call the bridge directly in the UI.
Implementation: In TodoBlockWidget._saveTaskMetadata, implement the TODO at line 201
GitHub
. Use ref.read(enhancedTaskServiceProvider) to get the service. If _task == null (new task) and a custom reminder is set, call createTaskWithReminder with metadata.dueDate and metadata.reminderTime. If _task exists (updating), and metadata.hasReminder is true, compare the current task’s reminder (if any) and schedule or update accordingly (for example, call TaskReminderBridge.updateTaskReminder(newTask) after saving changes, or if no prior reminder existed, call TaskReminderBridge.createTaskReminder(task: newTask)). Also ensure the reminderId gets saved as per point #1. In the hierarchical widget (HierarchicalTodoBlockWidget._saveTaskMetadata), instead of always passing createReminder: metadata.hasReminder to createTask
GitHub
 (which uses the default offset), use the same approach: if a custom lead time is specified, call createTaskWithReminder.
Expected Outcome: When a user sets a reminder for a task in the UI (e.g. “Remind me 1 day before due date”), the app will schedule the notification at the correct offset. The NoteReminder entry will reflect the chosen remindAt time (due date minus 1 day, in this example) instead of the default 1 hour. This gives users the expected functionality – their reminder preferences in the dialog will be honored by the system.
Use a Single Sync Mechanism to Avoid Duplicate Tasks:
Issue: The app currently runs two parallel task-sync processes when editing a note, which can conflict. On opening a note, ModernEditNoteScreen starts the bidirectional sync (noteTaskCoordinator.startWatchingNote) and also calls NoteTaskSyncService.syncTasksForNote() once for initial content
GitHub
GitHub
. The legacy syncTasksForNote parses the note and inserts any checkbox lines as tasks with simple position-based IDs (e.g. "<noteId>_task_0", "..._task_1", etc.)
GitHub
. Meanwhile, the bidirectional sync will also parse the note and create tasks, but using a different ID scheme (a stable hash of the content)
GitHub
. This means on first load a note with tasks can get duplicated: the old sync creates tasks with one set of IDs, then the bidirectional sync sees tasks in the note that don’t match those IDs and creates its own, then possibly deletes tasks whose IDs don’t match any note lines. For example, a task line "- [ ] Task A" might first be saved as note123_task_0 by the old sync, then bidirectional sync generates an ID like note123_task_ab12c3de for the same line and inserts a new task, and finally the old one (note123_task_0) is detected as not present in the note (since IDs differ) and gets marked deleted
GitHub
. This not only causes extra work and flicker, but risks losing metadata: if the first sync attached any additional info to the task (say labels or notes in the DB), that task might be removed.
Solution: Eliminate the double syncing. We should pick one mechanism (preferably the more advanced bidirectional sync) as the source of truth. The simplest fix is to stop calling syncTasksForNote on note open and rely solely on startWatchingNote (which internally does an initial syncFromNoteToTasks once
GitHub
). In practice, that means removing or guarding the block at ModernEditNoteScreen.initState that calls taskSyncService.syncTasksForNote
GitHub
 when a note contains task syntax. The bidirectional sync will handle initial parsing and insertion of any missing tasks itself during initializeBidirectionalSync
GitHub
, using its stable IDs. We should verify that BidirectionalTaskSyncService.syncFromNoteToTasks creates new tasks if they don’t exist and deletes those no longer in the note
GitHub
GitHub
, which it does.
Implementation: Update the note-opening logic to use only one sync path. Remove the WidgetsBinding.postFrameCallback that calls syncTasksForNote in ModernEditNoteScreen (or wrap it in a condition to skip if bidirectional sync is enabled). Ensure that NoteTaskCoordinator.startWatchingNote is always invoked for editing an existing note (this is already done). After this change, test opening notes that contain tasks: they should load with tasks exactly once. No duplicate tasks should appear and then disappear.
Expected Outcome: Tasks in notes will sync consistently without duplication. The bidirectional sync will create tasks with stable IDs based on content (ensuring the same task isn’t re-created every time), and it will update or delete tasks as the note text changes. This reduces churn in the database and prevents any “flash” of duplicate tasks on note load. It also lays a stable foundation for preserving extra task metadata because the same task record will be reused when possible rather than dropped and re-added.
Preserve Task Metadata During Note Edits:
Issue: The markdown representation of tasks in the note only includes a few basic properties – the checkbox (status), the text content, optional priority tags (e.g. #high) and due date (e.g. @2025-12-31). Other attributes like labels/tags, sub-tasks, detailed notes, time estimates, actual time spent are not present in the note text. With the current sync design, if a user edits the note text or if the sync recreates tasks, those richer fields can be lost. For example, if you add labels to a task via the UI, then later modify that task’s text in the note, the sync (especially if using content hashes as IDs) might treat it as a new task or update it without those labels (since it doesn’t know to carry them over). The bidirectional sync’s _hasTaskChanged check and mapping logic consider content, completion, priority, and due date
GitHub
 – but not the labels or notes fields, etc., so changes in those fields aren’t reflected in the note, and changes in the note could cause a task to be recreated without them.
Solution: Introduce a way to keep track of a task’s identity or full data between the note and the database. There are a couple of approaches:
a. Stable Task IDs in the Note: Embed an identifier for each task in the note content (for instance, an HTML comment or a special markdown syntax) that the sync can use to match text lines to existing tasks reliably, regardless of content edits. For example: - [ ] Task A <!-- id: abc123 -->. The sync could parse that and know that line corresponds to task ID abc123 in the database, so it would update that task’s content rather than create a new one. This would preserve fields like labels, because the link is by ID, not by content hash. This requires changes to how tasks are rendered in the note (possibly not showing these IDs to the user, or using a hidden attribute).
b. Richer Markdown for Metadata: Extend the markdown format to include extra metadata. For instance, a task line could include labels or time estimates in a parseable way (e.g., - [ ] Task A @2025-12-31 #high [labels: ProjectX, ClientY]). The sync parser would need to detect and extract these fields. This is more complex for users to edit manually, but could be done in a lightweight way (priority tags and due dates are already handled by simple symbols).
c. Post-Edit Merging: As a simpler stop-gap, when syncFromNoteToTasks detects that a task’s content was edited (e.g., content hash doesn’t match), instead of deleting and inserting a new task outright, it could attempt to find a matching task by some other key (like old content or position) and update it. Currently, the bidirectional sync generates a new ID if content changed significantly (since the hash input changes, the ID changes) and will delete the old one
GitHub
GitHub
. We could alter this to preserve the same id or at least carry over non-text fields. For instance, if a task’s checkbox position hasn’t moved and it’s the “same task” conceptually, we update its content and status rather than make a new entry.
Implementation: The full solution may be involved, but as an immediate measure we should warn users (perhaps in documentation or release notes) that certain task details (like labels or notes) may be lost if they directly edit the task text in the note. Then, plan the improvements above: Adding hidden IDs in the note is a robust approach. We’d implement this by updating the markdown renderer/editor to include a unique ID comment when creating tasks (the ID could be the task’s UUID). The bidirectional parser then looks for that ID. If found, it can map the line to the exact NoteTask and update its fields (content, status, etc.) without touching other fields. This would require storing those IDs in the note text and handling them carefully so as not to show in normal view (maybe zero-width or HTML comments). Alternatively, adjust _generateStableTaskId to incorporate an existing task’s ID if the content matches partially or if the position matches an existing task with no better match.
Expected Outcome: Once implemented, the system will no longer accidentally drop metadata when syncing tasks with notes. A task’s ancillary data (labels, sub-tasks, time tracking) will be retained even if the user edits the task’s text or checkbox in the note. In practical terms, if you label a task “@Work” in the UI and then rephrase the task description in the note, the task will still have the “@Work” label after sync. This will make the integration between notes and tasks much more seamless and predictable.
Implement “Open Task” Notification Action (Deep Linking):
Issue: Notifications for task reminders have an Open button intended to take the user to the task’s detail, but currently this action is not wired up. The Android notification is created with an open_task action
GitHub
 and on iOS a category is set, but tapping it doesn’t navigate the user to the app’s task or note screen. In the code, TaskReminderBridge.handleTaskNotificationAction receives the action and payload – for "open_task" it calls _handleOpenTaskFromNotification – which as of now only logs an info message and contains a “TODO: Implement deep linking navigation”
GitHub
. There is no actual code to open the app or direct to the correct note/task.
Solution: Enable deep linking from the notification action to the app UI. We should decide what screen to show: ideally, opening the note that contains the task, and maybe scrolling to or highlighting that task. Since the payload includes the noteId and taskId
GitHub
GitHub
, we have the needed identifiers. Implementing this could be done in a few ways:
– If app is in background: Configure the notification library (Flutter Local Notifications) with a callback or intent that launches the app to a specific route. For example, set up a method channel or use the initialPayload in FlutterLocalNotificationsPlugin so that if the app is opened via a notification tap, we can parse the payload and navigate. The iOS categoryIdentifier “TASK_REMINDER” should be registered with actions so that tapping Open triggers the plugin’s handler. We might use the onDidReceiveNotificationResponse callback to catch the open_task action and route it.
– If app is in foreground: Tapping Open should directly navigate. We can have _handleOpenTaskFromNotification broadcast an event via an EventBus or Riverpod provider that the UI listens for. For instance, the bridge could call something like NavigationService.openTask(noteId, taskId) or use a global key to access the navigator. Another approach is to use a deep link URL (e.g., a custom scheme myapp://openTask?note=<id>&task=<id>) and have the app handle it.
Implementation: In TaskReminderBridge._handleOpenTaskFromNotification, replace the TODO with actual navigation logic. On Android, ensure that the AndroidNotificationAction for Open does not just dismiss the notification but triggers the Dart side (the plugin typically does this automatically if configured). We may register a callback in main.dart when initializing notifications: e.g., FlutterLocalNotificationsPlugin().initialize(..., onDidReceiveNotificationResponse: (response) { ... }) and in that callback, detect if response.actionId == 'open_task' and then call a function to navigate to the note. We’ll create a helper that uses the stored noteId to open the note editor (or a read-only view) and maybe scroll to the task. Perhaps the easiest path: when the user taps Open, just open the note and focus the task’s checkbox (we could even search the content for the task text). On iOS, we need to ensure the notification actions are properly set with the category and that the app delegate is configured to forward the action to Flutter (the Flutter local_notifications plugin can do this if the category matches an identifier it knows; otherwise we handle via didReceive...). In summary, a possible implementation is: use the payload’s noteId and taskId to push a route like /note/noteId?highlightTask=taskId. Integrate this with the router or a global navigation key.
Expected Outcome: When the user taps “Open” on a task reminder notification, the app will launch (if not already) and navigate directly to the relevant note, making it easy for them to view details or edit the task. This completes the notification UX loop: Complete will mark done, Snooze will reschedule, and Open will jump to the content, providing a convenient quick action.
Finalize Snooze Reminder Functionality:
Issue: The design documents mention limiting snoozes (e.g., a max of 5 snoozes per reminder) and smart scheduling (“tomorrow morning” etc.), and indeed the code has a SnoozeReminderService class with these capabilities
GitHub
GitHub
. However, this service is not currently active – it’s commented out in the ReminderCoordinator initialization
GitHub
. Instead, snooze actions in notifications are handled in a simpler way: the TaskReminderBridge directly cancels the existing reminder and creates a new one for the snooze duration
GitHub
GitHub
. This works for basic snoozing but doesn’t enforce the max snooze count (though the database tracks snoozeCount, it’s not checked here) and doesn’t have options beyond the hardcoded 15 minutes and 1 hour on Android (and presumably a default on iOS). Essentially, the groundwork for a more advanced snooze system exists but isn’t fully hooked up.
Solution: Integrate the SnoozeReminderService or implement equivalent checks in the current flow. In the short term, we could add a simple guard in snoozeTaskReminder: after retrieving the task and its current reminderId, query the NoteReminder from the DB and check its snoozeCount. If it’s >= 5, refuse to snooze further (perhaps notify the user that the limit is reached). The SnoozeReminderService already has logic for this (maxSnoozeCount = 5 and it checks the count before snoozing
GitHub
). Ideally, we should instantiate and use SnoozeReminderService for consistency – for example, call _snoozeService.snoozeReminder(reminderId, duration) from the TaskReminderBridge instead of manually rescheduling. That service also handles scheduling a new notification and computing “tomorrow” times intelligently
GitHub
GitHub
. We might need to wire up the plugin callbacks for snooze actions to funnel into the SnoozeReminderService (similar to how recurring reminders are handled via RecurringReminderService).
Implementation: First, enable the SnoozeReminderService in ReminderCoordinator (instantiate _snoozeService and possibly call an initialize if needed). Then adjust handleTaskNotificationAction for snooze cases: instead of directly calling snoozeTaskReminder in TaskReminderBridge, perhaps call a method in ReminderCoordinator or SnoozeReminderService. Alternatively, incorporate SnoozeReminderService’s logic into TaskReminderBridge: check reminder.snoozeCount as stored in the NoteReminder (the DB trigger is incrementing it on each snooze
GitHub
). If >=5, don’t reschedule and maybe show a notification or toast that the reminder can’t be snoozed further. If less, proceed to reschedule. Also consider adding more snooze options (e.g., “Snooze 5 min” or “Tomorrow morning”) by defining additional notification actions and handling them (the enum SnoozeDuration has options like fiveMinutes, tomorrow
GitHub
). This could be a future enhancement once the basics are stable.
Expected Outcome: The snooze feature will align with the intended design: Users can only snooze a reminder a limited number of times (preventing indefinite deferral), and possibly have more snooze duration choices. After implementing, if a user taps snooze repeatedly, on the sixth attempt the app would refuse (e.g., re-notify immediately with a message or simply not schedule another snooze), encouraging them to handle the task. This keeps the reminder system from becoming an endless loop and nudges users to address tasks.
Use the User’s Input for New Task Titles:
Issue: In the Tasks screen, tapping the New Task FAB brings up a dialog (TaskMetadataDialog) which is pre-filled with the title “New Task”. If the user fills in details and saves, the app still creates the task with the title “New Task” (the default), ignoring any custom name they may have typed. The code shows that after the dialog, _createStandaloneTask always calls createTask with content: 'New Task' literally
GitHub
, instead of using metadata.taskContent. This likely forces the user to then edit the task to give it a real title, which is clunky. It also means multiple new tasks could all be named “New Task” initially.
Solution: Allow the user to set the task’s title during creation and actually use it. The TaskMetadataDialog actually does support editing the task name (it has a TextField for taskContent and returns it in TaskMetadata
GitHub
GitHub
). We should utilize that. When the dialog returns a TaskMetadata, grab metadata.taskContent and pass it to createTask. In other words, replace the hard-coded 'New Task' with the user’s input. Also consider not using a placeholder at all – we could start with an empty field or a lighter hint instead of a fixed string, to encourage the user to type something descriptive.
Implementation: In _showCreateStandaloneTaskDialog, we already pass taskContent: 'New Task' to the dialog
GitHub
. We can change that to '' (empty) so the dialog shows an empty text field (or keep 'New Task' as a hint but at least let it be editable). More importantly, in _createStandaloneTask, use metadata.taskContent as follows:
await taskService.createTask(
    noteId: 'standalone',
    content: metadata.taskContent.isNotEmpty ? metadata.taskContent : 'New Task',
    … // other fields
);
This way, if the user typed a name, it’s used; if they left it blank, we could fallback to "New Task" or better yet, validate in the dialog that it’s not empty (the dialog already does validation – it won’t allow saving an empty name
GitHub
). Remove the comment “// Default content, user can edit” because now the default content will likely be replaced by actual content
GitHub
. After this change, test creating a task: type a custom title in the dialog and ensure the new task appears with that title in the list.
Expected Outcome: Creating a new task will be a smoother experience. The user can set the task’s name immediately in the popup, and the task will show up with that name (no extra edit step required). This avoids confusion of seeing multiple “New Task” entries and improves initial organization of tasks.
Ensure Robust Sync on Rapid Task Toggling:
Issue: The bidirectional sync uses a short debounce (500ms) to batch updates when the note text changes
GitHub
GitHub
. This prevents excessive churn and infinite loops (especially when a task toggle updates the note text, which then triggers a task update, etc.). However, if a user very quickly checks and unchecks a task (or toggles multiple tasks in quick succession), there’s a risk that one of the state changes might be lost or applied out-of-order. For example, if you click a checkbox on and off in under half a second, the note might end up with it still checked (because the “unchecked” update got coalesced or overwritten). The _activeSyncOperations flag in BidirectionalTaskSyncService is meant to prevent simultaneous syncs
GitHub
, but rapid user interactions might still queue multiple operations once the lock is free. Additionally, if the user closes the note immediately after toggling a task, the last update might not persist if the debounce hasn’t fired yet.
Solution: We should test and handle edge cases for rapid toggling. One strategy is to force a final sync when the editor is about to dispose (ensure no pending changes are unsynced). For instance, in dispose of the note editor screen, call noteTaskCoordinator.syncNote(noteId) to flush any remaining updates immediately
GitHub
. Also, consider shortening the debounce for checkbox toggle events specifically. Since checking a box is an explicit user action that they probably expect to reflect instantly, we might apply a smaller delay (or none) when a task is marked complete/incomplete. The code in TodoBlockWidget._toggleCompleted already calls NoteTaskSyncService.updateNoteContentForTask immediately to reflect the change in the note text
GitHub
, which helps one direction. We need to ensure the other direction (note to task DB) also doesn’t skip an update. Monitoring the logs during rapid toggles will reveal if any “Skipped sync because active” messages or missed state occur. If so, we can adjust the logic: for example, do not exit _handleNoteChange without syncing if another sync was active; instead, queue one more run after the active one finishes (perhaps by scheduling again).
Implementation: Add a safeguard in the coordinator’s debounce handler: if _activeSyncOperations is true when a new note change comes in, maybe extend or restart the debounce so that the change isn’t lost. Another approach is to reduce _debounceDelay (500ms) to something like 300ms, to catch quick interactions faster. We should also explicitly call syncFromNoteToTasks when the user navigates away (since closing the note will remove focus and might not trigger the normal text change listener). We can use the dispose of ModernEditNoteScreen or the route’s didPop to perform a final sync. By doing so, even if a toggle happened just before closing, the tasks in the database reflect the final state.
Expected Outcome: The synchronization between note text and task list remains correct even under rapid user actions. If a user rapidly toggles a task or edits multiple tasks quickly, the final state in the note and in the database will match what the user saw last. No task will mysteriously revert its status or duplicate. Essentially, this makes the system more fault-tolerant to fast interactions.
(Future) Leverage Analytics & Goals Features:
Issue/Opportunity: The codebase includes classes for productivity analytics (TaskAnalyticsService) and user productivity goals (ProductivityGoalsService), but these appear to be only partially implemented and not exposed in the UI. Enums and fields exist to support recurring task patterns, priorities, etc., and the app is already recording data like completedAt timestamps and estimatedMinutes/actualMinutes on tasks
GitHub
. However, there’s no current screen fully utilizing this. For instance, there is a ProductivityAnalyticsScreen and the TaskAnalyticsService.getProductivityAnalytics() computes a variety of metrics (completion rate, time estimation accuracy, trends, etc.)
GitHub
. Similarly, ProductivityGoalsService can save goals and track progress
GitHub
GitHub
. These are groundwork for advanced features (possibly related to AI or user motivation) that aren’t active yet.
Plan: While not a “bug,” fleshing out these analytics features could greatly enhance the app, especially if integrating AI to provide insights or coaching. Once the above critical fixes are done, we can turn to implementing these:
Productivity Analytics: Finish the UI to display the metrics from TaskAnalyticsService. The service already calculates stats like number of tasks completed vs created in a time range, average tasks per day, priority distribution, deadline adherence, etc. We should create visualizations or at least a summary view in the app (perhaps the “Insights” tab) where users can see these numbers. For example, show a chart of tasks completed per day, or a percentage of tasks completed on time vs overdue
GitHub
GitHub
. This will make use of data already being collected.
Goals: The ProductivityGoalsService allows users to define goals (like “Complete 10 tasks this week” or “Improve on-time rate to 90%”) and checks progress
GitHub
GitHub
. To implement this, we need UI for users to create goals (choose a metric, target value, and time period) and a way to display current progress (perhaps a progress bar or simply text). The service uses SharedPreferences to store goals
GitHub
GitHub
, so it’s mostly client-side. We’d integrate it by providing a screen or dialog to set goals and by periodically calling updateAllGoalProgress()
GitHub
 (maybe when the user opens the app or completes tasks) to refresh status. Achievements (completing a goal) could trigger a notification or badge as encouragement.
Outcome: By activating these features, users get more value: they can review their productivity trends and receive feedback. For instance, the app could say “You complete 8 tasks/week on average” or “Your time estimates are 30% longer than actual time – consider adjusting estimates.” Goals give users a target to strive for, which can be motivating (for example, “Streak: 5 days in a row completing at least one task”). While these analytics and goals aren’t directly related to the core task-sync functionality, they complement the task management experience and could be a platform for future AI-driven insights (like suggesting goal adjustments or focus areas based on the data). Implementing them would realize the potential hinted at by the existing codebase
GitHub
GitHub
.
Each of these steps addresses gaps or improvements identified in the audit. By tackling points 1 and 2 first (reminder linkage and UI completion), we ensure the reminder system is reliable for users. Then fixing 3 and 4 will solidify the task-note synchronization, preventing data loss and duplicates. Point 5 and 6 enhance the reminder notifications to be more user-friendly and aligned with the intended design. Finally, 7 and 8 are usability tweaks to polish the experience, and 9 opens the door to advanced features once the basics are solid. Following this plan will not only fix the current issues but also lay a strong foundation for adding intelligent features in the future.