İçeriğe geç
Sohbet geçmişi

Şunu dedin:
bu iki taskı sonraya bırakıyorum, widget ve extension yaratma sürecinde çok problem yaşadım, bütün her şeyi bitirip implemente ettikten sonra bakacağım, belki bu iki özellik olmadan çıkacağım. 
* 	•	System Share Extension (iOS & Android): Develop a share sheet extension so users can send content into DuruNotes from other apps. On iOS, this means creating an Action Extension or Share Extension target in the Xcode project via Flutter (which likely involves some native code or use of the flutter_share plugin if available). The extension should accept common data types: text snippets, URLs, images, etc. When a user shares to DuruNotes, the extension can create a new note with that content (e.g. if sharing a webpage from Safari, grab the URL and page title into the note; if sharing text, put it in the note body; if an image, add as attachment). Consider adding a default tag or metadata for notes created via share (similar to how email-in notes are tagged #EmailGitHub or web clips #Web). On Android, implement an intent-filter to receive shared content. Flutter can handle incoming intents using an external package or through platform channels. Likely, we’ll start an instance of the app (or a headless receiver) that adds the data to a new note. Key micro-tasks: set up the platform-specific code for receiving shares, pass the data to Flutter (maybe via method channel), and implement logic in Dart to save a new note from that data. Also, if the app is locked or requires authentication (if any security in place), decide how to handle that for quick captures (perhaps queue the note until app is unlocked). Testing: share various content types from different apps (browser, gallery, notes) on both iOS and Android to verify the note is created correctly with the shared content and that no data is lost (e.g. multi-image share, or a URL with no text).
* 	•	Home Screen Widget (Quick Note): Provide a widget on mobile platforms for fast note-taking or viewing. For iOS 16+, Flutter supports widgets via additional packages (since iOS widgets are essentially SwiftUI views, we might need to write a bit of native code or use flutter_widgetkit). The widget could be something simple like a “New Note” shortcut or a small list of recent notes. A minimal valuable widget might be a Quick Add button: tapping it deep-links into the app’s new-note screen, or even directly opens a text input overlay to capture a note without fully launching the app (this might need iOS App Quick Actions or a widget with a textfield, though interactive widgets on iOS are limited). On Android, implement an App Widget that could have buttons (New Note, maybe shortcuts to specific folders or recent notes). Android widgets allow some interactivity; for instance, one design is a scrollable list of recent notes and a "+" button. To implement: use Flutter’s widget support (there are packages that simplify this) or write native widget code and have it communicate with Flutter (via App Links or an isolate). Initially, focusing on a simple "New Note" one-tap widget might be best. Also consider App Shortcut (long-press app icon to get quick actions like New Note, Search) – on iOS this is done via Info.plist UIApplicationShortcutItems, on Android via manifest shortcuts. These are not home screen widgets but related quick-capture features. Ensure the widget updates appropriately (for example, if showing a count of notes or last note title, it refreshes when notes change – possibly using App Groups on iOS or similar mechanism for shared data). Testing: add the widget on both platforms, tap it to create notes, and verify it works from various states (app running in background vs closed).


şimdi şablon not, note template ekleme için çalışma yapacağım. Note Templates: Introduce templates to speed up capturing structured notes. Templates could be a set of pre-defined note contents (like "Meeting Notes", "To-Do List", etc.) that the user can choose from when creating a new note. A straightforward implementation is to ship a few default template files and allow the user to duplicate them. For example, have a hidden “Templates” folder with notes that serve as templates, or store template content in a JSON config. Micro-tasks: create a UI in the "new note" flow that lets the user select a template (e.g. a New Note menu that has a submenu or dialog: New Blank Note, From Template → [Meeting, Journal, etc]). If using a Templates folder approach, the action would basically duplicate the template note’s content into a new note. Ensure formatting (checklists, headings, etc.) in the template is preserved. Also allow users to create their own templates eventually – perhaps by saving a note as template (not mandatory in first version, but keep in mind). Implement at least 2-3 useful default templates for now. Testing: create notes from each template and verify the content matches the template, and that template notes themselves aren’t accidentally shown as normal notes (if using a special folder, maybe hide that folder from normal view or mark templates distinctly).

This is the implementation plan;

Implementation Prompt

  - Add note templates to speed structured capture while keeping them invisible in the regular note surface, and measure success via creation latency, template adoption %, and zero regressions in sync/search.
  - Respect offline-first + end-to-end encryption guarantees; template metadata must never break lib/repository/notes_repository.dart:206 syncing, and UX must stay seamless in lib/ui/notes_list_screen.dart:204.
  - Ship at least Meeting Notes, Daily Journal, and Action Items templates with content reviewed by product, localized, and aligned with accessibility and Material 3 guidance.

  Architecture Checkpoints

  - Note authoring funnels through ModernEditNoteScreen (lib/ui/modern_edit_note_screen.dart:20) and is launched by the FAB helpers around lib/ui/notes_list_screen.dart:204 and lib/ui/notes_list_screen.dart:1152; template entry
  points must plug into both.
  - Local storage is Drift-based (lib/data/local/app_db.dart:20), synced to Supabase via encrypted payloads (lib/repository/notes_repository.dart:760), re-indexed for search in lib/core/parser/note_indexer.dart:20, and surfaced
  through Riverpod selectors (lib/providers.dart:239).
  - Pagination (lib/features/notes/pagination_notifier.dart:12), smart folders (lib/features/folders/smart_folders/smart_folder_engine.dart:15), bulk actions, and keyboard shortcuts all call NotesRepository.list or
  AppDb.allNotes; template filtering must be centralized.

  Data Model & Persistence

  - Introduce enum NoteKind { note, template } (e.g. lib/models/note_kind.dart) and add a non-null note_type column with default 'note' to LocalNotes (lib/data/local/app_db.dart:27), bump schemaVersion to 10, and update
  migrations to backfill existing rows.
  - Regenerate Drift bindings (dart run build_runner build --delete-conflicting-outputs) so LocalNote in lib/data/local/app_db.g.dart exposes noteType; update factories, companions, and test fakes that instantiate LocalNote.
  - Propagate noteType through repository APIs (lib/repository/notes_repository.dart:206, lib/repository/notes_repository.dart:320, lib/repository/notes_repository.dart:652) and ensure every query that currently checks
  deleted.equals(false) also excludes templates unless explicitly requested.
  - Persist noteType in encrypted metadata (propsJson['noteType']) so cross-device sync and older builds stay compatible; on pull (lib/repository/notes_repository.dart:855) read it back and default to 'note'.

  Seed Data & Template Service

  - Create assets/templates/templates.json (register in pubspec.yaml:100) with slug, title, body, emoji/icon, category, version, and suitability tags; include at least 3 curated templates.
  - Add a TemplateSeeder (e.g. lib/services/template_bootstrapper.dart) that runs post-auth (lib/app/app.dart:320) once per user, inserting or updating templates via NotesRepository.createOrUpdate with noteType:
  NoteKind.template, using stable IDs derived from the slug to avoid duplicate seeds.
  - Store a per-template seed version in SharedPreferences to allow upgrading defaults without overwriting user-modified templates; log via AppLogger.

  Repository & Service Layer

  - Add a TemplatesRepository facade or extend NotesRepository with listTemplates(), getTemplateBySlug, createOrUpdateTemplate, and createNoteFromTemplate that duplicates content and resets metadata/timestamps while keeping
  template formatting intact.
  - Queue template ops with distinct pending-op kinds (e.g., 'upsert_note_template') if server-side differentiation helps analytics, otherwise reuse 'upsert_note' but ensure template filters stay client-side consistent.
  - Update NoteIndexer (lib/core/parser/note_indexer.dart:33) and FTS triggers (lib/data/local/app_db.dart:472) to short-circuit indexing when noteType == template, keeping local search clean.
  - Expose Riverpod providers (lib/providers.dart) for templateListProvider, recentTemplateProvider, and a helper that prefetches templates when the user opens the new-note sheet.

  UI & UX

  - Replace the single-action FAB in lib/ui/notes_list_screen.dart:204 with a Material bottom sheet or extended FAB that offers New Blank Note and a From Template section; respect compact layouts and accessibility (talkback
  labels, focus order).
  - Build a reusable template picker widget (lib/ui/templates/template_picker_sheet.dart) that shows template title, description, and quick metadata; integrate in folder-specific flows (lib/ui/notes_list_screen.dart:1161) so
  templates can start inside the active folder when appropriate.
  - On template selection, pre-create the note via createNoteFromTemplate, then navigate to ModernEditNoteScreen with initialTitle/body already populated and track analytics.
  - Add subtle affordances (e.g., chip in the editor header) to show the note originated from a template and allow clearing that state; ensure undo/redo (lib/services/undo_redo_service.dart) works with seeded content.

  Sync, Search & Offline

  - Filter templates out of pagination (NotesPaginationNotifier.loadMore), folder counts, saved searches, inbox badge, smart folder engines, keyboard shortcuts, and batch operations by using the centralized noteType predicate.
  - Ensure template duplication works offline by queuing the new note for sync; do not expose template rows via API queries in SupabaseNoteApi other than through encrypted payloads.
  - Update fts_notes triggers to guard on note_type != 'template', and add migrations to drop any existing template rows from FTS to avoid stale hits.
  - Verify import/export flows (lib/services/import_service.dart, lib/services/export_service.dart) either skip templates or provide explicit toggles; adjust share extension (lib/services/share_extension_service.dart) to forbid
  template creation from incoming shares.

  Analytics & Monitoring

  - Add analytics constants (e.g., template_used, template_opened) in lib/services/analytics/analytics_service.dart:2 and fire events on template selection, note creation, and cancellation.
  - Log seeding and errors with AppLogger, and add Sentry breadcrumbs when template data fails to load; include template slug in anonymized metadata only.
  - Update any dashboards or Supabase edge functions if template stats are needed; document fields in docs/analytics.md if present.

  Testing & QA

  - Unit-test the template service (seed idempotency, version upgrades, duplication) under test/services/template_service_test.dart; include regression coverage for NotesRepository.createNoteFromTemplate.
  - Add widget tests for the picker and FAB state changes (test/ui/templates/template_picker_sheet_test.dart) using flutter_test golden patterns to catch theming regressions.
  - Extend integration tests (e.g., test/services/import_integration_simple_test.dart:102) to ensure templates are excluded from regular listings and that creating from each default template matches the source text exactly.
  - Provide manual QA scripts covering offline creation, sync across two devices, localization (RTL), accessibility (screen readers), and interactions with folders/saved searches.
  - Update CI scripts if new tests require additional setup, and ensure coverage thresholds remain satisfied.

  Rollout & Ops

  - Document migration steps (Drift schema upgrade, template seeding) in a release checklist, including back-out plan (e.g., migrate down, purge template rows) and Supabase schema review.
  - Communicate required Supabase changes (if any) to backend owners; ensure RLS policies continue to pass (test/sql/test_rls_policies.ts).
  - Update user-facing docs/FAQ or in-app tips to mention templates, and prepare release notes calling out the new workflow.
  - Monitor post-release logs and analytics for template adoption and unexpected template visibility in note lists; be ready to hotfix template filtering if necessary.

  Future & Open Questions

  - Design “Save note as template” flow leveraging the same noteType column, including permissions, naming, and versioning.
  - Decide whether templates warrant folder-like organization or tagging; consider exposing favorites or last-used templates.
  - Evaluate whether Supabase should expose template analytics or if local-only metrics suffice.
  - Align on localization cadence and copy review for template content before finalizing seed data.
ChatGPT:
Thanks for the detailed plan. Before I proceed, could you clarify what specific help you’d like with the note templates feature implementation? For example, are you looking for:

Code scaffolding or architecture validation?

Migration or schema update support?

UX flow and widget suggestions for the template picker?

Test plan structuring?

Copy suggestions for default templates (Meeting Notes, Daily Journal, Action Items)?

Let me know where you'd like support so I can tailor my response effectively.

Şunu dedin:
so you're able to reach to the github, 
1. you can make an assesment and my plan validation.
2. I'm using Cursor, and GPT Codex, Claude 4.1 Opus Max and Me :)
3. After codebase review you can enhance the implementation plan and convert it Claude-friendly prompts. 
ChatGPT:
Great. I’ll perform a codebase-level validation and architectural assessment of your Note Templates implementation plan for DuruNotes. I’ll also enhance it where applicable and rewrite it into Claude-friendly, modular prompts you can use inside Cursor or other coding copilots.

I’ll get back to you shortly with structured feedback, enhancements, and actionable prompt blocks.

Research completed in 12m· 13 kaynak· 6 arama
Assessment and Enhancement of Note Templates Plan for DuruNotes

Validation Summary
The proposed Note Templates design is largely well-aligned with DuruNotes’ architecture. It cleanly extends the data model with a new NoteTemplates table (both locally in Drift and remotely in Supabase) instead of overloading the existing notes schema
GitHub
. This separation means template records won’t interfere with normal note queries, full-text search, or pagination by default – a strong choice for isolation and clarity. The plan covers end-to-end considerations: local schema, sync logic (pending ops, Supabase migrations), UI flows (template picker, “save as template”), and analytics/logging hooks
GitHub
. It also emphasizes testing (migrations, unit tests, widget UI, integration tests) and outlines RLS and triggers on the server side to maintain data integrity
GitHub
. Overall, the feature is designed in a comprehensive and privacy-conscious way, consistent with the app’s offline-first, encrypted architecture. That said, a few areas need attention or clarification:
Data Model & noteType Usage: The plan suggests using a separate NoteTemplates table (with fields like name, body, tags, etc.) and possibly mentions a noteType column or NoteKind enum to classify notes vs. templates. In practice, if templates live in their own table, adding a noteType field to the main notes may be redundant for filtering (since templates aren’t in the notes table at all). It might only be needed if you want to mark notes that were created from a template. Make sure to use this consistently – e.g. a NoteKind.Template could flag a template definition, while normal notes remain NoteKind.Normal. If you do keep templates completely separate, you can avoid scattering WHERE noteType != 'template' checks throughout the code. In summary, the modeling approach is sound, but be clear whether templates are segregated (preferred) or identified by a type flag (and adjust filtering logic accordingly).
Sync & Offline Safety: Integrating templates into the sync flow needs careful implementation. The plan accounts for offline support by queuing template ops in PendingOps (so template creates/edits sync later)
GitHub
. This should fit nicely with the existing SyncService, but you’ll need to extend it. Ensure that NotesRepository.pushAllPending() (or a similar mechanism) processes new op types like upsert_note_template and delete_note_template, encrypts template data, and uses a Supabase API call to persist templates. Likewise, add a pull step for templates (e.g. fetchEncryptedTemplates from Supabase) so that creating a template on one device syncs to others. One missing piece is realtime updates: the unified realtime subscription currently listens for changes in notes, folders, etc., but not note_templates. Without this, a new template made on device A might not immediately appear on device B until the next sync. Consider extending UnifiedRealtimeService to subscribe to the note_templates table (similar to notes) so template creations/updates propagate in real time. The data model changes (including using a UUID primary key for templates and enforcing user_id and unique name per user) combined with Supabase RLS
GitHub
 will keep template sync private and scoped to the owner. Just double-check that encryption is applied to template content the same way as notes. The plan’s Supabase schema lists body text and other fields in plain form
GitHub
 – given Duru’s end-to-end encryption, you’ll want to store at least the template body (and probably name/description) in encrypted form on the server. This likely means adding name_enc and props_enc columns (like the notes table has) and handling encryption in the client API. This is crucial so that templates don’t become a privacy loophole. As long as you incorporate templates into the encryption/sync pipeline (and write server triggers for things like lowercase tag normalization as planned), the data model and sync logic remain safe and compatible with existing notes.
Filtering & Indexing: By introducing templates as a separate entity, the plan smartly avoids polluting normal note queries. Regular note lists and searches will naturally exclude templates unless explicitly included. This reduces regression risk – for example, your note FTS index and queries will continue to index only real notes, not template definitions. Do verify that any tag counts or autocomplete logic similarly ignore templates (unless you want template tags to show up). Since templates have their own tags field, the plan’s server trigger will deduplicate/lowercase them
GitHub
, but you probably don’t want template-only tags appearing in the global tag list until a template is actually used to create a note. A minor caution: if you had decided to use a noteType flag in a unified table, you would need to add AND noteType = NORMAL to a lot of queries (notes listing, search, pinned notes, etc.). The chosen separate-table approach neatly sidesteps this. Just be mindful in the UI that template entries are fetched via their own code paths (e.g. a Template picker provider) and that features like “folder counts” or “last updated note” don’t accidentally include templates. The plan’s filtering strategy (keeping templates out of normal pagination and folder assignments altogether) is solid and should avoid regressions in search or smart folders
GitHub
, as long as templates remain segregated unless intentionally invoked.
UI Integration & UX: The plan covers multiple UI touchpoints: a templates picker (likely a bottom sheet) in the note editor, changes to the FAB (new-note flow), and a “Save as Template” option in the note editing screen
GitHub
. This is comprehensive, but careful execution is needed to make it intuitive. The template picker should be easily accessible when creating a note. The plan suggests showing it in the editor screen – for example, a “Apply Template” button or icon that opens a list of templates. That works, though an alternative (for faster access) is intercepting the New Note FAB: if template suggestions are enabled, tapping the FAB could directly open a “New from Template” sheet with options for a blank note or a template. Either approach can work; the key is not to add too much friction when a user just wants a blank note. Since you have a Settings toggle to enable/disable templates
GitHub
, you could default to the current behavior (blank note on FAB) unless the user opts in to template suggestions. When implementing the picker UI, leverage Riverpod to provide the list of templates (e.g. listTemplates() from the Template service) and use flutter_markdown to show a preview of each template’s content as described
GitHub
. Make sure to handle template preview rendering efficiently (perhaps just the first N characters or so) to avoid heavy markdown parsing in a long list. The “Save as Template” action is straightforward – it should gather the current note’s title, body, and tags and prompt the user for a template name (or reuse the note title) then call the Template service to save it. One improvement here: if notes have additional metadata like color or icon and you want templates to capture an “icon” for easy identification, you might extend the template model to include that (the plan hinted at “optional icon/color metadata” for templates, though it wasn’t explicitly in the schema). This can be a future enhancement. Overall, ensure the UX flows are smooth: for example, after creating a note from a template, the editor should clearly indicate that the content was loaded from a template (maybe via a subtle toast or a small label, purely informational). But templates shouldn’t feel like second-class objects – the user should find them in a dedicated UI (perhaps a Templates section in settings or a manage-templates screen) for editing or deleting them as the plan suggests.
Analytics & Observability: The plan appropriately adds analytics events like quick_capture.template_used and .template_created
GitHub
. This will help track how often users leverage templates. Be sure to record relevant properties (e.g. template_id, maybe template_name, source of creation if through widget/share, etc.) using your AnalyticsService. Also continue the convention of structured logging with AppLogger: for example, when a template is applied, log an info/breadcrumb with the template ID and note ID, and when a template is created or deleted, log those with IDs as well. This aligns with existing observability – just avoid logging any sensitive content (stick to IDs or perhaps template names, which are usually generic). The plan’s inclusion of these analytics and logs is good; just double-check that the new code follows the no PII in logs rule (template names/tags might contain user terms – probably fine, but if any concern, you can hash or omit actual content from logs). Another observability angle is performance: adding template selection shouldn’t noticeably slow down note creation. Templates are few in number, so this is low risk – but you might track the time it takes to load/apply a template and ensure that’s negligible (could even emit a performance metric if needed). Lastly, the test plan covers a lot of ground (fresh account defaults, cross-device sync, offline usage, toggling the feature on/off without affecting normal notes)
GitHub
. Make sure to implement those tests, especially offline scenarios (e.g. create templates offline on two devices, sync them – do conflicts arise or are they just duplicated? Ideally, avoid name conflicts by the unique name constraint). The thorough testing and monitoring steps in the plan will help catch regressions and ensure the templates feature doesn’t compromise existing functionality.
In summary, the plan is robust and well-scoped, integrating note templates into DuruNotes with attention to architecture (using existing services like NotesRepository, SyncService, etc.), data safety (encryption and RLS for the new table), and UX (making templates accessible but not intrusive). The main improvements are to simplify where possible (e.g. leverage the separate table rather than adding a noteType flag everywhere) and to cover the couple of missing pieces like realtime sync and encryption of template content. Addressing those, and heeding the potential edge cases mentioned, will ensure the feature rolls out smoothly without privacy or regression issues.
Enhanced Implementation Plan
Below is an adjusted plan that follows the original outline but with some refinements and sequence optimizations: 1. Data Schema Extensions (Local & Remote): Begin by updating the data models. In the Drift database, add a new noteTemplates table with the proposed columns:
id (TEXT primary key, storing UUID as string),
name (text),
body (text),
tags (could be stored as a JSON string or a separate many-to-many relation; simplest is a comma-separated or JSON array text field if full tag querying isn’t needed locally),
description (text, optional short info),
updatedAt (DateTime),
deleted (boolean flag for soft delete).
This will involve writing a Drift migration to create the table and updating lib/data/local/app_db.dart accordingly
GitHub
. On the Supabase side, create a parallel note_templates table via a SQL migration. The schema should mirror the needed fields:
id UUID PK,
user_id UUID FK -> users (with index),
name text,
body text,
tags text[],
description text,
updated_at timestamptz DEFAULT now(),
deleted boolean DEFAULT false,
Unique index on (user_id, lower(name)) to prevent duplicate template names for one user
GitHub
.
Additionally, add triggers to auto-update the updated_at timestamp and normalize tags to lowercase (e.g., on insert/update, do NEW.tags = array(SELECT DISTINCT lower(t) FROM unnest(NEW.tags) AS t) as suggested). These ensure consistency. Also create RLS policies on note_templates similar to notes: owners can SELECT/INSERT/UPDATE/DELETE their templates, and perhaps a separate full-access for a service role if needed. Important: Since DuruNotes encrypts note content, decide how to handle encryption for templates. The recommended approach is to encrypt template name and body/description on the client just like notes, and store them in binary columns (name_enc, props_enc) instead of plaintext. This will keep templates fully private on the backend. (You could still keep a plaintext tags array if tags are not sensitive, or encrypt them too inside props_enc.) Adopting encryption means also adding corresponding columns to the Drift model (to hold encrypted data or metadata as needed). If encryption is used, update the Supabase migration to have name_enc bytea, props_enc bytea and omit storing body/description in plaintext. In summary, extend the local and remote schema first, and run migrations so both sides know about note_templates. Verify that the app’s migration path is handled (e.g., bump Drift schema version and test that an existing user’s app upgrades without data loss).
2. Service Layer – Template Management: Implement a new TemplateService (or a TemplatesRepository) to encapsulate CRUD operations for templates
GitHub
. This service will mirror some of the NotesRepository functionality but for templates. Key methods include:
listTemplates() – fetch all non-deleted templates from local DB (optionally sorted by name or updatedAt).
getTemplate(id) – retrieve a single template by ID (if needed).
saveTemplate(templateData) – create or update a template. This should insert/update the local Drift noteTemplates table. If no ID is provided (new template), generate a UUID (you can use the existing Uuid().v4() or SupabaseNoteApi.generateId() for consistency). Set updatedAt = now() and deleted = false. After upserting locally, enqueue a pending operation for sync: e.g. call something like db.enqueue(templateId, 'upsert_note_template', payloadJson). The payload can include the template fields if needed, or you might not need a payload if the sync logic just pulls from the DB.
deleteTemplate(id) – mark a template as deleted (set its deleted flag true locally) and enqueue a 'delete_note_template' op for sync. (Since we use soft-delete, this could also be implemented via saveTemplate with a deleted flag, but a separate method is fine for clarity.)
duplicateTemplateToNote(templateId) – this is a special method to apply a template when creating a new note (more on this in step 4, but you’ll implement it here). It should load the template from local DB, then call the existing note creation logic with the template’s content.
You have a decision here: either integrate these into the existing NotesRepository or keep them in a separate service. Integration approach: You could extend NotesRepository with all the above methods (ensuring to use the same db and crypto instances). This has the advantage of reusing pushAllPending() and the sync pipeline. For example, NotesRepository.pushAllPending() can be modified to handle the new op types. If you go this route, you might not need a wholly separate TemplateService class – just add “template” methods to the repository. The plan even suggests either approach. Given the size of NotesRepository already, a clean approach is:
Create a TemplateService class that internally uses AppDb (for local ops) and possibly the NotesRepository (to create notes from templates). It can also accept a reference to the same CryptoBox or Supabase client if needed for encryption.
However, for syncing, you likely want to piggyback on NotesRepository.pushAllPending() to avoid duplicating sync loops. You can still enqueue ops via db.enqueue(...) from TemplateService, since the PendingOps table is shared. Then simply update pushAllPending() to recognize those ops.
Whichever way, ensure the PendingOps system knows about templates. Define new op kind strings like 'upsert_note_template' and 'delete_note_template'. In the repository’s pushAllPending(), add cases for these. For 'upsert_note_template': retrieve the template from db.noteTemplates by ID, encrypt its fields (use the CryptoBox – e.g., call encryptJsonForNote or a similar method, providing the userId and templateId as context). For example, encrypt the template’s name in one JSON (or as plain if you treat name like note title), and the rest of the fields in another JSON blob. Then call a Supabase API method (to be created in step 3) to upsert the encrypted template to the cloud. For 'delete_note_template': you can similarly call the API with an indicator that this template is deleted (or simply upsert with deleted=true). Once the API calls succeed, mark those ops as processed and remove them from the queue (just like existing note and folder ops)
GitHub
GitHub
. By handling template ops in the same pipeline, your existing sync schedule (SyncService.syncNow() etc.) will cover templates automatically. Also update the pull logic: add a fetchEncryptedTemplates(since) in the Supabase API, and in NotesRepository.pullSince (or a parallel in TemplateService) fetch remote templates updated since last sync, decrypt them, and upsert into local noteTemplates. If you prefer, you can do this in the same pullSince method after pulling notes and folders, or have TemplateService be called by SyncService separately. The end goal is that templates sync just like notes: offline edits queue up, and sync merges remote changes. Pay special attention to conflict resolution: because of the unique name constraint, if two devices create a “Meeting Notes” template offline, when both sync one might fail the unique constraint. You may need to catch that error – perhaps append “(1)” to the name or otherwise handle duplicate default names. This scenario might be rare (more likely with default templates seeding, see step 3), but it’s worth considering in tests. 3. Default Template Seeding: Provide a set of default templates for new users (and possibly localized versions for different locales). The plan is to include a JSON asset, e.g. assets/templates/default_templates.json, containing templates like “Meeting Notes”, “Daily Journal”, “Task Checklist” with their predefined content. Implement logic to seed these on a user’s first login
GitHub
. A good place to do this is after a successful sign-in or account creation, when the local database is empty. For example, in your authentication flow (maybe in main.dart or wherever you handle new user setup), you can check if the current user has any templates saved. The TemplateService could have a method ensureDefaultTemplatesSeeded(Locale locale) that loads the JSON and inserts templates if none exist yet. Be careful to run this only once per user. If using Supabase functions or triggers, you might also seed on the server side, but that can complicate localization. A simpler route: do it on the client:
Parse the default_templates.json (which could contain template definitions in multiple languages, keyed by locale).
Determine the user’s locale (or just use app’s current locale).
For each default template definition, call saveTemplate to insert it. Because these are new, they’ll get enqueued for sync. The Supabase unique index on name will prevent duplicates if the seeding runs twice, but you should still guard against multiple seeding on the client (perhaps store a flag in user preferences or check if any template exists before seeding).
If you want the backend to seed as well (for example, to ensure a user who signs in on Device B first also gets templates), you could write a Supabase Edge Function triggered on user sign-up or a nightly job to insert templates. The plan mentions possibly doing it via migration SQL or onboarding function
GitHub
. This is optional – many apps simply let the client handle initial data population. In either case, align the default templates on both sides (the backend should insert the same content the client expects). Note that if the backend seeds and the client also seeds on first login, you must avoid double-creating. The unique (name) index will throw an error in that case – the client code should catch a conflict and ignore it (or better, call a function to fetch existing templates first). Once seeding is done, you should see the default templates (e.g. “Meeting Notes”, etc.) in the Template picker UI for any new account. Don’t forget to localize the template content if needed – e.g. provide Turkish versions if your app supports TR. The seeding JSON could have entries for each language, or you ship only English by default unless locale is Turkish (as indicated by the plan). Test this by creating a fresh account and verifying the templates appear with correct titles/bodies
GitHub
. 4. Template to Note Duplication Flow: Enable creating a new note from a template. This is the core “use template” action. Implement the duplicateTemplateToNote(templateId) method in the TemplateService (or NotesRepository) to handle this. When called (with a specific template chosen by the user), it should:
Fetch the template from local DB (by ID).
Merge any template tags into a set (the template may have tags defined; if the user is creating the note in a specific context, you could also merge in context tags, but likely just use the template’s tags).
Prepare any metadata: The plan suggests adding a metadata field indicating the note’s origin, e.g. {'template_id': <id>, 'source': 'template'}
GitHub
. You can include this in the note’s encryptedMetadata or a similar property. This will allow tracking template usage and, if needed, filtering (for example, an “Inbox” smart folder could treat template-sourced notes specially, though likely they are just normal notes).
Call the existing note creation method. For instance, NotesRepository.createOrUpdate(title: ..., body: ..., tags: ..., metadataJson: {'template_id': ..., 'source': 'template'}). The title of the new note could default to the template’s name, or you might prompt the user for a title if the template is generic (some UX designs let you change the title after applying the template anyway). Often, templates contain body content and maybe a placeholder title like “<Project> Meeting Notes” that the user can edit.
After creating the note locally (which also enqueues it for sync), consider placing it into the appropriate location. The plan indicates routing to Inbox via IncomingMailFolderManager
GitHub
. If your app uses an “Inbox” folder to collect new notes (like notes from email, share extension, etc.), you likely want template-created notes to land there as well so they’re easily found. So, if you have a function addNoteToIncomingMail(noteId) or similar, call that for the new note (and handle any exceptions if that folder doesn’t exist). This step might simply tag the note or move it to a folder designated as Inbox.
Finally, navigate the UI to the new note’s edit screen (if not already there). In most cases, if the user is on a “New Note” screen and picks a template, they’re already editing it, so you may just populate the fields. But if the template is chosen from outside (say from a widget or an Inbox conversion), you should open the editor for that note.
The result is that using a template feels instant – the editor is populated with the template content (which the user can then modify as needed) and the note is saved just like a standard note. Make sure to treat the new note as a normal note in all respects (it will sync via the usual channels, etc., just with the additional metadata). This implementation should avoid any concurrency issues: it’s essentially a copy operation from Template -> Note. Also, because you’re calling the normal note creation, the encryption for that note is handled as usual (note: template content was stored encrypted on server, but once it’s in local plaintext, you create a note and it gets encrypted with that note’s key for syncing – this is fine). One more thing – if the template had checkboxes or other formatting in its body markdown, verify that the editor renders them properly once inserted (generally it should). Test the duplication thoroughly: create notes from each default template and confirm the new note has all the content and tags, appears in the Inbox, and has its source=template metadata. 5. User Interface – Template Picker Integration: Develop the UI components that allow users to choose a template when creating a note. There are a few places to integrate this:
In the Note Editor Screen: Add a UI control to invoke the template picker. For example, if you have a top app bar or a toolbar in the editor, you could add an icon (perhaps a document or template icon). Tapping it should open a bottom sheet or dialog listing available templates. Implement this Template Picker Sheet as per the plan
GitHub
: it should fetch the list of templates via a Riverpod provider (backed by listTemplates() from your service) and display each template’s name, maybe along with a short preview. Using flutter_markdown to render a preview of the template body is a nice touch – perhaps show the first couple of lines in smaller text under the name, so users recognize the template. Also consider allowing “favorite” templates to be marked: you might include a star icon on each item that the user can toggle. Favoriting could simply sort those templates to the top of the list, or you might maintain a separate list. (If you want to persist favorites across devices, you’d need to add a boolean field or a separate store; you can also keep it client-only to start.) In the picker, handle the case of no templates (maybe show a message “No templates yet – create one from a note”). When the user taps a template in the list, you have two possible UX flows:
If the editor is blank (new note just opened): Immediately apply the template to the editor fields. This means fill the title and body (and possibly set initial tags in the note model). You should probably prompt “Apply template? This will overwrite current content.” if the user already typed something to avoid accidental overwrite.
If you haven’t created a note record yet: Perhaps your “New Note” opens the editor and already created a note entry. In that case, applying the template will just update that note. If instead the user opens the picker from somewhere else (not likely – probably it’s from within editor), ensure you create the note.
In either scenario, after applying, consider closing the sheet and maybe flash a toast like “Template applied” for feedback.
From the New Note FAB (Quick Capture flow): This could enhance discoverability. If template suggestions are enabled (see step 7 about the settings toggle), intercept the FAB press. For instance, instead of directly creating a blank note, you could open a small modal with two options: “New Blank Note” and “From Template…”. This could be a simple AlertDialog with those options, or an extended FAB menu (SpeedDial). If using a dialog, on choosing “From Template”, you then present the Template Picker sheet; on “Blank”, proceed normally. Alternatively, a long-press on the FAB could open templates directly. Choose what feels natural – the plan specifically calls out “FAB flows” so the expectation is the FAB will facilitate template usage. A smooth approach is: single tap FAB -> goes to blank note editor (default behavior), long tap FAB -> opens template picker immediately. This way power users can directly jump to templates, and others won’t be bothered if they don’t use templates. Document this or make it intuitive via an onboarding tip if needed.
Quick Capture Widget / Other Entry Points: The plan also aims to integrate templates into the share extension and widget flows
GitHub
. For the home screen widget, one idea is to allow configuring a default template for the quick note button. For example, the widget could have a setting (in-app) that “Quick Note uses [Template X] by default.” Implementing that might be phase 2, but keep it in mind. The share extension is less straightforward for templates (since that’s triggered by external content), so you might defer that. But do ensure that if a note was created from a template via any means, it carries source: template in analytics.
As you build the UI, maintain consistency with the app’s design (Material 3 style). The template picker sheet could use a standard ListView with ListTiles or a more custom design if needed (with preview). Also ensure accessibility: e.g., the FAB long-press has a tooltip or the template list is readable with TalkBack/VoiceOver (the preview might be read as well). This step is mostly UI/UX implementation, tying into the service layer you wrote. 6. “Save as Template” Feature: Allow users to create a new template from an existing note’s content
GitHub
. In the note editing screen (probably in the overflow menu or a dedicated button), add a “Save as template” action. When triggered:
If the note is empty or very short, you might validate or ask for confirmation (since saving an empty template might not be useful).
Possibly prompt the user to enter a name for the template. By default, you could use the note’s title (or first line of body if title is empty) as the template name. The user can confirm or edit this.
Call TemplateService.saveTemplate with the gathered data. This will create a template record with the note’s body content, perhaps the tags (the plan says to include note title/body/tags, plus optional icon/color)
GitHub
. If you have note metadata like color or icon and want to save it, you’d need to extend template schema. Initially, you could ignore that or store it in the template’s description field.
After saving, provide feedback: maybe a SnackBar “Template saved!” and perhaps a quick link “Manage templates” that opens a template management screen (if you have one in settings).
Implementing this feature solidifies the template system by letting users grow their own library beyond the defaults. One edge case: if a user tries to save a template that has the same name as an existing one, your unique index in Supabase will cause a conflict on sync. To avoid that, either warn the user (check locally if name exists and append a suffix or ask them to rename), or handle the sync error gracefully by renaming server-side. Easiest is to prevent duplicates at creation. So do a quick check in listTemplates for any colliding name. This ensures a smooth experience and upholds the uniqueness invariant. 7. Settings Toggle and Template Management UI: Add a user setting to enable or disable template suggestions
GitHub
. In your Settings screen (perhaps under an “Advanced” or “Notes” section), include a toggle like “Enable Note Templates feature” or phrased in user-friendly terms. When off, the UI should not show template options – e.g., hide the FAB long-press behavior, hide the template picker button in editor, and possibly hide any template-related prompts. You’ll need to plumb this toggle into the UI logic (e.g., use a Riverpod StateProvider<bool> or similar, or read from SharedPreferences). Default might be on or off depending on whether the feature is considered beta. Given templates are listed as “upcoming” in capabilities, perhaps default it to on to promote usage. Just ensure that if off, templates are completely out of sight (power users can turn it on). Additionally, consider providing a way for users to manage templates outside of creating a note. This could be a simple list in Settings like “Manage Templates” that shows all templates (similar to the picker but perhaps with edit/delete controls). Users might appreciate the ability to edit template content or delete ones they no longer need. While the plan didn’t explicitly call out a full management screen (it focuses on picker and save-as), it did include delete and edit in testing scenarios
GitHub
. So, implementing at least deletion (maybe swipe to delete in the picker list or a long-press menu on a template item) is necessary. Editing a template could reuse the note editor screen: you could allow tapping a template in the manage list to open an editor preloaded with the template (and perhaps a label indicating you’re editing the template, not a note). Any changes saved there should call saveTemplate (with the existing ID, updating the template). This might be advanced, so at minimum ensure there’s a way to delete templates (with confirmation, since deletion is permanent across devices after sync). The settings toggle and any management UI reinforce that the feature is optional and under the user’s control, which is good for onboarding. 8. Analytics and Logging Integration: With the functionality in place, integrate analytics events and logging to observe usage. Define events as planned:
On using a template to create a note, fire an event like quick_capture.template_used (or a name following your AnalyticsEvents scheme). Include properties: template_id, maybe template_name, and entry_point (e.g. “editor” or “widget” to indicate where it was used). If you also track note creation events, you might piggyback or differentiate template-sourced notes.
On creating a new template (via “Save as template”), fire quick_capture.template_created with properties like template_id and perhaps a flag if it was from an existing note or from scratch.
If you implement template deletion or editing, you might track those as well (template_deleted, template_edited) – optional but could be useful to see if users curate their templates.
Use the AnalyticsService.event() method to log these, and ensure it’s called at appropriate places in the code (right after the action completes). For logging, use AppLogger to record important steps: e.g., logger.info("Template applied to new note", data: {"templateId": id, "noteId": newNoteId});. Also log errors: if applying a template fails for some reason, or syncing a template hits an error, log a warning or error with context. These logs (and Sentry breadcrumbs, if integrated via the logger) will help debug any issues in production. Finally, consider adding Sentry alerts or checks for template sync. For instance, if an encryption decryption fails for a template, that might be caught and logged. The monitoring plan in earlier phases may already cover general sync errors, so just verify that template ops go through the same error handling pathways (e.g., any caught exception in push/pull should mention the op type in the log so you can distinguish template sync failures). With all these steps, remember to run thorough testing as outlined. Write unit tests for TemplateService (creating, updating, deleting templates and duplicating to notes). Write a widget test for the template picker UI (e.g., simulate tapping a template and verify the note editor gets populated). Integration-test the full sync: create a template on device A, sync, ensure device B receives it and it appears in its picker; delete on B, sync, ensure A removes it. Test offline mode: create a template offline, it should queue and later sync up (with no data loss or duplication)
GitHub
. Also, test that turning off the feature hides the UI and doesn’t break anything (e.g., templates remain in DB but just not shown). By following this enhanced plan, you will implement Note Templates in a way that dovetails with DuruNotes’ existing architecture:
Using the NotesRepository/SyncService paradigm for consistency,
Preserving encryption and privacy for all user-generated template content,
Ensuring normal note operations remain unaffected (templates are an add-on, not a disruption),
Providing a smooth UI/UX that encourages using templates without forcing it,
And upholding the app’s standards for quality (with testing, analytics, and logging for observability).
This sequence (schema → service → sync → UI → settings → analytics → tests) should help incrementally build and verify the feature. Each part can be developed and unit-tested in isolation (e.g., get the schema and service working with some dummy UI to verify template save/apply, then integrate into the real UI). Keep the scope tight and avoid feature creep (like don’t try to add too many bells and whistles in v1). With this foundation, you can later iterate (perhaps adding template import/export, more template examples, etc.) confidently.
Modular Prompts
Below are Claude 4.1-friendly coding prompts for each major implementation task. These can be used in Cursor or another code assistant to generate boilerplate and expedite development:
Drift Schema and Migration:
In `lib/data/local/app_db.dart`, add a new Drift table called `NoteTemplates` with the following columns:
- id: Text, primary key
- name: Text, not null
- body: Text, not null (note content template)
- tags: Text, nullable (we will store JSON or comma-separated tags here)
- description: Text, nullable
- updatedAt: DateTime, not null
- deleted: Bool, not null with default false  
Also, create a Drift database migration to create this table. Ensure the migration is added to the migration logic so existing users’ databases get the new table. Write the Dart code for the Drift `NoteTemplates` table class and any updates to the `$AppDb` class (like adding `noteTemplates` to the list of tables). Don't forget to run `flutter pub run build_runner build` after writing the table to generate the companion. 
Supabase Template Table API:
Create a new Dart class `SupabaseTemplateApi` in `lib/data/remote/` (similar to SupabaseNoteApi). It should handle remote operations for the `note_templates` table:
- `Future<void> upsertEncryptedTemplate({ required String id, required Uint8List nameEnc, required Uint8List propsEnc, required bool deleted })`: This should upsert a row into the `note_templates` table on Supabase. The row should include `id`, `user_id` (use SupabaseClient.auth.currentUser!.id), `name_enc`, `props_enc`, `deleted`, and an `updated_at` timestamp (UTC now). Use `_client.from('note_templates').upsert(row)` to send it.
- `Future<List<Map<String, dynamic>>> fetchEncryptedTemplates({ DateTime? since })`: This should select `id, user_id, updated_at, name_enc, props_enc, deleted` from `note_templates` where `user_id == currentUser` (and if `since` is provided, `updated_at >= since`). It should then normalize the result so that `name_enc` and `props_enc` come through as `Uint8List` (similar to how SupabaseNoteApi._normalizeListOfMaps works). Return the list of row maps.
- `Future<Set<String>> fetchAllActiveTemplateIds()`: Similar to fetchAllActiveIds for notes, select all `id` where `deleted == false` for the user, and return a Set<String> of those IDs.
The class should likely have a reference to a SupabaseClient (passed in via constructor). If encryption keys are note-specific, we might reuse the note ID as context for templates as well. Write the skeleton of this `SupabaseTemplateApi` class with the described methods.
Template Service – CRUD Methods:
Implement a new class `TemplateService` (e.g., in `lib/services/template_service.dart`) responsible for managing note templates. The class should be initialized with dependencies similar to NotesRepository (probably the AppDb instance, CryptoBox for encryption, and SupabaseTemplateApi or SupabaseClient for sync). Provide the following methods:
- `Future<List<LocalTemplate>> listTemplates()` – query the local Drift `noteTemplates` table for all templates where deleted == false, sorted by name or updatedAt.
- `Future<LocalTemplate?> getTemplate(String id)` – fetch a single template by ID from the local DB.
- `Future<String> saveTemplate({String? id, required String name, required String body, List<String> tags = const [], String? description})` – create a new template or update an existing one. If id is null, generate a new UUID (you can use the same Uuid package). Insert or update the `NoteTemplates` table with the given data (set deleted=false and updatedAt = now). After the DB write, enqueue a pending operation: use `db.enqueue(templateId, 'upsert_note_template', payload: <maybe JSON string of template data>)`. (The payload could be jsonEncode({'name':..., 'body':..., 'tags':[...]}) if needed, or just an empty payload if the sync logic reads from DB.)
- `Future<void> deleteTemplate(String id)` – mark the template as deleted in local DB (set deleted=true and perhaps update updatedAt), then enqueue `db.enqueue(id, 'delete_note_template')`.
Ensure these use transactions if needed so that local DB and queue are consistent. If the CryptoBox is to be used for encryption, you might also prepare encrypted fields here to store in a separate column or metadata (optional – could also be handled during sync). For now, implement as described without encryption, we will integrate Crypto in sync.
Return appropriate values (e.g., saveTemplate returns the template’s id). Provide the Dart code for TemplateService with these methods (you can assume LocalTemplate is the Drift data class for noteTemplates).
Duplicate Template to Note (Service method):
In the TemplateService, add a method `Future<String> duplicateTemplateToNote(String templateId)` that creates a new note from a given template. Implement it as follows:
- Load the template by id from the local database (`db.noteTemplates` or via getTemplate).
- If not found or if it’s marked deleted, throw an error or return early.
- Prepare the new note’s content: determine a title and body. You can use the template’s name as the note title (or leave title empty if your notes derive title from first line). Use the template’s body as the note body.
- Gather the template’s tags (List<String>) if any. These will be applied to the new note.
- Create the note: call `NotesRepository.createOrUpdate(...)` (or `createNote`) to insert a new note with the above title, body, and tags. Also pass `metadataJson = {'template_id': templateId, 'source': 'template'}` so the note’s metadata records its origin.
- The createOrUpdate should return the new LocalNote (with an ID). Capture the new note’s ID.
- (Optional) If there is an Inbox or default folder mechanism, use IncomingMailFolderManager to add this note to the Inbox. For example, `incomingMailFolderManager.addNoteToInbox(newNoteId)` if such a method exists (handle any exceptions).
- Return the new note’s ID.
Provide the Dart implementation of `duplicateTemplateToNote` following these steps. Assume you have access to an instance of NotesRepository (perhaps passed into TemplateService or globally) to create the note. Make sure to enqueue sync ops as part of note creation (NotesRepository will do that internally).
Realtime Sync for Templates:
Modify the UnifiedRealtimeService (in `lib/services/unified_realtime_service.dart`) to listen for changes on the `note_templates` table. Specifically:
- Add a new enum value in `DatabaseTableType` for templates (e.g., `templates`).
- When creating the realtime channel (`_createChannel()`), call `_channel.onPostgresChanges(...)` for the `note_templates` table, similar to how it's done for 'notes' and 'folders'. Use a filter on user_id = current user’s id.
- In the callback, call `_handleChange(DatabaseTableType.templates, payload)`.
- Also create a new StreamController for template events (like `_templatesController`) and a public Stream getter if needed (similar to notesStream).
- In `_handleChange`, when table == templates, broadcast the change event on the templates controller stream.
- Update any initialization logic to include templates. For example, ensure that when a template event comes in (insert/update/delete), the app will respond by pulling new templates or updating the local DB. (You might decide to simply call `TemplateService.pullSince()` or directly apply the change to local DB in the callback.)
Provide the code changes needed in UnifiedRealtimeService to subscribe to `note_templates` and emit events. If there is similar code for notes, mirror that structure.
UI – Template Picker Bottom Sheet:
Implement a Template Picker UI in the note editor screen (`lib/ui/note_edit_screen.dart`). When the user taps a "Templates" button:
- Use `showModalBottomSheet` to open a list of templates. Create a widget (e.g., `TemplatePickerSheet`) that builds the content.
- In that sheet, obtain the list of templates via a Riverpod provider or by calling TemplateService.listTemplates(). Likely you have a provider like `templatesProvider = FutureProvider((ref) => templateService.listTemplates())`.
- Build a ListView of the templates. For each template, display its name and maybe a preview snippet of the body. You can use the `flutter_markdown` package to render a short preview: for example, `MarkdownBody(data: template.body.substring(0, 100))` for the first 100 chars (be careful to catch if body is shorter).
- If you implement favoriting: you could include an IconButton (star) on each list item, toggling a flag in the TemplateService or local storage. Favorited templates might be shown in a separate section or on top.
- Handle tap on a template item: When a template is selected, dismiss the bottom sheet (`Navigator.pop(context)`) and then apply the template. Since this sheet is in the editor context, you can call something like `context.read(templateServiceProvider).duplicateTemplateToNote(template.id)` or directly use TemplateService to get the template and populate the current note fields. However, since the note is already open, *do not create a new note* – instead, populate the current note’s controller/text fields. For example, set the title controller text to template.name (or leave existing title if user had one), set the body controller text to template.body, and maybe add template.tags to the note’s tag list (if your editor supports tagging on the fly).
- Optionally, prompt the user if the current note content isn’t empty: “Apply template will replace current content – continue?”.

Provide the Dart code snippet for the TemplatePickerSheet widget and how to integrate it in NoteEditScreen. You can stub out the actual provider call with sample data for clarity. Focus on the UI layout (ListView of templates with name and body preview) and the onTap handling to pass the template back to the editor.
UI – “Save as Template” Action:
Add a "Save as Template" feature in the note editor screen (`modern_edit_note_screen.dart`). This likely goes in the app bar menu (Overflow menu). Do the following:
- In the editor screen’s AppBar actions, add a new `PopupMenuItem` or IconButton labeled "Save as Template".
- When selected, trigger a function `_onSaveAsTemplate()`.
- In that function, gather the current note’s content: title, body, and tags. For tags, if the note has any (you might get them from NotesRepository or state).
- Prompt the user for a template name. E.g., show a `TextEditingController` in an AlertDialog where they can confirm or edit the default name (which could be the note’s title or "Untitled Template").
- Once confirmed, call `TemplateService.saveTemplate(...)` with the data. Use the note’s body as the template body, note’s tags as template tags, and the chosen name.
- Await the future to ensure it’s saved. On success, maybe pop a SnackBar: "Template saved." On failure (e.g., name conflict), show an error SnackBar.
- (Optional) If you want to navigate the user to a template management screen or directly into editing that template, you could do so, but generally just saving is enough feedback.
- Ensure that after saving, if the user syncs or logs into another device, that template is now available (the sync is handled by pending ops).

Provide the code changes in the note editor widget to add this menu item and the handler logic. Use pseudo-code for the dialog if needed, but show how to call `templateService.saveTemplate` with the current note’s data.
UI – New Note FAB Template Options:
Enhance the FAB on the main notes list screen (perhaps in `notes_list_screen.dart` or similar) to support template creation. We want: if templates are enabled (check the setting flag), allow the user to create a note from a template easily.
Implement one of two approaches (choose one in code):
**A)** Use a long-press on the FAB to open the template picker:
 - Detect long-press on the FloatingActionButton (you might wrap it in a GestureDetector or use the onLongPress callback if using FloatingActionButton.extended).
 - On long press, navigate to the note editor but immediately show the TemplatePickerSheet (as implemented earlier). Alternatively, show a dialog of template names.
 - When a template is chosen, you can either create the note in background then open it, or open the editor and apply the template. Simpler: perform `duplicateTemplateToNote` right away, get the new note ID, then navigate to the Editor screen for that note (so the user sees the pre-filled note).

**B)** Use a FAB submenu (Speed Dial):
 - When the FAB is tapped (or a FAB with a dropdown arrow), show two mini-fab buttons: one for "Blank Note" and one for "Template". The Template mini-fab opens the template picker.
 - (This approach might need a package or custom widget for a fab menu.)

For simplicity, implement approach A with long-press:
- Add an onLongPress handler to the FAB. Inside, use `showModalBottomSheet` to present the list of templates (you can reuse TemplatePickerSheet in this context too).
- When a template is selected from this sheet (since now we are not in an open editor), directly call TemplateService.duplicateTemplateToNote(templateId). Once it returns the new noteId, push the NoteEditScreen for that note (`Navigator.pushNamed(context, '/edit', arguments: noteId)` or similar).
- For normal tap (onPressed) keep the existing behavior (create a blank note or open empty editor).

Provide the code snippet to implement the FAB long-press behavior in the notes list screen. Include checking the user setting (e.g., if template feature is off, maybe long-press just does nothing or isn’t set). If possible, illustrate opening the TemplatePickerSheet and handling its result to navigate to the new note.
Analytics and Logging Hooks:
Integrate analytics and logging for template actions:
- In TemplateService.duplicateTemplateToNote (after successfully creating the note), call the AnalyticsService to log an event. For example: `analytics.event('quick_capture.template_used', properties: {'template_id': templateId})`. If you have a constant in AnalyticsEvents, add something like `static const templateUsed = 'quick_capture.template_used'` for consistency.
- In TemplateService.saveTemplate (after saving locally), log an event `analytics.event('quick_capture.template_created', properties: {'template_id': newTemplateId, 'from_note': someNoteIdOrFalse})`. The `from_note` property could indicate whether this template came from an existing note or was created blank (if you ever allow blank template creation).
- Also, use AppLogger to record these actions. For example, in duplicateTemplateToNote’s success: `logger.info('Note created from template', data: {'templateId': templateId, 'noteId': newNoteId});`. In saveTemplate: `logger.info('Template saved', data: {'templateId': id, 'name': name});`.
- Add logging for any errors: if an API call throws or encryption fails, use `logger.error('Failed to upsert template', error: err, data: {...})`.
- Don’t log sensitive info: avoid dumping the full template body or user content in logs. Template name and IDs are fine.

Provide code excerpts showing where you would insert these analytics and logging calls in the TemplateService methods (duplicateTemplateToNote and saveTemplate). Use the `AnalyticsFactory.instance` or similar to get the analytics, and `LoggerFactory.instance` for logger. Just show the event calls and logger calls in context.

Kaynaklar
Şunu dedin:
I dont really want to make mistake , this is a critical functionality. Do you need to see the real screens or you can understand the app from the sourcecode?
ChatGPT:
To help ensure this critical functionality is implemented flawlessly, I can go quite far by analyzing the source code you've connected via GitHub. That gives me access to architectural flow, UI composition, and data layer contracts.

However, seeing the real screens or mockups (especially for the note editor, FAB interactions, and template picker flows) would help refine UX decisions and avoid misalignments.

Could you let me know:

Do you have Figma files or screenshots of the New Note flow, editor, or settings screen?

Are there existing design constraints (e.g., minimum tap targets, Material 3 theming, animation patterns)?

Should templates be completely invisible if disabled, or just deprioritized?

Happy to work with whatever you can share, but those visuals could help tighten the design validation.

Şunu dedin:
Yüklenmiş görüntü
Yüklenmiş görüntü
Yüklenmiş görüntü
Yüklenmiş görüntü
Yüklenmiş görüntü
Yüklenmiş görüntü
Yüklenmiş görüntü
no but i can provide running app screens from my phone. so you can analyze the screenshots, and at the same time see the backend and the codebase. I need a well, production grade bug free prompts for this implementation please
ChatGPT:
Thanks for sharing the running app screenshots. With both the UI visuals and full backend + codebase access, I can confidently ensure that the Note Templates implementation matches real user flows, stays aligned with production-grade standards, and introduces zero regressions.

I’ll now begin refining the template prompts and UX interactions (e.g. FAB behavior, editor pre-fill, folder/tag context) based on these screens. I’ll share a complete Claude-ready, stepwise production prompt kit shortly.

Research completed in 14m· 25 kaynak· 23 arama
Template Integration Refinement for DuruNotes Based on UI Screens and Architecture

Integrating Note Templates: UX Refinements & Prompt Guide
UX and Interaction Refinements
Floating Action Button – Template Quick Actions
The My Notes screen of Duru Notes, featuring a blue circular FAB in the bottom-right for creating notes. Tapping the FAB currently expands into multiple mini-FABs for quick note types (Text, Checklist, Voice). The design uses a modern, Material 3 aesthetic with a blue accent for primary actions. We will integrate a template option here while preserving the clean layout.
Expanded FAB Menu: Leverage the existing FAB expansion pattern to include a “Note from Template” option. Currently, tapping the FAB reveals mini action buttons labeled Checklist, Voice Note, and Text Note
GitHub
GitHub
. Add a fourth mini-FAB (e.g. an icon like Icons.description or a document icon, colored with another accent from the theme) labeled “From Template”. This keeps the interaction consistent and discoverable – users tap the plus, then choose “From Template” to initiate the template flow. Upon tapping From Template, close the FAB menu (_toggleFab()) and open the template picker (see below).
Long-Press Shortcut (Optional): As an enhancement for power users, enable a long-press on the main FAB to directly launch the template picker sheet. This provides quick access to templates without needing the intermediate menu. If implemented, include a subtle tooltip or hint (e.g. “Hold + for templates”) to improve discoverability. Long-press should provide haptic feedback and then display the template selection bottom sheet immediately. Normal taps still show the expanded menu, ensuring no accidental triggers.
FAB Visual Feedback: Keep the FAB’s current rotation animation and tooltip. Update the main FAB’s tooltip to reflect multiple actions (e.g. still “Create Note” is fine, since template creation is a form of creating a note). Ensure the new From Template mini-FAB has its own tooltip (tooltip: 'New note from template') and a unique heroTag to avoid Flutter hero conflicts. All FAB buttons (main and mini) should have accessible labels (Flutter’s Semantics or Tooltip) for screen readers indicating their function, e.g. “New note from template” for the template button.
New Note Screen – Template Picker Integration
The Note Editor screen in Duru Notes, showing a minimalist UI with a back arrow, title “New Note”, and a Done/Save action. Below the app bar, folder and tag chips are present, and the first line of the text field acts as the title. We will introduce a template picker trigger here that blends into the clean, whitespace-focused layout.
App Bar Action: Introduce a Template Picker icon in the note editor’s top bar for new notes. In the ModernEditNoteScreen, the title “New Note” is flanked by an icon (edit/note icon) and the actions container (preview toggle, pin, save)
GitHub
GitHub
. For unsaved new notes (widget.noteId == null), add an icon button (e.g. Icons.library_books_rounded or a “template” sheet icon) to this action row. Tapping this opens the same template selection bottom sheet as from the FAB. This placement in the toolbar keeps the UI clean – no large banners or intrusive prompts – yet gives a visible affordance to apply a template if desired. Use a filled icon style to match Material 3 icons (similar weight as the existing preview/edit icons). Include a tooltip “Choose template for note” and a descriptive semantic label for accessibility.
Placeholder Prompt (Optional): To further guide users, you might include a subtle inline prompt in the editor for new notes. For example, if no text has been entered, a one-line hint above the keyboard or in the empty space could say “Or use a template to start”. This could disappear once the user starts typing. However, be cautious: the current design’s placeholder already says “Start writing your thoughts… Tip: First line becomes the title.” Adding too much text could clutter the whitespace-focused design. If using an inline prompt, style it similarly to the existing hint (gray, small font) and possibly make it a tappable text that opens the template picker. Keep it subtle to preserve the minimal feel.
Keyboard Handling: Ensure that invoking the template picker from the editor does not conflict with the on-screen keyboard. When the user taps the Template icon, first dismiss the keyboard (e.g. call FocusScope.of(context).unfocus()) so that the bottom sheet isn’t obscured or cramped by the keyboard. The bottom sheet should slide up from the bottom, and the transition should follow Material animation guidelines (300ms ease-out). After applying a template (see below), the keyboard can be re-focused on the editor if appropriate (e.g. place cursor at end of inserted content).
Prefilling Note Content from a Template
Seamless Prefill: When a template is selected, pre-populate the new note’s fields (title, body, tags) immediately, so the user sees a filled note ready for editing. If the template was chosen before entering the editor (via FAB or the New Note toolbar icon), pass the template data into the editor screen’s constructor. ModernEditNoteScreen already supports initialTitle and initialBody parameters
GitHub
, combining them into the text controller on init
GitHub
. Use the template’s title as initialTitle, the template content as initialBody, and push the editor screen. The note editor will then show the template content as if it were typed, with the first line as the title and the rest as body text.
In-Editor Injection: If the user opens a blank note and then selects a template via the toolbar icon, inject the content into the existing editor. For example, retrieve the template’s title/body and set the _noteController.text to "${template.title}\n${template.body}" (ensuring a newline between title and body) while the editor is open. Also, update the _initialText reference and _hasChanges flag appropriately so that the editor knows there are unsaved changes. This approach effectively mimics the behavior had the note been opened with that content. After inserting, consider moving the cursor to the end of the text (or start of body) and re-focusing the text field so the user can continue writing without disruption. Provide a short SnackBar or toast like “Template applied” for feedback, especially if the user had any existing text that was replaced.
Avoid Jarring the User: Apply the template content without full page reload or popping screens. The user should remain in the editor and simply see text appear. Use a smooth scroll or focus change if needed (for example, if the note was empty, the user might still be at the title field; after insertion, ensure the title is visible at top). If the note already had content, confirm with the user before overwriting (e.g. show a dialog: “Replace current note content with template?”). This confirmation is only necessary if non-empty content would be lost; if the note is truly new/empty, no prompt is needed.
Prefilling Tags: Templates may include suggested tags (the plan is to store tags with each template
GitHub
). Merge these into the new note’s tags seamlessly. If the note is created via template before the editor opens, pass the template’s tags to the tag management logic. You might extend ModernEditNoteScreen to accept an initialTags list, similar to initialFolder. On init, set _currentTags = initialTags and pass them to the NoteTagChips widget. If applying a template in an open note, call the tag chip component’s callback or state to add the template’s tags (ensuring no duplicates). The UI will then display those tag chips immediately. For example, if the “Meeting Notes” template has tags meeting and work, after selection the note’s tag chips section should show chips for “meeting” and “work” in addition to any user-added tags, with the same style and behavior as standard tags.
Metadata & Source: Mark notes that come from a template in their metadata for future reference. When creating the note, include a flag like metadata['source'] = 'template' and metadata['template_id'] = <id> as intended in the plan
GitHub
GitHub
. This doesn’t directly affect UI at creation time, but it enables showing a “template” indicator later and tracking analytics (quick_capture.template_used). Also consider automatically placing template-created notes into the user’s Inbox/Incoming Mail folder for visibility. The plan’s testing notes indicate template-generated notes should land in Inbox
GitHub
. Using the IncomingMailFolderManager, add the new note’s ID to the Inbox (unless the user chose a specific folder before). This way, if the user has an “Inbox” filter or badge (as shown by the Inbox chip with a badge on the My Notes screen), the new template note will appear there, consistent with other quick captures.
Indicating Template Origin in the Note Editor
“Saved from Template” Affordance: For notes created from a template, provide a subtle visual indicator of that origin in the editing view, similar to how folder and tag are displayed. The approach is to show a template chip in the header area of the editor. In the current UI, there is a row with the folder selector chip and the tag chips at the top of the content
GitHub
. We can insert a non-interactive chip here for template info. For example, if the note was based on the “Meeting Notes” template, display a small pill saying “Template: Meeting Notes”. Style this chip like the folder chip: same corner radius, font size, and primary color accent. The folder chip uses a filled container with primary color text and icon
GitHub
; the template chip can do the same with an icon like Icons.auto_awesome (a star) or a document icon to denote a template. Use a slightly different shade (e.g. primaryContainer with alpha) so it doesn’t overpower the content – consistency with the subtle gray/blue tones of other chips is key.
Placement and Behavior: Place the template chip to the left of the folder chip, if a folder is selected, or in that position if no folder. One layout strategy is a Row containing [TemplateChip, SizedBox(width:12), FolderChip, Expanded(Tags)]. If space is tight (e.g. many tags), the chips might wrap or truncate; to handle this, ensure the Row can overflow to multiple lines or that the Template chip is brief. Typically template names should be short (“Daily Journal”, etc.), but if long, consider truncating the text in the chip. The chip should not steal focus or behave like a button – it’s purely informational. However, for accessibility, you can give it a content description like “Note created from template: {TemplateName}” so screen readers announce it. If in the future a “view template” action is desired, this chip could become tappable, but for now it remains static.
When to Show: Only display the template chip if the note has a template origin. Determine this by checking the note’s metadata (e.g. note.metadata['template_id'] exists) or, for unsaved new notes created from template, by carrying that info in the state. For instance, if ModernEditNoteScreen receives a templateId or templateName along with initial content, store it in a state variable. On saving, that info will be persisted in the note’s metadata via the createOrUpdate call
GitHub
. When the note is later opened for editing (with a real noteId), you can fetch its template ID from the database (possibly via an extended getNote or a join with templates table) and then display the chip. This means adding a small lookup in _loadNoteMetadata() for template info, similar to how tags and pin state are loaded
GitHub
GitHub
. Because this feature is subtle, it should not clutter the UI for regular notes – ensure it’s absent for notes without template origin or if templates feature is disabled.
Templates in Settings and Navigation
Settings Toggle: Provide a master switch in Settings to enable or disable template functionality
GitHub
. This gives users control if they prefer not to see template options. In the Settings screen, under an appropriate section (perhaps “Notes & Quick Capture” or a new “Templates” section), add a toggle (e.g. a SwitchListTile or custom IOS-style toggle) labeled “Enable Note Templates”. When off, the UI should hide template-related elements: e.g. the FAB’s template option, the template icon in the editor toolbar, and any template suggestions. When on, those features become active. This toggle should be persisted (likely in local settings or user preferences). Default could be on, especially if you seed default templates, but some users may turn it off for simplicity.
Manage Templates Interface: Since users can create and customize templates, offer a “Manage Templates” entry point. The navigation could be via Settings or the overflow menu on the main notes screen. To maintain a clean main UI, a good approach is to locate it in Settings (perhaps below the toggle). For example, a Settings list tile: “Manage Templates” which navigates to a dedicated Template Management screen. This screen would list all user templates (using TemplateService.listTemplates()), allow creating new templates (perhaps by tapping a FAB in that screen or an “Add Template” button), renaming or deleting templates, and marking favorites. It should use the same app design (AppBar with back, etc.). If preferred, an overflow menu item on the main screen (next to Settings, Help, etc.) could directly open this Manage Templates screen for quicker access
GitHub
GitHub
. For example, add a menu item “Templates” in the overflow; this would be analogous to the existing “Tasks & Reminders” entry.
Consistent Design in Settings: In the Settings screen, follow Material 3 styling for the new elements. Use clear wording – e.g., the toggle’s subtitle can read “Show template options when creating notes” to clarify its purpose. If using a card-based section, include an icon (perhaps the same template icon) for visual consistency with other sections. Ensure high contrast for text and that the toggle is focusable via TalkBack/VoiceOver. The manage templates list can reuse list styles from elsewhere in the app (like the folder list design) to display template names and perhaps a description preview. Each row should have an edit/delete action (swipe actions or trailing icons) to modify templates.
No Overcrowding the UI: It’s important that adding template features doesn’t overwhelm new users. By keeping the management in Settings and gating visibility with a toggle, the primary note-taking experience stays as simple as before for those who aren’t interested in templates. Defaults like three pre-seeded templates (Meeting Notes, Daily Journal, Task Checklist as planned
GitHub
) can be provided so users immediately see value when they do enable the feature. These default templates should be localized and user-editable. If templates are enabled by default, consider a brief in-app tooltip on first run like “New! Use note templates for common formats” pointing to the FAB or template icon, which can be dismissed.
UI Prompt Blocks (Claude 4.1)
Below are structured prompt instructions for an AI (Claude 4.1) or developers to implement specific UI pieces of the Note Templates feature. Each block is self-contained, focusing on a particular component:
FAB Behavior – Template Quick Note Option
You are the Flutter UI developer extending the Floating Action Button menu on the “My Notes” screen to support note templates. Enhance the existing FAB “speed dial” to include a new **Note from Template** action, with a focus on clean design and intuitive interaction.

TASKS:
1. **Add Template Mini-FAB:** In `notes_list_screen.dart`, define a new mini FAB button in the expanded FAB menu (similar to Checklist/Voice/Text). Use an appropriate icon (e.g. `Icons.description_rounded`) and label “From Template”. Color it with a distinct but harmonious ColorScheme color (e.g. secondaryContainer or another accent) so it stands out but fits the palette.
2. **Hook Up Action:** When the user taps the “From Template” mini-FAB, first call the existing `_toggleFab()` to collapse the menu (providing a light haptic feedback). Then trigger the template selection UI. Implement this by showing a modal bottom sheet (see Template Picker below) or navigating to a template picker screen. Ensure the FAB closes smoothly before the sheet appears (consider a short delay or calling sheet within `setState` after collapse).
3. **Long Press (Advanced):** Implement a long-press handler on the main FAB that opens the template picker directly. Use `InkWell.onLongPress` or GestureDetector on the FAB. Provide `HapticFeedback.mediumImpact()` on long press. This should bypass the expanded menu and go straight to template selection. Make sure this doesn’t interfere with the single-tap (the tap should still expand the menu as normal).
4. **Accessibility & Feedback:** Update tooltips and semantics. The main FAB retains tooltip “Create Note”. For the new mini-FAB, set `tooltip: 'New note from template'`. Verify that screen readers announce the menu and new option properly (the mini-FAB labels are already visible text, which is good for accessibility:contentReference[oaicite:21]{index=21}:contentReference[oaicite:22]{index=22}). The long-press action should also have a brief descriptive feedback (you might show a SnackBar like “Template chooser opened” for visibility, though not strictly necessary).
5. **Visual Consistency:** Follow Material 3 guidelines for FABs. The mini-FAB’s text label should use the same style as existing ones (see `_buildModernMiniFAB` for label styling:contentReference[oaicite:23]{index=23}:contentReference[oaicite:24]{index=24}). The new icon should be 20px and white (since the FAB small uses `onPrimary` for foreground). Ensure spacing between FABs remains equal (they use SizedBox(height: 12) between items). Test that the FAB menu scrolls or not needed – if 4 items are too tall for small screens, consider making the sheet scrollable or using a scrollable FAB menu container.
Template Picker Bottom Sheet UI
You are implementing the **Template Picker** as a modal bottom sheet in Flutter, following Material 3 design and optimizing for usability in Duru Notes.

TASKS:
1. **Design Modal Sheet:** Create a new widget (e.g. `TemplatePickerSheet`) to be shown via `showModalBottomSheet`. It should cover a good portion of the screen (use `isScrollControlled: true` for full-height if needed) with a rounded top corners shape. The sheet’s background uses `colorScheme.surface` with elevation (to stand out from the dimmed backdrop), or wrap in a `Container` with BoxDecoration to achieve a pill shape similar to the folder picker:contentReference[oaicite:25]{index=25}.
2. **Sheet Header:** At the top, include a pull-handle indicator (a small rounded rectangle) for affordance. Below it, add a title like “Choose Template” in a bold Text (use theme.textTheme.titleMedium). If there are many templates, consider a search icon or filter, but initially keep it simple. If implementing favorites, you might add a toggle or segment control (e.g. “All / Favorites”).
3. **Template List:** List available templates in a ListView. Each template can be represented by a ListTile or custom row: **icon + template name + optional description**. Use an icon to denote templates (perhaps `Icons.article_rounded` or a custom template icon). If a template is marked as favorite, show a star icon on that row. For each item, also display a short preview of the content – for example, a second line of text in a lighter style showing the first few words or a summary. You could use `flutter_markdown` to render a snippet if the templates contain Markdown formatting:contentReference[oaicite:26]{index=26} (e.g., italic or bullet in the preview).
4. **Interactions:** Tapping a template item should immediately create a new note from that template. Implement onTap to pop the sheet (`Navigator.pop(context, template)`) returning the selected template object. The calling code (either from FAB or editor) will handle using that template to populate the note. Also allow the sheet to be dismissed with no selection (tapping outside or a Cancel button if you provide one). Ensure the back button on Android closes the sheet rather than the whole app.
5. **Favorites (Optional):** If templates can be favorited, include a star toggle on each list item. Tapping the star marks/unmarks favorite without closing the sheet. Favorites could be sorted on top or in a separate section. Use a filled star icon for favorite (primary color) and outlined star for normal, with appropriate semantics labels (“Mark as favorite template”).
6. **Empty State & Scroll:** If no templates exist (unlikely if default templates are seeded, but handle anyway), show a friendly empty state message like “No templates yet. Create a new template from a note.” Possibly provide a shortcut button here to go to “Manage Templates”. Make sure the sheet is scrollable if content exceeds screen height, but also not too tall if only a few templates (use `DraggableScrollableSheet` for a nice effect, or just constrain height). Test on different device sizes for usability.
7. **Theming & Aesthetics:** Match the app’s aesthetic: use the app’s primary color for active elements (e.g. highlight selected or focused item, favorite stars). The text and background should adapt to light/dark themes (e.g., for dark mode use surface color and onSurface for text accordingly). Maintain high contrast for readability. Follow Material 3 modal bottom sheet specs – e.g., default vertical padding and list item ripple effects. The sheet appearing should use the standard animation (slide up and fade in). 

Accessibility: Each template row should be a a11y focusable node reading the template name (and maybe “favorite” state). The sheet as a whole should be announced as a dialog; set `semanticsLabel` on the container like “Template selection, swipe up to choose”. Ensure that when the sheet opens, focus moves to it (Flutter does this by default for modal bottom sheets).
Note Editor – Applying Template Content Logic
You are implementing the logic to inject template content into the note editor once a template is chosen. Focus on correctly populating the text field, title, and tags, without disrupting the user’s editing flow.

TASKS:
1. **Navigation Path 1 – New Note via Template:** When the user selects a template from outside the editor (e.g. FAB -> template picker), instantiate the editor with template data. Modify the `Navigator.push` call for creating a new note to pass `initialTitle`, `initialBody`, and possibly `initialFolder`/`initialTags`. Example: 
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ModernEditNoteScreen(
    initialTitle: template.title,
    initialBody: template.body,
    initialFolder: inboxFolder, // if routing to Inbox by default
    // initialTags: template.tags (if you add this parameter)
  ),
));
Ensure the ModernEditNoteScreen uses these to pre-fill the TextEditingController
GitHub
 and tag list. The user should see the note already filled out upon entering.
2. Navigation Path 2 – In-Editor Template Selection: If the editor is already open and empty, and the user taps the template icon (from the app bar), handle the returned template. Use the _noteController to insert text: combine template title and body with a newline. For example:
final content = template.title + "\n" + template.body;
_noteController.text = content;
Then call _noteController.selection = TextSelection.collapsed(offset: content.length) to move cursor to end. Also update _initialText and set _hasChanges = true so that the Save/Done button enables. For tags, update the _currentTags list in state by merging template.tags. The NoteTagChips widget will rebuild and show the new tags. Call setState after these changes to refresh UI.
3. Replacing Existing Content: Decide how to handle if the user had already typed something. The simplest approach is to confirm before overwriting. Implement a confirmation dialog if _noteController.text is not empty (and not just whitespace). Dialog: “Apply template? This will replace the current note content.” with Cancel/Apply. If confirmed, proceed to set the text and tags as above. If the note was truly empty, skip confirmation.
4. Maintaining Title/Body Structure: Since Duru Notes uses a “unified field” where the first line is the title
GitHub
, ensure that the template content respects this format. The template’s first line should serve as the note’s title (the user can edit it afterward). If a template’s content already contains newlines (e.g. a multi-line body), our insertion logic (title + '\n' + body) is correct. Just make sure not to introduce extra blank lines at the start or missing newline after title. Trim any trailing newline from template title to avoid a blank title line.
5. Tag Injection: If using an initialTags parameter approach, handle it similarly in both paths – pass template tags list to the editor. If not, for in-editor injection, directly call the method to add tags. The NoteTagChips has an onTagsChanged callback that updates _currentTags
GitHub
. You can reuse that: for each tag in template.tags, if it’s not already in _currentTags, add it and then call the callback or directly call setState to update _currentTags. This ensures UI chips update. Preserve tag case or apply normalization as in backend (the trigger normalizes to lowercase, but UI can show as entered).
6. Post-Apply Focus and UX: After populating the template, ensure the note editor remains user-friendly. For a newly opened note, auto-focus the content so keyboard comes up ready to type (Flutter’s autofocus or a delayed focus on _contentFocusNode). For in-editor injection, after setting text, you may need to refocus the text field if the focus was lost due to the modal sheet. Call _contentFocusNode.requestFocus() to bring the cursor back. Scroll if needed so that the start of the content is visible (especially if a long template was inserted – you might use a short scroll animation to bring the top into view).
7. Data Integrity: Mark the note’s metadata as coming from a template. If you have the templateId, store it in the note’s metadata field (encrypted or plain as per app design). This will be saved when the user taps Save. Also, if template tags were added, they are now part of the note’s tags; nothing further needed except the UI already reflects it. Test the entire flow: choose template, see content and tags appear, modify something, save note, and verify the note is created with correct title/body/tags in the database. Edge cases: handle when user cancels template selection (do nothing), and when a template with a very large content is applied (the text field should handle it, but test performance). Ensure no crashes if template content is empty (though templates will have something).

### “Save as Template” Overflow Action
```text
You are adding a **Save as Template** feature in the note editor, allowing users to save the current note’s content as a reusable template.

TASKS:
1. **Overflow Menu UI:** In `ModernEditNoteScreen`, introduce an overflow menu (3-dot menu) in the app bar if not already present. For example, use `PopupMenuButton` in the NavigationToolbar or AppBar actions. Add a menu item labeled “Save as Template” with an icon (perhaps `Icons.save_as_rounded` or `Icons.content_copy`).
2. **Show for Existing Notes:** This action should primarily be available when editing an existing note (`widget.noteId != null`), as saving a template implies the note is already written. If the note is new and unsaved, you could decide to allow it (in which case, it should first save the note, then create the template). To start, simplest: show the menu item only for `noteId != null` (existing notes). Disable or hide it for new unsaved notes to avoid confusion.
3. **Template Save Flow:** When the user selects **Save as Template**, prompt for confirmation or additional info if needed. At minimum, confirm the action via a dialog: “Save this note as a template?” with “Save” and “Cancel”. If the note’s title should become the template name, you can use it directly. Optionally, allow the user to edit the template name in this dialog (prefilling the note title). For now, using the note’s title is fine – ensure a default if title is empty (e.g. “Untitled”).
4. **Create Template:** Invoke the TemplateService/NotesRepository to save the template. For example, call a method `saveTemplate(name, body, tags)` on a repository. Implement this to insert into the local `NoteTemplates` Drift table and sync to Supabase. Include the note’s full body (which already contains title in first line format, but for template storage you might want to store title and body separately). Also gather the note’s tags via `getTagsForNote(noteId)` so you can store them with the template:contentReference[oaicite:30]{index=30}. This operation should be asynchronous – show a small loading indicator or disable interactions while saving.
5. **Feedback:** On success, dismiss the dialog and perhaps show a SnackBar: “Template saved” (with template name). The new template should immediately be available in the Template Picker. You might proactively update the in-memory template list (e.g. call `TemplateService.listTemplates` or maintain a provider that the picker uses). On failure, show an error SnackBar.
6. **Prevent Duplicates/Trimming:** Optionally, trim the content for the template (remove any trailing empty lines) so the template is clean. Check if a template with the same name exists – you might warn or automatically rename (e.g. “Meeting Notes (2)”). The Supabase table enforces unique names per user ignoring case:contentReference[oaicite:31]{index=31}, so handle that collision (the save could fail if name exists). E.g., if `.saveTemplate` throws an error for duplicate, catch it and inform user.
7. **UI Consistency:** The overflow menu should follow Material 3 style (the app likely already has similar menus). For example, use `PopupMenuItem` with a ListTile child (icon + text) as seen in the notes list menu:contentReference[oaicite:32]{index=32}:contentReference[oaicite:33]{index=33}. Use localization for the text “Save as Template” (add to `app_en.arb`). The icon should be visible and match the weight of others. Ensure the menu is accessible: the menu button has a tooltip “More options” and the menu items are readable by screen readers by default.
8. **Post-Save Behavior:** After saving as a template, remain on the note editor. There’s no need to navigate away – the user can continue editing the note itself. If they make further changes and want to update the template, they’d have to save again as template (there’s no auto-link between note and template). This one-time copy should be clearly communicated (perhaps in documentation or a help tip). 

Testing: create a note, save as template, then create a new note from that template to verify content and tags carry over. Also test saving as template, then editing the note more and saving again (should create a separate template or override? – likely separate entry unless you decide to match names and override, but that’s an edge decision). Default to creating a new template entry each time for simplicity.
Template Origin Chip in Editor
You are implementing a subtle indicator in the note editor UI to show when a note was created from a template, without disrupting the minimal design.

TASKS:
1. **Determine When to Show:** Introduce a field in the editor state (e.g. `_templateName` or `_templateOrigin`) that holds the template reference if applicable. Set this when opening the editor:
   - If opening a note via template (new note flow), you know the template’s name/id – pass it into `ModernEditNoteScreen` (add a param like `templateName` or keep the id to lookup name).
   - If opening an existing note (`noteId != null`), fetch its template origin in `_loadNoteMetadata()`. Extend the notes repository to provide the template name if `note.metadata['template_id']` exists. This might involve a join on the `NoteTemplates` table or storing the template name in metadata at creation time. Simpler: store template name in note.metadata when creating from template, so you don’t need a join. If you find a template origin, update `_templateOrigin = thatName` in state.
2. **UI Placement:** In the build method for the editor header (the area with folder and tags chips:contentReference[oaicite:34]{index=34}), insert a Template chip if `_templateOrigin` is not null. Structure: If a template origin exists, build a chip widget before the folder chip. Use a similar style to `_buildFolderIndicator`:contentReference[oaicite:35]{index=35} but slightly different icon:
   - Container with padding (horizontal 12, vertical 8), rounded corners 12dp.
   - Border and background: you can use the same color as the folder chip (primary with alpha). Perhaps use `colorScheme.tertiaryContainer` for a distinct look, or stick to primaryContainer with low opacity for subtlety.
   - Inside Row: an Icon (maybe `Icons.auto_awesome` (star) or `Icons.content_copy`), size ~16, color `colorScheme.primary` (or a chosen accent). Then a Text “Template: <Name>” in medium weight, fontSize ~14, color `colorScheme.primary`. No dropdown arrow for this chip (it’s not interactive).
3. **Interactions:** Make this chip read-only. Wrap it in a Material/InkWell without onTap (so it’s focusable but does nothing) or simply a `Container` with text if focus behavior isn’t needed. If you do want to allow a tap in future (e.g. to view template details), you could add a tooltip “Originated from template” but that’s optional. For now, ensure it doesn’t conflict with tapping the folder chip or tags (adjust spacing as needed; e.g. give 8px padding between chips).
4. **Responsiveness:** If the screen width is small and adding another chip causes overflow, the chips row might wrap to a second line (which is acceptable). The `NoteTagChips` likely handles overflow of tag chips by scrolling or wrapping internally. Test with a scenario: a note from template with a folder and multiple tags – ensure the layout is still legible. If needed, allow the Row to wrap (you might use `Wrap` widget instead of Row for the chips section so that it naturally flows to new line). Maintain the visual order: Template (if present), Folder, then Tags.
5. **Style Consistency:** Match the visual style to existing chips so it looks like part of the same family. The folder chip has an icon and text tinted in primary color:contentReference[oaicite:36]{index=36}; do the same for template chip but you might use a different icon to differentiate visually at a glance. The tag chips are usually displayed differently (possibly as distinct chips with their own remove icons), but since this template chip is similar in function to the folder indicator (metadata about the note), styling it like the folder chip is appropriate.
6. **Translation & Accessibility:** If the app is localized, add a string for “Template: %s” or just the word “Template”. Screen readers should announce this chip. Provide a `Semantics(label: "Template origin: ${templateName}")` on the container. Because it’s not interactive, ensure it’s not focusable by default (so it doesn’t confuse keyboard navigation). If using an InkWell without onTap, set `focusColor` transparent or disable focus.
7. **Testing & Edge Cases:** 
   - Open a note that was created from a template, verify the chip shows the correct template name. 
   - Open a note not from a template, ensure no blank space or chip is shown. 
   - Create a new note from a template, check that the chip appears as soon as the editor opens (you can set the state in init). 
   - Save a new template-based note, then edit it again from the list – the chip should still show (since metadata persisted). If a user deletes that template later, decide what to do: likely still show the name (the note metadata might be the only record). That’s fine – the note still “came from” that now-nonexistent template. No need to remove the chip if template is deleted; treat the name as historical info.

By implementing this subtle indicator, we give users context without any manual effort. It complements the folder and tag indicators, fitting right into the existing blue-accented chip style.
Accessibility & Material 3 Considerations
Color Contrast & Theming: All new UI elements (FABs, chips, icons, text) should maintain sufficient contrast with the background. Duru Notes uses Material 3 color scheme – use colorScheme.primary, onPrimary, surface, etc., to ensure colors adapt in light/dark modes. For example, the template FAB and chip use the existing theme colors so they automatically match the blue-accented aesthetic and meet contrast guidelines (the folder chip style with primary text on a light container meets a11y contrast on both light and dark backgrounds). Avoid purely decorative or low-contrast colors for important text.
Touch Targets: Follow Material 3 minimum touch sizes (48x48 dp). The new mini-FAB and icon buttons already satisfy this (the FAB small plus padding). The template chip is large enough to read; even if it’s not interactive, its tap target should be similar to chips (for consistency if a user does tap it inadvertently). Spacing between chips prevents accidental taps on the wrong chip.
Screen Reader Labels: Provide semantic labels for all interactive elements:
The new From Template FAB button has a visible label, which helps, but also set a content description if needed (Flutter’s Tooltip takes care of some announcements). Verify TalkBack reads “From Template – button”.
The template picker sheet should announce itself. Use Semantics or the showModalBottomSheet barrierLabel for context like “Template selection dialog”.
Each template in the list should be a ListTile with proper text – TalkBack will read the title and possibly description. If you include a favorite star toggle, ensure it’s labeled (e.g. “favorite template, unchecked”).
The Save as Template menu item text will be read by accessibility by default (just ensure it’s in the localization files so it’s not missing).
The Template origin chip should have a label as mentioned (e.g. “Note created from template: Meeting Notes”). Because it’s not focusable, screen readers might only catch it when reading through content – consider wrapping it in a Semantics widget set to container:true so it’s read with the rest of the header information.
Keyboard & Navigation: Although this is a mobile app, ensure that using a hardware keyboard or D-pad can navigate the new elements. The template picker should trap focus while open (Flutter handles modal focus, but test that pressing Tab or arrow keys on a connected keyboard can focus list items and close the sheet with Esc/Back). The Back button (system navigation) should close the sheet and dialogs gracefully (we handle that by using standard modal sheet and dialog APIs).
Animations & Transitions: Use Material 3 recommended motion. The FAB to mini-FAB expansion is already animated (rotation plus mini FAB slide-up) – adding one more mini-FAB should still animate in sequence. The bottom sheet appears with a slide; ensure no jank by perhaps closing the FAB menu first (to avoid animating two things at once if that causes dropped frames). The transitions should be smooth at 60fps. Provide slight haptic feedback for key actions (the app already uses HapticFeedback.lightImpact() on FAB toggle
GitHub
 – continue this for long press and template selection to acknowledge the action).
Material 3 Components: Adhere to M3 component usage:
FABs and Extended FABs – use Flutter’s FloatingActionButton and .extended as in code for consistency.
Modal Bottom Sheet – use showModalBottomSheet with proper theming (the app might have ThemeData adjustments for bottomSheet shape).
Outlined icons and filled icons – the app uses rounded icons (e.g. Icons.add_rounded); pick the rounded variants for consistency.
Text styles – use the app’s textTheme for labels (as seen, labelMedium, titleMedium, etc.) to ensure typography is consistent.
Testing Accessibility: Manually test with TalkBack/VoiceOver turned on. Navigate to create a note from template using voice commands and ensure all steps are announced (e.g. “double tap to choose template” on the FAB’s long press might need a custom hint since long press isn’t easily discoverable via screen reader – so it’s okay if that’s considered an extra feature for sighted users; the primary path using taps is accessible). Also test with larger font sizes (“Largest” in accessibility settings) – the chips and FAB labels should accommodate (the chips row might wrap an extra line, which is acceptable). All icons should have tooltip text for accessibility (Flutter links tooltips to semantics by default, but verify).
By addressing these points, the Note Templates feature will integrate seamlessly with Duru Notes’ modern design while being usable by all users and compliant with Material 3 guidelines. The result is a powerful yet elegant addition: users can quickly start notes from templates, and the app retains its clean, intuitive interface. Sources: Implementation plan for Note Templates
GitHub
GitHub
, Duru Notes codebase (FAB menu
GitHub
GitHub
, editor UI) and Material Design guidelines.

Kaynaklar
Şunu dedin:
is the prompts cover backedn and middleware too? i need full stack prompt set please
ChatGPT:
GPT-5 Pro talebi
Reasoned for 9m 2s
Absolutely—here’s a full‑stack, production‑grade prompt set that covers Drift (SQLite) + Repository + Sync/Middleware + Supabase edge bits + Analytics + Tests + UI for Note Templates.
It aligns with your Implementation Prompt (single notes table, noteType flag, encrypted metadata propagation, centralized filtering, FTS exclusion, seeding, Riverpod providers, ModernEditNoteScreen entry points, etc.). It also respects your offline‑first + E2E encryption guarantees and existing modules (CryptoBox, AppDb, NotesRepository, SyncService, NoteIndexer, providers).

How to use: Paste each block into Cursor/Claude (one at a time), let it write code, then run the acceptance checks under each step before moving on.

0) Pre‑flight guardrails (paste first)
You are updating Duru Notes. Hard constraints:

- End-to-end encryption: note content + props go through CryptoBox on the client; the server stays blind to content/props. Do not add server-side plaintext columns for template fields. Use our existing CryptoBox + KeyManager. 
- Offline-first: every write goes to Drift first and enqueues a PendingOp; SyncService push/pull reconciles later. Never block UI on network. 
- Centralized filtering: everywhere we list “regular notes” we must filter out templates via a single predicate (avoid copy-paste WHEREs).
- Zero regressions: pagination, search, smart folders, shortcuts, inbox badge, and bulk actions must not see template rows.

Primary modules to respect: 
- Crypto: lib/core/crypto/crypto_box.dart (client-only encrypt/decrypt JSON/strings). 
- Local DB: lib/data/local/app_db.dart (LocalNotes, PendingOps, tags/links, migrations).
- Notes repo/sync: lib/repository/notes_repository.dart + lib/repository/sync_service.dart.
- Indexer: lib/core/parser/note_indexer.dart.
- UI editor: lib/ui/modern_edit_note_screen.dart and notes list FAB entry points.

Before coding, scan the repo to confirm file structure and imports exist; only then modify.
Why these guardrails: CryptoBox derives per‑note keys and encrypts JSON payloads; we must extend metadata, not the server schema.
Drift currently defines LocalNotes, PendingOps, tags/links, and common queries that exclude deleted notes; we’ll extend these carefully.
Indexer parses tags/links from the unified text; we will short‑circuit it for templates. 
Sync and providers exist and should be reused for push/pull + UI. 

1) Data model & Drift migration (schema v10)
1A. Add enum + column
GOAL: Introduce `NoteKind { note, template }` and a non-null `note_type` column with default 'note' into LocalNotes.

CHANGES:
1) Create `lib/models/note_kind.dart` with:
   enum NoteKind { note, template }
   extension NoteKindX on NoteKind {
     String get db => this == NoteKind.note ? 'note' : 'template';
     static NoteKind parse(String? v) => v == 'template' ? NoteKind.template : NoteKind.note;
   }

2) In `lib/data/local/app_db.dart`:
   - Add a new `TextColumn get noteType => text().withDefault(const Constant('note'))();` to LocalNotes.
   - Bump `schemaVersion` to **10**.
   - Extend `MigrationStrategy.onUpgrade` with:
     if (from < 10) {
       await m.addColumn(localNotes, localNotes.noteType);
       // backfill any NULLs defensively (older dbs)
       await customStatement("UPDATE local_notes SET note_type = 'note' WHERE note_type IS NULL;");
     }

3) Regenerate Drift:
   dart run build_runner build --delete-conflicting-outputs

ACCEPTANCE:
- App launches on an existing device; DB migrates without data loss.
- New `LocalNote` data class exposes `noteType`.
- `allNotes()` and other read paths continue to return previous notes (all default to 'note').
(Your AppDb currently defines LocalNotes, versioned migrations, and helper queries—extend those surgically.)

1B. Centralized predicate for “real notes only”
In `lib/data/local/app_db.dart`, define:

boolExpression noteIsVisible(GeneratedColumn<bool> deletedCol, GeneratedColumn<String> noteTypeCol) =>
  deletedCol.equals(false) & noteTypeCol.equals('note');

Replace all local note listings that currently do `deleted.equals(false)` to use `noteIsVisible(localNotes.deleted, localNotes.noteType)`.

Include:
- allNotes()
- searchNotes()
- suggestNotesByTitlePrefix()
- distinctTags(), notesWithTag(), backlinksWithSources() joins (when returning notes)
- any other list/select helpers

ACCEPTANCE:
- Grep for `deleted.equals(false)` and ensure every “note listing” also filters `noteType == 'note'` via the helper (except explicitly requested template lists).
(The current allNotes()/search/suggest functions already filter on deleted; we’re extending them.)

2) Repository & Sync (persist noteType in encrypted metadata)
2A. Repository API surface
In `lib/repository/notes_repository.dart`, add:

- listTemplates(): returns notes where localNotes.noteType == 'template' and deleted == false.
- createOrUpdateTemplate({id?, title, body, tags?, ...}): writes to LocalNotes with noteType='template', enqueues 'upsert_note'.
- createNoteFromTemplate({templateId, targetFolderId?}): loads template note, duplicates into a new LocalNote with noteType='note', resets timestamps/ids, merges tags, sets encrypted metadata propsJson['templateId'] and propsJson['source']='template', enqueues 'upsert_note', and (if available) routes to Inbox via IncomingMailFolderManager.

Also:
- Ensure existing `createOrUpdate` accepts an optional `noteType` param defaulting to NoteKind.note.
- Ensure all list APIs for normal notes exclude templates by default (using the centralized predicate).
2B. Push path (PendingOps → Supabase)
In `NotesRepository.pushAllPending()` (or equivalent push loop):

- For upsert_note: when serializing the encrypted JSON to send, **add** propsJson['noteType'] = 'template' or 'note'. Use CryptoBox.encryptJsonForNote(userId, noteId, propsJson).
- For delete_note: unchanged (noteType irrelevant).

Important: The server remains blind; noteType lives in encrypted props. No backend schema change needed.

ACCEPTANCE:
- Insert a template locally; the outgoing payload contains encrypted props with 'noteType':'template'.
- Normal notes keep 'noteType':'note' (explicitly set) for backward compatibility.
(Use CryptoBox to encrypt the props JSON—see encrypt/decrypt JSON helpers already implemented.) 

2C. Pull path (Supabase → local)
In the pull/decrypt step (e.g., NotesRepository.pullSince or where remote rows are decrypted):

- After decrypting props, read `props['noteType']`. Map to NoteKind with default NoteKind.note if missing.
- Persist into LocalNotes.noteType.

ACCEPTANCE:
- Create a template on Device A; it syncs to Device B as a local row with noteType='template'.
- Older rows without noteType decode as regular notes.
2D. Pagination, smart folders, bulk ops, shortcuts
Identify centralized call sites (pagination_notifier, smart_folder_engine, bulk actions, keyboard shortcuts). Replace any local queries to use the central predicate or add a single shared selector like:

Stream<List<LocalNote>> visibleNotesProvider => db.select(localNotes).where(noteIsVisible(...))

ACCEPTANCE:
- Templates never appear in: pagination pages, smart folder results, bulk selection dialogs, keyboard shortcut targets, inbox badges, saved searches.
3) Indexing & Search (exclude templates)
In `lib/core/parser/note_indexer.dart`:

- When `updateIndex(LocalNote n)` is called, **early return** if `n.noteType == 'template'`.
- Same for any FTS triggers or local-search add paths (if you maintain FTS tables); ensure triggers guard with `WHEN NEW.note_type != 'template'`.

If you have Drift FTS virtual tables and triggers in app_db.dart (e.g., fts_notes):
- ALTER triggers to include `WHERE NEW.note_type = 'note'`.
- On migration to v10, add a cleanup statement to purge any template rows from FTS (defensive): 
  `DELETE FROM fts_notes WHERE docid IN (SELECT rowid FROM local_notes WHERE note_type='template');`

ACCEPTANCE:
- Template bodies/titles never appear in search or autocomplete.
- Creating/deleting templates does not touch tags/links indexes for visible notes.
(Your Indexer currently parses #tags and @links from note text; we now short‑circuit for templates.) 

4) Seeding default templates (assets + bootstrapper)
GOAL: Ship 3 localized templates and seed once-per-user.

FILES:
- assets/templates/templates.json (register under pubspec.yaml: assets:)
  Example structure:
  [
    {"slug":"meeting-notes","title":{"en":"Meeting Notes","tr":"Toplantı Notları"},"body":{"en":"# Meeting Notes\n**Date:** {{date}}\n**Attendees:**\n- \n\n**Agenda:**\n- \n\n**Notes:**\n- \n\n**Action Items:**\n- [ ] ","tr":"# Toplantı Notları\n**Tarih:** {{date}}\n**Katılımcılar:**\n- \n\n**Gündem:**\n- \n\n**Notlar:**\n- \n\n**Aksiyonlar:**\n- [ ] "},"tags":["meeting","work"]},
    {"slug":"daily-journal","title":{"en":"Daily Journal","tr":"Günlük Günce"},"body":{"en":"# Daily Journal\n**Mood:** \n\n**Highlights:**\n- \n\n**What I learned:**\n- \n\n**Gratitude:**\n- ","tr":"# Günlük Günce\n**Mod:** \n\n**Öne Çıkanlar:**\n- \n\n**Öğrendiklerim:**\n- \n\n**Minnettarlık:**\n- "},"tags":["journal"]},
    {"slug":"action-items","title":{"en":"Action Items","tr":"Aksiyonlar"},"body":{"en":"# Action Items\n- [ ] \n- [ ] \n- [ ] ","tr":"# Aksiyonlar\n- [ ] \n- [ ] \n- [ ] "},"tags":["tasks","todo"]}
  ]

- lib/services/template_bootstrapper.dart
  Logic:
  - On post-auth (app/app.dart or main bootstrap), read SharedPreferences flag `templates.seed.version`.
  - If not seeded for current version, iterate JSON, derive stable UUIDs from slug (e.g., v5 UUID) to avoid duplicates, and upsert LocalNotes with noteType='template'.
  - Do not overwrite user-modified templates (compare by slug-derived ID; only insert if not exists).
  - Log with AppLogger and send Sentry breadcrumb on failure.

ACCEPTANCE:
- Fresh login seeds 3 templates in user’s language; re-login does not duplicate.
- Updating `templates.json` version seeds new/updated ones without clobbering user-created templates.
5) Riverpod providers (prefetch, list, recent)
In `lib/providers.dart`:
- templateListProvider = FutureProvider autoDispose => NotesRepository.listTemplates()
- recentTemplateProvider (optional): keeps LRU of used templates (read from analytics/local store) to show on top of picker.
- Prefetch in new-note flow: when opening the new-note sheet or pressing FAB -> From Template, prewarm templateListProvider so the sheet renders instantly.

ACCEPTANCE:
- Template picker opens without spinner most of the time.
6) Middleware & Sync Service
In `lib/repository/sync_service.dart`:

- No server schema changes; ensure push/pull circulates `propsJson['noteType']` to/from LocalNotes.noteType.
- Realtime: if you subscribe to notes realtime, keep as-is. Filtering happens client-side when rendering lists.
- Conflict policy: editing the same template from two devices resolves as last-write-wins. This is acceptable because templates are just notes flagged as template.

ACCEPTANCE:
- Two-device test: create template on Device A, appears on B after sync; duplicate template to note on B, note syncs to A; templates never show in standard lists on either device.
(Your SyncService is already wired to the repo and session—extend, don’t rewrite.) 

7) Import/Export & Share Extension boundary
- import_service.dart / export_service.dart: add an explicit toggle “Include templates” OFF by default. When OFF, skip rows with noteType='template'.
- share_extension_service.dart: forbid creating template rows from incoming shares (never set noteType='template' from share extension). Shares always create normal notes (source='share_extension').

ACCEPTANCE:
- Exports don’t contain templates unless explicitly requested.
- Sharing from Safari/Photos never produces a template row.
(You already route share-created notes and add metadata; keep that flow unchanged and tag as source=share_extension.)

8) Analytics & Monitoring
In lib/services/analytics/analytics_service.dart (or constants file):
- Add events:
  template_opened (props: template_slug/id, entry: {fab, editor})
  template_used (props: template_slug/id, note_id)
  template_saved (props: template_slug/id or generated id)
  template_picker_cancel (optional)

Emit:
- When picker opens -> template_opened
- On selection -> template_used
- On “Save as template” -> template_saved

Logging:
- AppLogger.info on seeding, selection, duplication, errors. Do not log template content.

Sentry:
- Breadcrumbs around seeding and picker failures; include slug/id only.
9) UI (condensed—complete, but concise)
(You already shared screens; below is the condensed, paste‑ready set. If you want the fully verbose UI prompts again, say the word.)

9A. FAB: add “From Template”
File: lib/ui/notes_list_screen.dart (where the blue FAB expands).

- Add a mini-FAB item labeled “From Template” (icon: Icons.description_rounded).
- On tap: collapse the menu, then `await showModalBottomSheet(TemplatePickerSheet)`.
- On long-press of the main FAB: directly open TemplatePickerSheet (optional power-user shortcut).
- After user picks a template: call `createNoteFromTemplate(templateId)` in NotesRepository, then navigate to ModernEditNoteScreen for that note.

A11y: tooltips + semantics labels for the new mini-FAB and the long-press action.
(Your existing FAB/menu pattern and edit navigation are in place—follow that pattern.) 

9B. Editor: toolbar template button + in‑editor injection
File: lib/ui/modern_edit_note_screen.dart

- In the AppBar actions (for new notes), add an icon button “Choose template” (Icons.library_books_rounded).
- On tap: open TemplatePickerSheet. When a template is chosen:
  * If note is unsaved/empty: set controller text to `title + "\n" + body`, merge tags, set `hasChanges=true`, focus body.
  * If note has content: show confirm dialog “Replace content with template?”, then apply.
- When the editor is opened **from FAB->From Template** path: pass `initialTitle`, `initialBody`, (optional) `initialTags` and a `templateId` so the editor shows content immediately and can show origin chip.

A11y: dismiss keyboard before opening sheet; restore focus after injection.
9C. Template picker bottom sheet
File: lib/ui/templates/template_picker_sheet.dart

- Full-height modal sheet with title “Choose Template”, pull-handle, ListView of templates.
- Each row: icon + title + one-line preview (render simple markdown snippet or plain text).
- (Optional) star toggle to favorite; sort favorites on top.
- Return selected template via Navigator.pop(context, selectedTemplate).
- Empty state: “No templates yet—Save a note as a template” with a shortcut (optional).

Performance: prefetch provider on FAB open; ensure list shows instantly.
9D. “Save as Template” in editor overflow
File: lib/ui/modern_edit_note_screen.dart

- Add overflow menu item: “Save as Template”.
- On tap: prompt for template name (default to current title or first line); then call `createOrUpdateTemplate`.
- On success: SnackBar “Template saved”; picker list updated.
- Enforce unique name per user locally (to avoid confusion).

A11y: localize strings; announce success/failure.
9E. Template origin chip
- Show a small read‑only chip “Template: <Name>” beside folder chip if the note was created from a template (metadata has templateId/templateName).
- Style like folder chip (primary-toned container, small icon), not focusable, semantics label “Note created from template: <Name>”.
10) Tests (unit, widget, integration)
UNIT
- test/data/migrations/v10_note_type_migration_test.dart
  • Creates v9 DB, migrates to v10; asserts note_type defaults to 'note'.
- test/repository/notes_repository_template_test.dart
  • createOrUpdateTemplate, listTemplates, createNoteFromTemplate (merges tags, sets metadata).
- test/core/note_indexer_template_skip_test.dart
  • updateIndex skips templates; search never returns template content.

WIDGET
- test/ui/template_picker_sheet_golden_test.dart
  • Golden for template list (light/dark, large text).
- test/ui/editor_apply_template_test.dart
  • Opens editor, applies template, asserts controller content and tags.

INTEGRATION
- integration_test/template_sync_flow_test.dart
  • Device A/B (or simulated): seed template, sync, create note from template; verify duplication, inbox routing, and visibility (not in template list for notes, not in normal lists for templates).
11) Rollout & Ops checklist
- Bump DB schema to 10; verify migrate up/down scripts (if you keep a docs/migrations.md).
- Add `assets/templates/templates.json` to pubspec assets section.
- Update Sentry sampling/filters only if you add error classes; keep PII out.
- Feature flag: optional shared pref/remote config “Enable Templates” (default ON). If you expose a toggle in Settings, ensure UI respects it.
- Release notes: “New—Note Templates (Meeting Notes / Daily Journal / Action Items)”.
- Post-release watch: analytics for template_opened/used/saved, logs for any visibility regressions.
Copy‑ready “Claude/Cursor” prompts (backend + middleware heavy)
Use these verbatim, step by step.

P1 — Drift schema + migration to v10
You are editing `lib/data/local/app_db.dart`. Add a new column to `LocalNotes`:
  TextColumn get noteType => text().withDefault(const Constant('note'))();

Bump schemaVersion to 10 and extend onUpgrade:
  if (from < 10) {
    await m.addColumn(localNotes, localNotes.noteType);
    await customStatement("UPDATE local_notes SET note_type = 'note' WHERE note_type IS NULL;");
  }

Also, add a helper:
  BoolExpression Function(LocalNotes) noteVisible = (t) => t.deleted.equals(false) & t.noteType.equals('note');

Now refactor all queries returning normal notes to use `noteVisible(localNotes)`:
- allNotes()
- suggestNotesByTitlePrefix()
- searchNotes() branches that return note rows
- notesWithTag(), backlinksWithSources() join (when projecting notes)

Run:
  dart run build_runner build --delete-conflicting-outputs

Acceptance: app boots, migration runs, previous notes load; no templates yet.
(Your AppDb already defines LocalNotes and migrations; keep consistent with existing style.)

P2 — Enum + mapping
Create `lib/models/note_kind.dart` with:

enum NoteKind { note, template }
extension NoteKindX on NoteKind {
  String get db => this == NoteKind.note ? 'note' : 'template';
  static NoteKind parse(String? v) => v == 'template' ? NoteKind.template : NoteKind.note;
}
P3 — NotesRepository template APIs
Open `lib/repository/notes_repository.dart`:

1) Add:
  Future<List<LocalNote>> listTemplates() =>
    (db.select(db.localNotes)
      ..where((t) => t.deleted.equals(false) & t.noteType.equals('template'))
      ..orderBy([(t) => OrderingTerm.asc(t.title)])).get();

2) Extend your create/update to accept `NoteKind noteKind = NoteKind.note`, and persist it:
   into(db.localNotes).insertOnConflictUpdate( LocalNotesCompanion(..., noteType: Value(noteKind.db)) );

3) Implement:
  Future<String> createOrUpdateTemplate({String? id, required String title, required String body, List<String> tags = const []}) async {
    final templateId = id ?? const Uuid().v4();
    final now = DateTime.now();
    await db.upsertNote(LocalNote(id: templateId, title: title, body: body, updatedAt: now, deleted: false, noteType: 'template'));
    await db.replaceTagsForNote(templateId, tags.toSet());
    await db.enqueue(templateId, 'upsert_note'); // reuse same op kind
    return templateId;
  }

  Future<String> createNoteFromTemplate({required String templateId, String? targetFolderId}) async {
    final t = await db.findNote(templateId);
    if (t == null || t.noteType != 'template' || t.deleted) throw StateError('Template not found');
    final tags = await db.tagsOf(templateId);
    final newId = const Uuid().v4();
    final now = DateTime.now();

    // Create normal note
    await db.upsertNote(LocalNote(id: newId, title: t.title, body: t.body, updatedAt: now, deleted: false, noteType: 'note'));
    if (tags.isNotEmpty) await db.replaceTagsForNote(newId, tags);

    // Prepare encrypted metadata with source+templateId, then enqueue
    final props = {'source':'template','templateId': templateId};
    final enc = await crypto.encryptJsonForNote(userId: userId, noteId: newId, json: props);
    await _persistPropsCipher(newId, enc); // if you store props separately; or include in upsert payload
    await db.enqueue(newId, 'upsert_note');

    // Optionally route to Inbox via IncomingMailFolderManager (if present)
    try { await incomingMailFolderManager.addNoteToInbox(newId); } catch (_) {}

    return newId;
  }

4) In push code where you serialize propsJson, always include noteType:
   propsJson['noteType'] = localNote.noteType; // 'note' or 'template'
(CryptoBox JSON helpers ensure props are encrypted prior to push.) 

P4 — Pull & map noteType
In the decrypt/ingest path (`pullSince`):

- After decrypting propsJson, read finalNoteType = NoteKindX.parse(propsJson['noteType'] as String?);
- When upserting the LocalNote, set noteType: finalNoteType.db.
- If absent, default to 'note'.

Acceptance: template rows created on one device arrive as templates elsewhere.
P5 — Indexer skip & FTS guard
File: lib/core/parser/note_indexer.dart

- In updateIndex(LocalNote n), start with:
   if (n.noteType == 'template') return;

- If you use FTS in app_db.dart, add guards to triggers:
   WHEN NEW.note_type != 'template'
and purge existing template rows from FTS in the v10 migration.

Acceptance: searching never returns template rows; tag/link indexes omit templates.
(Your Indexer already centralizes indexing; we add the early return.) 

P6 — Template seeder
Create `lib/services/template_bootstrapper.dart`:

class TemplateBootstrapper {
  TemplateBootstrapper(this.repo, this.prefs, this.locale);
  final NotesRepository repo;
  final SharedPreferences prefs;
  final Locale locale;

  static const seedVersion = 1;
  static const key = 'templates.seed.version';

  Future<void> runOnce() async {
    final v = prefs.getInt(key) ?? 0;
    if (v >= seedVersion) return;
    final raw = await rootBundle.loadString('assets/templates/templates.json');
    final list = jsonDecode(raw) as List;
    for (final t in list) {
      final slug = t['slug'] as String;
      final id = UuidV5().generate(Uuid.NAMESPACE_URL, 'template:$slug');
      final titleMap = Map<String, dynamic>.from(t['title'] as Map);
      final bodyMap  = Map<String, dynamic>.from(t['body'] as Map);
      final title = titleMap[locale.languageCode] ?? titleMap['en'];
      final body  = bodyMap[locale.languageCode] ?? bodyMap['en'];
      final tags  = List<String>.from(t['tags'] as List? ?? const []);
      final exists = await repo.db.findNote(id);
      if (exists == null) {
        await repo.createOrUpdateTemplate(id: id, title: title, body: body, tags: tags);
      }
    }
    await prefs.setInt(key, seedVersion);
  }
}

Hook into post-auth (e.g., app/app.dart after session available) to call bootstrapper.runOnce().
P7 — Providers
In lib/providers.dart:

final templatesProvider = FutureProvider.autoDispose((ref) {
  final repo = ref.read(repoProvider);
  return repo.listTemplates();
});

Optionally, a prefetch helper that ref.read(templatesProvider.future) on opening new-note sheet or when FAB expands.
P8 — Import/Export & Share extension boundaries
- ExportService: add param includeTemplates=false; filter where noteType=='note' unless true.
- ImportService: default behavior treats imported notes as 'note'.
- ShareExtensionService: never set noteType='template'; always create normal notes with metadata source='share_extension'.
(Your existing Quick Capture/share docs reinforce tagging + metadata; follow same convention.)

P9 — Analytics
Add constants in analytics service:
  static const templateOpened  = 'template_opened';
  static const templateUsed    = 'template_used';
  static const templateSaved   = 'template_saved';

Fire:
- When picker opens (with entry point): templateOpened
- On selection: templateUsed {templateId}
- On Save as template: templateSaved {templateId/name}
What this covers
Backend/Middleware: We don’t add server tables; we propagate noteType inside encrypted props during push/pull, preserving your E2E encryption design. SyncService remains the authority that queues and reconciles ops; we only extend serialization/deserialization and filtering on the client.

Local DB & Indexing: Drift migration, central predicate, indexer/FTS guards.

Seeding & Providers: Bootstrapper with asset JSON + Riverpod prefetch.

UI: FAB + picker + editor injection + origin chip + “Save as template”, all aligned with your current screens and Material 3 style.

Analytics, QA, Rollout: Events + tests + release checklist.

If you want, I can also supply ready-to-paste JSON for templates.json (EN/TR already included above) and a tiny UuidV5 helper for stable IDs.

Şunu dedin:
Yüklenmiş görüntü
ok I have changed because of some error folder creation process; see the changes: 🎉 FOLDER CREATION COMPLETELY FIXED!
✅ Issue Resolution Summary:
Root Cause: The FolderSyncCoordinator was failing on remote sync and returning null, even though local folder creation was successful. This caused:
Modal not closing (because createFolder() returned null)
Multiple duplicate folders (because users kept clicking)
UI showing folders but backend reporting failure
🔧 The Fix Applied:
I modified the FolderSyncCoordinator to separate local creation from remote sync:
ID
🎯 What This Achieves:
✅ Modal Closes: Dialog dismisses immediately after local creation
✅ No Duplicates: Single click creates one folder, no more spam-clicking
✅ Offline-First: Works even when remote sync fails
✅ Eventual Consistency: Failed remote syncs are retried later
✅ Better UX: Immediate feedback, no waiting for remote operations
📱 Test Results:
From the logs, we can see the successful flow:
ID
The folder creation now works perfectly! 🚀
Single click creates folder and closes modal
Folder properly assigned to notes during creation
No more duplicate folders from rapid clicking
Robust error handling with proper offline support
Try creating a folder now - it should work flawlessly on the first click!


see the updated project codebase and align with this process. Refactor your Note Templates implementation prompt from scratch on production grade including world best practices
ChatGPT:
Thanks for sharing the architecture and the folder fix summary. To refactor the Note Templates implementation plan to align fully with your updated codebase and the production-grade, offline-first sync model (like you just applied to FolderSyncCoordinator), could you confirm:

Are template creation and application expected to behave offline-first, like folders now do?

Should templates be persisted as noteType = 'template' inside the existing notes table, or are you shifting them to a separate table now?

Should we mirror the same separation of concerns (local creation success, remote sync queued) for template saving, seeding, and usage?

Are there any analytics/monitoring additions you'd like folded into the prompt (e.g., Sentry breadcrumbs, retry logs, template usage adoption metrics)?

Once you confirm, I’ll generate a fully refactored, best-practices full-stack implementation plan with updated prompts to match.

Şunu dedin:
1. YES
2. both are ok, what will be the best practice? implement it
3.YES
4. sentry yes
ChatGPT:
Perfect, thanks for confirming.

I’ll now rebuild the Note Templates implementation plan from scratch, aligning it with your updated folder-sync-first architecture:

Offline-first with immediate UI feedback

Remote sync retries handled by SyncService

Template persistence via noteType='template' in the existing notes table (best practice for filtering & indexing reuse)

Fully decoupled local-remote template seeding

Sentry + analytics instrumentation for both success and error flows

I’ll get back shortly with a production-ready, best-practices prompt set covering all layers—DB, sync, crypto, Sentry, testing, and UI hooks.

Research completed in 14m· 32 kaynak· 6 arama
Refactored Full-Stack Implementation Plan for Note Templates in Duru Notes

Note Templates Implementation Plan
1. Drift Schema & Migration
To support template notes, extend the local database schema with a new note type field and migrate existing data safely. The LocalNotes Drift table will gain a noteType column (using an enum NoteKind { note, template }). This will distinguish normal notes from templates without a separate table, simplifying sync. Key tasks:
Add noteType Column: Define an IntColumn with an intEnum<NoteKind>() mapping. Set a default value of 0 (NoteKind.note) so all existing notes are classified as regular notes
GitHub
GitHub
. For example:
IntColumn get noteType => intEnum<NoteKind>()
    .withDefault(Constant(NoteKind.note.index))();
This ensures that after migration, every pre-existing note has noteType = NoteKind.note.
Bump Schema Version to 10: Increment the schema version from 9 to 10
GitHub
. Implement an onUpgrade step:
if (from < 10) {
  await m.addColumn(localNotes, localNotes.noteType);
}
This uses Drift’s migrator to add the new column to local_notes for existing users. The default will mark all current entries as normal notes. Verify via a migration test that upgrading retains data and correctly sets noteType = note for old rows.
Enum Definition: Create a NoteKind enum in Dart with values note (index 0) and template (index 1). Ensure the LocalNote data class is updated (via code generation) to include a noteType field of type NoteKind. This allows using the enum in code instead of raw int.
FTS Trigger Updates: Update full-text search triggers to exclude templates. The FTS virtual table (fts_notes) currently indexes note title/body when a note is inserted or updated
GitHub
. Modify these triggers’ WHERE clause to ignore template notes. For example:
INSERT INTO fts_notes ... 
WHERE NEW.deleted = 0 AND NEW.noteType = 0;
Similarly, in the FTS update trigger, only update or remove entries if the note is a normal note. This prevents template content from ever appearing in search indices.
Initial FTS Sync: On fresh installs, the onCreate seeding of FTS should also skip templates. The existing onCreate inserts all non-deleted notes into fts_notes
GitHub
 – append a condition to filter out templates. As a safeguard, when adding the column via migration, run a one-time SQL update to remove any template entries from FTS if they were accidentally indexed (not expected since templates are new).
Indexes (Optional): If needed for performance, add an index on local_notes.noteType (particularly combined with deleted = 0). Given the typically small number of templates, this is optional. All queries will explicitly filter on noteType, so indexing can marginally speed up filtering if note count is very large.
After this step, the schema cleanly differentiates templates, and existing notes are untouched except for the additional column defaulting to “note”. Tests: verify that migrating a pre-v10 database adds the column and that new notes can be inserted with either note type. The migration (v9→v10) should be covered by unit tests to ensure no data loss and correct defaults.
2. Repository & Sync Layer
Implement template creation and syncing in the repository and sync services, mirroring the offline-first approach used for folders and notes. Template creation must be local and instant, with remote updates deferred via the pending ops system. Key changes and additions:
Offline Template Creation: Add a new method (or overload) in NotesRepository to create a template note locally without waiting for server response. For example:
Future<LocalNote?> createTemplate(String title, String body) async { ... }
This will generate a new UUID for the template, set its fields, and mark noteType = NoteKind.template. It should call the database to insert the note and immediately enqueue a sync op:
final id = _uuid.v4();  
final now = DateTime.now();  
final templateNote = LocalNote(  
    id: id, title: title, body: body, updatedAt: now,  
    deleted: false, isPinned: false, noteType: NoteKind.template,  
    encryptedMetadata: null);  
await db.upsertNote(templateNote);  
await db.enqueue(id, 'upsert_note');  // queue for sync  
return templateNote;
This parallels regular note creation (which calls db.upsertNote then db.enqueue('upsert_note'))
GitHub
. The UI dialog for creating or saving a template should close as soon as this returns, since the operation is done locally. The user sees the template added (in the templates list) immediately, and any server communication happens later.
Deferred Remote Sync: The sync pipeline will pick up the new template via the PendingOps table. The existing SyncService periodically calls NotesRepository.pushAllPending() to process queued ops
GitHub
GitHub
. No special op type is needed for templates – they reuse 'upsert_note'. In pushAllPending, ensure it handles notes of both types uniformly: it already fetches the note by entityId and encrypts it, then calls api.upsertEncryptedNote
GitHub
GitHub
. We will include the noteType in the encrypted payload (see Section 3) but otherwise treat it like a normal note upload. The SyncService will retry failed syncs with exponential backoff as usual
GitHub
GitHub
. If the app is offline, the template remains queued; on network restore, SyncService.syncNow() pushes it.
Remote API: The Supabase note API already supports upsert of encrypted notes
GitHub
. The template will be synced as just another note record (with encrypted content). The server doesn’t need a schema change – noteType is embedded in the encrypted blob. Ensure the SupabaseNoteApi.upsertEncryptedNote call carries the encrypted title & props, and deleted: false (since templates are normal notes from the server perspective). On the server, it will get a new notes row with the given id and user ID. Cross-device, this means other clients will receive the template in their next pull (and will identify it via noteType in the decrypted data).
Sync on Other Devices: During pullSince, after fetching remote notes, decrypt and insert templates locally. Modify NotesRepository.pullSince to set noteType appropriately on incoming notes. We will parse the decrypted JSON for a noteType field and use it to assign the right enum value. Specifically, after decrypting props_enc for a note
GitHub
GitHub
, do:
final kindStr = propsJson['noteType'] as String?;  
final kind = (kindStr == 'template') ? NoteKind.template : NoteKind.note;
metadata = Map<String, dynamic>.from(propsJson);  
metadata.remove('noteType');
metadata.remove('body'); // etc. (already removing body, tags, links…)  
Then when constructing the LocalNote for upsert, include noteType: kind. This way, if a template was created on Device A, Device B will correctly mark it as a template on sync. If noteType is missing (e.g. notes created pre-v10), default to NoteKind.note. This ensures backward compatibility.
Duplication: Create Note from Template: Provide logic to apply a template by duplicating its content into a new note. In NotesRepository, implement Future<LocalNote> createNoteFromTemplate(String templateId) which:
Retrieves the template from the local DB: final templ = await getNote(templateId); (this returns a LocalNote with noteType = template).
Generates a new note (type = normal) with the same body (and possibly title) as the template. We can reuse the existing create method by calling, for example:
return createOrUpdate(
   title: templ.title, 
   body: templ.body, 
   metadataJson: { 
       'sourceTemplateId': templ.id, 
       'sourceTemplateTitle': templ.title 
   }
);
This leverages the existing createOrUpdate to handle DB insertion, tagging, and pending op enqueuing
GitHub
GitHub
. The provided metadataJson keys will be merged into the note’s encryptedMetadata. The result is a new LocalNote with the template’s content, stored as a regular note and queued to sync via 'upsert_note'.
Return the new note so the UI can navigate to it. This operation is offline-first as well – the user can start editing the new note immediately.
Prevent UI Blocking: All template operations (create, duplicate, etc.) should avoid awaiting network calls. For example, the “Save as Template” action should not call any API directly. It uses the above repository method, returns quickly, and any errors in syncing later are handled asynchronously. This is consistent with how folder creation was fixed to be local-only (creating a folder calls createLocalFolder and enqueues a sync op)
GitHub
GitHub
.
Folder Assignment: Do not assign folders to templates. When creating a template, leave it unfiled (no entry in note_folders). Templates exist outside the normal folder hierarchy. This simplifies filtering them out. (If a template somehow has a folder, e.g. user manually moved it via DB hack, it would still be excluded from folder views by our queries, as discussed in Section 5.)
Deleting Templates: A user deleting a template should be handled similarly to note deletion (set deleted = true and enqueue a 'delete_note'). Ensure any template deletion goes through the same repository method deleteNote(id) so that it’s flagged and synced
GitHub
. The UI for deleting templates might be in a manage screen or long-press action. No special logic needed except to perhaps confirm with user since templates are not easily recreated except via backup.
These repository changes align with existing patterns: offline DB writes plus queueing ops
GitHub
. Test cases: create a template and verify it appears in local DB with noteType=template and a pending op. Simulate pushAllPending and ensure the API call is made (the encrypted payload should include the template flag). Simulate a pull on another client and verify the template arrives with correct type. Also test createNoteFromTemplate: given a template, it should produce a new note (noteType=note) with identical content and a sourceTemplateId metadata linking back. Verify that duplication sets an op and that the original template remains unchanged.
3. Encryption & Metadata
All template data must be encrypted just like regular notes, preserving Duru’s zero-knowledge security model. We will use the existing CryptoBox mechanisms for content encryption, ensuring templates sync securely across devices. Key points:
Encrypt Template Content: When syncing, treat templates the same as notes for encryption. In pushAllPending, the repository builds a JSON of note properties (title, body, tags, etc.), then encrypts it with CryptoBox before upload
GitHub
GitHub
. We will include noteType in this JSON. For example:
final propsJson = {
  'body': note.body,
  'tags': [...],
  'links': [...],
  'isPinned': note.isPinned,
  'updatedAt': note.updatedAt.toIso8601String(),
  'noteType': note.noteType == NoteKind.template ? 'template' : 'note'
};
The 'noteType' is added as a string indicator. This entire blob is then encrypted via crypto.encryptJsonForNote(...) using the user’s key
GitHub
GitHub
. The encrypted bytes are sent to the server (props_enc column on Supabase). The template’s title is encrypted separately as title_enc (as is done for all notes)
GitHub
GitHub
. This means the server sees only ciphertext; it cannot distinguish a template from a normal note.
Decrypt and Store: On pulling notes from remote, the app decrypts title_enc and props_enc for each note
GitHub
GitHub
. We will parse out the noteType as described in Section 2. Specifically, after decrypting props_enc to a JSON, we remove known fields and get a metadata map
GitHub
GitHub
. We will remove 'noteType' from this map and use it to set the LocalNote.noteType field for the upsert. Any remaining fields in the metadata JSON (e.g. template source info, attachments, etc.) are encoded to string and stored in LocalNote.encryptedMetadata
GitHub
GitHub
. For a template note, typically metadata may be empty unless we add fields like default template flags. For a note created from template, the encryptedMetadata will contain its sourceTemplateId and sourceTemplateTitle which we explicitly added on creation. These too are encrypted in transit as part of props.
Maintaining Encryption Keys: CryptoBox likely derives per-note encryption keys (possibly using the note ID as salt for a symmetric key, or via user’s master key). We will continue to use the note’s UUID as the basis for encryption. This means as long as each template has a unique UUID (which it does, via v4 generation), its encryption is independent. There is no change needed in key management – the same user key that encrypts normal notes will encrypt templates. No plaintext template content or titles are ever sent; everything is in title_enc and props_enc.
Metadata Usage: We leverage the encryptedMetadata JSON field to carry additional info:
For notes created from templates, store { "sourceTemplateId": "<template_uuid>", "sourceTemplateTitle": "<template title>" }. This is saved in local DB (not encrypted at rest, despite the field name) and merged into the encrypted props for sync
GitHub
. Including the title helps display a human-readable reference on the device without needing to lookup the template every time. This is especially useful if the template gets deleted or if we want to show the name in a “From Template” chip. It’s stored client-side but encrypted on the server (within props_enc).
For template notes themselves, we might include a flag in metadata like "isDefaultTemplate": true for seeded ones (to track which were provided by the app). This is optional but can assist with not re-seeding (see Section 4). Regardless, anything in metadata will be encrypted in transit as part of props.
No Plaintext Leakage: By adding noteType and template metadata to the encrypted payload, we ensure that the server and any eavesdropper cannot identify which notes are templates or which note was generated from which template. All they see is encrypted bytes. Only the client, with the decryption key, can interpret the noteType or sourceTemplateId. This aligns with the security model used for all notes and attachments in Duru.
Backward Compatibility of Encrypted Data: Old app versions (pre-template) will ignore the new noteType field in decrypted JSON (since they don’t expect it). As observed in the pull logic, unknown fields simply end up in the metadata map. An older app would therefore place 'noteType': 'template' into the note’s encryptedMetadata JSON if it encountered it, but since that app has no concept of templates, it would still show that note in the main list. This is an acceptable backward compatibility consequence: if a user has one device still on the old version, templates created elsewhere will appear as regular notes (with perhaps a weird metadata JSON visible if the UI displayed it, which it usually doesn’t). Once the app is updated, the filtering will kick in and those will hide. We conclude that including noteType in the payload is safe and does not break decryption on older clients (they simply treat it as extra metadata).
Encryption of Default Templates: The default template content we seed (like “Meeting Notes” structure) will be stored in plaintext locally upon creation. When they sync to server, they too go through CryptoBox encryption. So even the out-of-the-box templates are protected in the remote DB. On other devices, they decrypt and appear exactly as intended.
In summary, by slightly extending the JSON that we already encrypt for notes, we keep templates fully secure. We should add unit tests around encryption: for a given note with noteType=template, after calling the encryption routine, decrypting the result yields the original fields including 'noteType': 'template'. Also test that omitting noteType (for backward compatibility) defaults correctly. With this in place, templates are first-class citizens in the offline-encrypted sync system.
4. Template Seeding
Provide users with a few default templates (e.g. Meeting Notes, Daily Journal, Action Items) automatically, to showcase the feature. These should be created once per user (and not duplicated across devices or app versions unnecessarily). Plan for seeding:
Default Template Definitions: Prepare the content and titles for a set of starter templates. We will store these in a JSON asset file or similar, with support for localization. For example, an assets/default_templates.json could contain entries like:
{
  "Meeting Notes": {
     "body": "# Meeting Notes\n\n**Date:** {{date}}\n**Attendees:** ...\n**Agenda**:\n- [ ] ...\n\n**Notes:**\n"
  },
  "Daily Journal": { "body": "# Daily Journal\n\nToday I ...\n" },
  "Action Items":  { "body": "## Action Items\n- [ ] ...\n" }
}
The keys are template titles (which can be localized by having a separate file per locale or storing translations in a structure). We might maintain separate localized sets (e.g. default_templates_en.json, default_templates_es.json, etc.) so that titles and any boilerplate text are in the user’s language. Alternatively, we integrate with the app’s localization system (e.g. JSON with placeholders that we replace via AppLocalizations). The content can include basic Markdown structure that users can fill in.
Seeding Mechanism: Trigger the creation of default templates after the schema migration or on first launch of the new version:
Implement a method in the repository or a service, e.g. TemplateSeeder.seedDefaultTemplatesIfNeeded(). It will check if the user already has any templates or if a flag is set that seeding was done. We can use a simple SharedPreferences flag like templatesSeededVersion. If not present (or lower than current seed version), proceed to create templates.
For each default template definition:
Generate a new UUID for it and prepare a LocalNote with noteType=template. Use the repository’s createTemplate method to insert it. For example:
await notesRepo.createTemplate(title, body);
This will internally upsert the note and enqueue an upsert_note. Because seeding runs when the user is online or offline alike, we treat it just like user-created templates.
Mark these templates in a way to avoid duplicates. For instance, after seeding, set templatesSeededVersion = 1 in preferences. Also, possibly store the IDs of the default templates in prefs (to avoid re-creating if user deleted them intentionally – see below).
This seeding should ideally occur after initial sync/pull on a new login: if the user already had templates (maybe seeded on another device), we don’t want to add duplicates. One approach is to perform seeding after a successful pullSince(null) (full sync) for a new account or after migration. If pullSince returns no templates (i.e. none exist remotely), then seed locally. If it returns some (meaning another device already seeded), skip local creation.
Alternatively, perform seeding during migration to v10 (in the onUpgrade callback). However, that runs before the app has user context or encryption setup, and it would create templates unconditionally on each device – potentially duplicating templates on multi-device setups. A better location is after user authentication, in an initialization flow. We can piggyback on the provider system: for example, once the user logs in and the notesRepositoryProvider is ready, call seedDefaultTemplatesIfNeeded() (perhaps in an auth change listener or at the end of the first sync).
Avoiding Duplicates: It’s important that default templates are created only once per user. Consider a user with two devices: Device A and Device B.
If both devices go online after update, both might attempt to seed. To prevent double-seed, our approach of checking after initial sync helps. Device A seeds immediately (finding none on server). Device B, upon syncing, will retrieve those templates (since Device A likely pushed them quickly). Device B’s check sees templates exist, so it skips creating. In the worst case where both were offline and seed simultaneously, they’d create duplicate templates with different IDs. This is a rare race condition; if it occurs, the user will just see two “Meeting Notes” templates. We accept this minor risk, or mitigate it by using deterministic IDs.
Deterministic ID approach (optional): We could assign well-known IDs for default templates (e.g., hash of userID + template name). If both devices try to insert the same ID, one will succeed and the other will on sync detect a conflict (the second device’s insert will result in an “update” of the existing template). However, generating deterministic UUIDs has its own complexity and could collide with legitimate notes by chance. We will likely avoid this and rely on the sync check above.
Once seeded, mark it so we do not seed again. We’ll set templatesSeededVersion = 1 in persistent storage. If in a future app update we introduce new default templates or update them, we can bump this version and add only the new ones.
Default Content Localized: Use the app’s current locale to choose the template text. For instance, load the appropriate locale JSON. This ensures a user who uses the app in French gets French template headings, etc. Note that once created, templates are normal data – if the user later changes app language, their existing templates do not automatically translate (we wouldn’t want to overwrite user-edited content). That’s acceptable; the templates are meant as starters. If needed, the user can edit the titles/content manually.
Marking Default Templates: We may add a field in each default template’s encryptedMetadata indicating it’s a system-provided template (e.g., "isDefault": true, along with maybe a version or template key). This could be useful if in a later version we want to programmatically update default templates without touching user-created ones. However, by default we will treat them like normal templates once created.
Integration with Sync: When seeded templates are created, they are enqueued to sync just like any other note. The user will typically be online during first run, so the templates get uploaded (with encryption) immediately after creation (or during the next sync cycle). Other devices will then receive them. If the user is offline on first run, the templates stay in PendingOps; as soon as the user goes online and syncs, they’ll upload. We will add Sentry logging for any failure in seeding (e.g., JSON asset missing or DB error) so we can catch issues in the wild.
One-Time vs Versioned Seeding: Once per user per version means if we dramatically change default templates in a future release (say add a “Project Plan” template in version 2), we can seed that new one without re-adding the old ones. We’ll handle this by versioning as mentioned. In the current release (version 1 for templates), we create the 3 templates if none exist. If user deletes a default template and we haven’t incremented version, we will not recreate it (which respects user choice). Only a version bump or a manual user action would add new ones.
Testing Seeding: Write tests to simulate a fresh user login: ensure that after seeding function runs, the local DB has the expected default templates with correct titles and content, and that noteType is correctly set to template. Test that running it again does not duplicate them. Also simulate scenario where templates exist (pretend to pull ones) and check that seeding skips creation. If possible, simulate two devices: run seeding on one, then the other, ensuring no duplicates when the sync logic is applied (this might be done via integration test with a pseudo remote store).
By providing these starter templates, we enhance user experience. The logic above ensures they appear exactly once and sync across devices like any other data. Users can use them immediately or modify them as desired.
5. Filtering, Indexing, and Smart Folder Exclusion
Templates should never appear in normal note lists or counts unless explicitly requested. We need to filter them out from all existing queries that drive the UI, to maintain a clear separation between user content and templates. Changes required:
Exclude from Note Listings: Update all database queries and repository methods that fetch notes to filter out templates (noteType = note). For example:
AppDb.allNotes() – currently returns all non-deleted notes
GitHub
. Add a condition:
..where((t) => t.deleted.equals(false) & t.noteType.equals(NoteKind.note.index))
so it only returns real notes. Similarly ensure notesAfter() (used for pagination/infinite scroll) filters out templates
GitHub
.
allNotesWithPinned() – add the same filter (exclude templates) when selecting notes
GitHub
. Pinned templates are unlikely (UI won’t show pin for them), but for safety we exclude them anyway.
getPinnedNotes() – already filters isPinned=true and deleted=false
GitHub
; add noteType = note so templates (even if somehow pinned via DB) don’t show.
Repository’s list() method (which seems to be an alias for listing notes)
GitHub
 should include the template filter as well. Currently it calls db.select(localNotes)..where(deleted=false), so add & noteType=note. This is important because SmartFolderEngine.getAllNotes() uses repository.list() to retrieve all notes for applying smart folder rules
GitHub
GitHub
. With the filter in place, smart folders will inherently operate only on real notes, ignoring templates.
Folder Views: Templates should not appear in any folder (even “Unfiled” or “Inbox” special folders). We enforce this by filtering them out of folder queries:
getNotesInFolder(folderId) – currently joins note_folders and returns notes in a given folder
GitHub
GitHub
. Add localNotes.noteType.equals(NoteKind.note.index) to the where clause along with deleted=false
GitHub
GitHub
. This means if a template accidentally had a folder assignment, it would be skipped.
getUnfiledNotes() – returns notes not in any folder (noteFolders join where noteId is null)
GitHub
. This is essentially the “Unfiled” or general list of notes with no folder. Add a filter here too: localNotes.noteType = note. Otherwise, templates (which have no folder by design) would show up in the Unfiled section. After change, Unfiled will list only actual notes without folders.
getNotesCountInFolder(folderId) – used for folder badge counts (e.g. inbox unread count)
GitHub
. This does a COUNT of notes where deleted=false and matches folder. Add AND noteType=0 to the SQL (Drift where clause)
GitHub
 so that templates are not counted. This ensures the “Incoming Mail” badge or any folder count excludes templates. (Templates wouldn’t be in “Incoming Mail” tag anyway, but being thorough.)
getFolderNoteCounts() – returns a map of folderId -> count for all folders
GitHub
GitHub
. It joins local_notes and note_folders. We need to add localNotes.noteType = note to the join condition or the where clause. We can do:
..where(localNotes.deleted.equals(false) & localNotes.noteType.equals(NoteKind.note.index))
before grouping. This way, folder counts exclude any templates.
Search Results: Modify search to omit templates. Duru’s search (unified search) works via FTS or tag queries
GitHub
:
In the FTS query, currently:
SELECT n.* FROM local_notes n 
JOIN fts_notes f ON n.id = f.id 
WHERE n.deleted = 0 AND f MATCH ? 
ORDER BY n.updated_at DESC;
We will change WHERE n.deleted = 0 to WHERE n.deleted = 0 AND n.noteType = 0
GitHub
. This ensures the query doesn’t retrieve templates. We already prevented templates from entering fts_notes via triggers, but adding the condition is an extra guard (in case some template slipped in or noteType wasn’t added to trigger in an older migration scenario).
The tag search (when a query starts with #) looks up note IDs by tag and then selects notes by those IDs
GitHub
GitHub
. It currently filters deleted=false
GitHub
. We need to also filter noteType=note there. So:
..where((t) => t.deleted.equals(false) & t.id.isIn(ids) & t.noteType.equals(NoteKind.note.index))
This way if a template somehow had a tag (which could happen if user tags a template for organization), it won’t show up in tag search results.
Smart Folders & Saved Searches: Smart folders are essentially saved search presets or user-defined filters. Because we filter at the base data source (repository.list or DB queries), smart folder contents will naturally exclude templates. For instance, a smart folder for “All notes with attachments” should not include templates even if a template had an attachment tag, because our getAllNotes() fed into it only returns real notes. Similarly, any saved search execution that goes through db.searchNotes or repository queries will respect the noteType filters we added. We should double-check SavedSearch execution logic: it likely calls db.searchNotes(query) or specific tag/folder queries
GitHub
GitHub
. By updating those underlying calls (as above), saved searches won’t surface templates unless the search explicitly targets them (which normal UI won’t allow).
Bulk Operations: Duru supports bulk actions on selected notes (e.g. multi-select delete or move). We must ensure templates are never inadvertently included in these selections. Since templates aren’t shown in any listing or search, the user cannot multi-select them in the normal UI. Additionally, the provider that tracks selected note IDs for batch ops should only contain IDs visible in the list. For safety, if there’s any batch operation that queries all notes (unlikely), it should also filter by noteType. We can audit functions like TaskRepository.archiveAllCompleted() or similar to ensure they don’t sweep up templates. Most likely not an issue, but worth noting.
Notification/Badge Counts: If the app displays a badge for “Inbox” or similar counts (like unread email notes count via inbox_unread_service.dart or similar), those counts come from queries on notes in the Inbox folder. We have already handled folder counts. We should also ensure any such service filtering uses noteType, but since it likely uses the folder count or direct DB queries with deleted=false, adding noteType to those DB queries is necessary. For example, an Inbox unread service might query local_notes where a tag or folder equals Inbox and not deleted – add noteType=note to that condition. The principle is the same: only count actual notes.
Task Extraction: (Edge consideration) Duru extracts tasks (checkbox list items) from note content into a NoteTasks table for task management. We should ensure templates do not interfere here. If a template contains checklist items (e.g. a “To-Do” template with - [ ] lines), we do not want those appearing in the user’s task list. By default, tasks are extracted when a note is saved or edited (via NoteTaskSyncService which watches notes
GitHub
GitHub
). We should disable task sync for template notes. Implementation: in NoteTaskSyncService.initializeNoteTaskSync(noteId), we can check if that note is a template and simply return without setting up a subscription. Similarly, when toggling a task or adding tasks, if the parent note is a template, skip updating note content. This could be done by checking LocalNote.noteType in these methods. If not addressed, a template with tasks would get tasks extracted (since the service currently listens on all notes changes). Alternatively, we only ever call initializeNoteTaskSync for notes opened in the editor. If we never open templates in the normal editor or we explicitly avoid initializing it for templates, we are fine. For thoroughness, add a check:
final note = await _db.getNote(noteId);
if (note?.noteType == NoteKind.template) return;
at the top of initializeNoteTaskSync. This ensures template content’s checkboxes are ignored. Also ensure any global task queries (like “all open tasks”) exclude tasks whose parent note is a template. This likely requires joining NoteTasks with LocalNotes in the query; adding a join filter for noteType=note. This prevents template-derived tasks from cluttering task lists if they were accidentally extracted.
UI Safeguards: The UI should not list templates in recents or counts. For instance, if there’s an “All Notes count” somewhere, that might call db.getLocalActiveNoteIds()
GitHub
. That currently selects all notes where deleted=false and collects IDs. We should filter that as well so it doesn’t count templates as active notes. If getLocalActiveNoteIds is used for sync or conflict logic, excluding templates is likely fine (templates are active, but treating them separately might simplify logic). Since they sync via same mechanism, it’s probably not critical to exclude in that method, but for consistency we could.
In the UI “Recent notes” section (if any), ensure it uses a query that excludes templates. If they use getRecentlyViewedNotes(limit=5)
GitHub
, that selects where deleted=false, ordered by updatedAt, but no explicit template filter. We should add one there too. Otherwise, if a template was recently created or edited, it might appear in a “Recent” list or widget. So:
..where((n) => n.deleted.equals(false) & n.noteType.equals(NoteKind.note.index))
in that method.
After implementing these filters, templates will live “invisible” to the user unless we deliberately fetch them. We will explicitly fetch them in a separate UI (e.g. a Templates management screen or template pickers). This compartmentalization maintains an uncluttered user experience – users won’t inadvertently come across templates in their note feed, search results, or counts. Testing filters: This is crucial – write tests to verify that template notes do not appear where they shouldn’t:
After creating a template, calls to notesRepository.localNotes() or db.allNotes() should not include it.
Templates should not count towards folder note counts (test that a folder with only a template yields count 0).
Search for a keyword present in a template should return no results (unless explicitly searching templates, which our UI doesn’t do).
Verify that adding a tag to a template and searching by that tag yields no result.
If possible, simulate UI providers: e.g. the filteredNotesProvider which uses currentNotesProvider (backed by db.watch(localNotes)) needs to ensure it’s filtering as well. We might need to adjust the currentNotesProvider if it directly watches the DB; likely it uses a query with deleted filter – ensure we incorporate noteType there.
Smart folder rules: e.g. a smart folder “Open Tasks” that collects notes containing tasks – ensure a template with a checkbox is not in its computed results (by virtue of noteType filter or skipping task extraction as mentioned).
All such tests should pass, confirming that templates remain hidden except where we explicitly surface them.
6. Riverpod Providers
Introduce dedicated Riverpod providers for template data, analogous to those for notes, to integrate templates into the app’s reactive state management. These providers will allow the UI to easily access the list of templates or recent templates and respond to changes (e.g. new template added, template edited).
Template List Provider: Create a provider that yields the list of all template notes (sorted appropriately). For example:
final templateListProvider = StreamProvider<List<LocalNote>>((ref) {
  final db = ref.watch(appDbProvider);
  // Watch all non-deleted templates
  return (db.select(db.localNotes)
           ..where((n) => n.deleted.equals(false) & n.noteType.equals(NoteKind.template.index))
           ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
         .watch();
});
This uses Drift’s .watch() to get a stream of LocalNote whenever the template table subset changes. By watching appDbProvider, it automatically rebuilds if the database instance changes (on login/logout). We filter noteType == template and deleted == false, ordering by last updated (so that newly created or edited templates appear at top). The provider will emit the current list of templates and update in realtime if any template is added, edited, or removed (deleted).
Alternatively, we can expose this via the repository: e.g., add NotesRepository.watchTemplates() that does the above query, then do ref.watch(notesRepositoryProvider).watchTemplates(). Either approach is fine; direct DB access is straightforward here.
Recent Templates Provider: Provide a subset of templates, for quick access (e.g. in a template picker showing most recently used or created templates). If by "recent" we mean recently used (applied) templates, we might need to track usage. However, since usage is also correlated with updatedAt if we update a template’s timestamp on each use, a simpler approach is to use either updatedAt or creation time. We’ll interpret “recent” as recently modified or created for now. Implement:
final recentTemplatesProvider = Provider<List<LocalNote>>((ref) {
  final templates = ref.watch(templateListProvider).maybeWhen(orElse: () => [], data: (t) => t);
  // Return the top 3 templates
  final count = templates.length;
  if (count <= 3) return templates;
  return templates.sublist(0, 3);
});
This takes the data from templateListProvider and simply returns the first 3 entries (which, given the sort by updatedAt, will be the 3 most recently edited/created templates). These can be shown as quick options.
If we wanted to truly track “recently used” templates, we could do something more advanced (like record last-used timestamp in metadata whenever a template is applied, and sort by that). That’s beyond the scope here, so using updatedAt as a proxy is acceptable (especially if the user rarely edits templates, updatedAt will basically reflect creation time, giving the first-created templates; but if they edit a template or we decide to update updatedAt on every apply, then it aligns with usage).
Individual Template Provider (if needed): If we have a screen to edit a single template, we can use an Editor route with the noteId. In that case, we might have something like:
final templateProvider = StreamProvider.family<LocalNote?, String>((ref, templateId) {
  final db = ref.watch(appDbProvider);
  return db.watchNote(templateId); // watchSingleOrNull on local_notes by id
});
This could feed a template editing UI to react to external changes. But since templates likely only change when user edits them on that device, this might not be heavily used. Still, it’s easy to add if needed (similar to how we watch notes).
Usage in UI: The templateListProvider will be used for any Template Management screen or section (see Section 7). The recentTemplatesProvider will be used in places like the New Note FAB menu or template picker dialog to highlight a few templates (if needed). These providers ensure consistency: if a user creates a new template via “Save as Template,” the providers will automatically include it (because the DB insertion triggers the .watch stream to emit a new list). If the user deletes or renames a template, the UI bound to these providers updates automatically.
Folder Providers Impact: There might be providers like unfiledNotesCountProvider or others that should exclude templates. If such providers exist (for example, an InboxCountProvider reading from DB), ensure they use the updated DB queries with noteType filtering. Likely they already rely on the DB functions we updated in Section 5, so no separate provider changes needed – it will naturally produce correct values after our DB query changes.
Ensure No Conflicts: The addition of template providers should not conflict with the existing providers. We name them clearly (templateListProvider, etc.). They will live alongside notes providers in providers.dart or a relevant module. For instance, in providers.dart we might add:
final templateListProvider = StreamProvider<List<LocalNote>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchTemplates(); // if we implemented in repository
});
Or use the direct DB approach as shown.
Providers for UI State: If we introduce any UI where templates can be filtered or sorted, we might add state providers for that. For example, if we allow sorting templates by name or date, a templateSortProvider could drive the order. Initially, we assume a default sort by date is fine, so no extra state needed.
Testing Providers: Write tests using ProviderContainer to ensure that adding a template triggers templateListProvider to update. For example, seed a container with a fake in-memory DB, add a template note, and expect the provider’s value contains that note. Similarly, test that deleting a template removes it from the list. If using Riverpod’s StreamProvider, we can simulate by manually calling the underlying DB insertion and then reading the provider state. Also test that recentTemplatesProvider correctly returns a limited sublist.
By introducing these providers, we integrate templates into our reactive app model, making it easy to build UI components that display templates and stay up-to-date. Experienced engineers on the team can follow this pattern (mirroring how notes and folders are handled via providers) to wire templates into the app.
7. UI Integration Points (FAB, Picker, Editor, Chip)
We will introduce several UI affordances for templates to make them accessible and manageable to the user while keeping them out of the main note flow. Key integration points and their implementation details:
New Note FAB Template Picker: Enhance the “New Note” action to allow starting from a template. Instead of the FAB immediately creating a blank note, we provide choices:
FAB Menu or Bottom Sheet: When the user taps the New Note FAB (➕), present a menu of options: “Blank Note” and “From Template…”. Selecting “From Template…” opens a template picker dialog. Alternatively, we can implement an expanding FAB (speed-dial style) that on tap (or long press) reveals sub-actions. For a simpler implementation, tapping FAB can show a bottom sheet listing templates (and an option for blank note).
Template Picker Dialog: Design a dialog or bottom sheet titled “Create from Template”. It will list the available templates fetched from templateListProvider. Each template can be shown with its name (and perhaps a brief preview or icon). Also include a “Blank Note” option at the top or bottom. For visual consistency, use ListTiles or buttons. Example: the sheet could show:
“📄 Blank Note” (always present)
Then a divider or heading “Templates:”
Then each template name as a selectable item (possibly with an icon like 🗒️).
Behavior: If user chooses Blank Note, proceed with existing blank note creation (the app likely already handles this by navigating to the editor with no noteId, which triggers a new note). If a template is chosen:
Call notesRepository.createNoteFromTemplate(templateId) (from Section 2) to instantly duplicate the template content into a new note. This returns a LocalNote for the new note.
Navigate to the note editor screen for that new note (pass its id into the editor). This opens the note for the user to start editing. The editor will show the template’s content and title pre-filled.
Log an analytics event template_used (with template name/ID) at this point (see Section 8).
The template picker dialog should dismiss after selection.
UI Considerations: The FAB icon might change to indicate multiple options (some apps use a FAB with a dropdown arrow or a split FAB). If using a bottom sheet, make sure to blur or dim background for focus. The template list may be scrollable if there are many templates. For a small number, showing them directly is fine. Possibly highlight the default templates with icons (e.g. 📋 for “Meeting Notes”, 📓 for “Journal”, etc., if available).
No Added Wait: The duplication happens locally and is fast (just a DB insert), so we can navigate immediately. We might show a brief toast “Note created from template ‘X’” if desired, but since we take the user to the note, feedback is inherent.
Editor App Bar Template Actions: Within the note editing screen, provide an option to apply a template to a new note or save as template:
Apply Template to Current Note: If the user opens a new blank note and then decides to fill it with a template, we allow that via an app bar action. For instance, an icon button “Apply Template” (could use an icon like 📝 or a templates icon). This is most relevant when the note is empty. We’ll implement:
In the editor’s AppBar overflow menu or toolbar, add “Apply Template” (or “Insert Template”). Tapping it opens the same template picker dialog as the FAB (or a simplified version listing templates).
If the current note is completely empty (no title/body changes), selecting a template will populate the editor fields with the template’s title and body. Under the hood, instead of creating a new note, we modify the existing draft:
Set the editor’s title text and body text controllers to the template’s content. (The ModernEditNoteScreen uses a unified text field where the first line is title and rest is body. We might need to split the template content into title vs body. Alternatively, since the template has a title field, we can set that as the initialTitle and template body as initialBody, then recreate the controller text. But dynamic changes after the controller is already set are tricky. Instead, we might close the current screen and reopen a new one from template, but that’s clunky.)
A simpler approach: when user chooses a template here, we can essentially do the same as createNoteFromTemplate but replace the current draft note:
Delete the current draft note (if it was not yet saved to DB, there might not be anything to delete – if an ID was pre-generated, mark it deleted or reuse it).
Create a new note from template as in FAB flow, and open that. Possibly with a smoother transition.
However, if the current note already has an ID and is being edited, replacing its content might be confusing in terms of sync (the app might treat it as the same note with new content). It might be easier to simply navigate away (pop current editor) and push a new editor loaded from the chosen template.
To avoid complexity, we can restrict “Apply Template” to only be enabled when the note is new and untouched. If _hasChanges is false and no content, then allow it. If the user has typed something already, either disable the action or show a confirmation “Replace current content with template?” and proceed if confirmed.
On applying, treat it similarly to selecting from FAB: navigate to an editor with a new note from that template (essentially discarding the blank draft). This way, we keep the logic unified.
This feature is a convenience; users can always choose templates from the start (FAB). But providing it in-editor covers the case “I opened a blank note, then decided to use a template instead.”
Save as Template (Overflow Action): When viewing/editing a normal note, allow the user to save its content as a reusable template:
In the editor’s overflow menu (“⋮”), add an item “Save as Template”. This is visible only if the current note is a regular note (noteType=note). It should be hidden or disabled for template notes (no point saving a template as another template).
When selected, prompt the user to name the template. We can show a simple dialog: “Save as Template – Enter template name:” with a TextField pre-filled with the current note’s title (or “Untitled” if blank). The user can modify the name if they want this template to have a different title than the note’s title.
On confirm, use NotesRepository.createTemplate(name, body) to create a new template entry locally
GitHub
GitHub
 (fast, offline). The body content will be exactly the note’s body content. (We might also copy the note’s title into the template’s body if we want the template content to include a title line, but since templates have a separate title field, we typically treat that as the template’s name only, and the body carries the content structure).
Immediately close the dialog. We can show a Snackbar “Template saved” for feedback. The template will now appear in the template list (via templateListProvider) and be queued for sync.
Do not navigate the user away from the note – they can continue editing it. Saving as template is like a “Copy” action.
Log template_saved analytics event (with template name) on completion.
Under the hood, createTemplate enqueues sync; if it fails later, we will handle via Sentry (the user still has the template locally, and will sync on retry).
Edge cases: If the note has attachments or other metadata, those will be included in the template’s content? In our approach, we only copy the text content. Attachments might not carry over (unless we handle them – out of scope now). That’s fine; templates likely focus on text structure. We can mention in documentation that attachments aren’t duplicated into templates via this action.
After saving, the template is independent of the note. If the user updates the note later, it doesn’t affect the template (and vice versa).
Prevent misuse: If user tries to “Save as Template” on a note that is itself a template (shouldn’t see the option), or if they spam it, they’ll just create multiple templates (which is allowed). No harm, aside from duplicates the user can delete if needed.
From Template Chip in Editor: When a note was created from a template, indicate this in the editor UI:
If a note has sourceTemplateId metadata (meaning it originated from a template), display a small “From Template” label in the editor. A good approach is a Chip widget (Material Design chip) with text like “From template: Meeting Notes”.
Placement: We want it to be subtle but noticeable. Options:
Under the note title (for a unified editor, perhaps at the top of body content area, we can insert a non-editable element).
Or in the app bar as a subtitle (if the app bar is not too cluttered). Possibly in the app bar, below the note title or next to it.
Or as an overlay at bottom of the screen.
A practical solution: If using a unified text field, we cannot inject the chip into the text easily. Instead, we can show it above the keyboard area or in a sticky footer when editing. However, the simplest might be just below the app bar, with some padding, not part of the scrollable text.
For example, in ModernEditNoteScreen build method, if note.sourceTemplateTitle is not null, render a Row with a Chip:
if (_sourceTemplateTitle != null) 
   Padding(
     padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
     child: Chip(
       label: Text("From template: ${_sourceTemplateTitle}"),
       backgroundColor: Theme.of(context).chipTheme.backgroundColor?.withOpacity(0.1),
     ),
   );
Style it to be subtle (perhaps smaller font or low-opacity background). The text includes the template’s name.
Optionally, make the chip clickable: tapping it could open the original template for reference (perhaps in a read-only view or full edit if we allow editing templates). This would be a nice touch: user can quickly jump to update the template if needed. If we implement this, on tap simply navigate to the template’s editor (we have its ID). For safety, open it read-only or at least indicate clearly that they are now editing the template itself, not the note.
Ensure to load the template title: Since sourceTemplateTitle is stored in encryptedMetadata, when loading the note in editor, parse that JSON. In _loadNoteMetadata()
GitHub
 after fetching the note, do:
if(note.encryptedMetadata != null) {
    final meta = jsonDecode(note.encryptedMetadata!);
    if(meta['sourceTemplateTitle'] != null) {
       _sourceTemplateTitle = meta['sourceTemplateTitle'];
    }
}
Then call setState so that UI shows the chip. We already do something similar for tags and pin state
GitHub
.
The chip should be removed if the note is converted to a template or if the metadata is not present. Since sourceTemplateId stays as part of note metadata for its lifetime, we’ll always show it for those notes. (If a user substantially changes a note that was from a template, the chip still shows origin – which is fine, it’s just a historical note).
This chip does not show for the template itself or for normal notes. Only when metadata indicates origin.
Also, do not show a chip in a template’s own editor indicating “template” – that’s redundant. The UI can have some subtle indicator if needed (like the screen title could say “Edit Template” instead of “Edit Note” if we differentiate mode, but that’s a stretch goal).
Manage Templates UI: (Potential extension) Provide a way for users to view and edit all their templates. Since templates are hidden from main UI, a dedicated screen can list them using templateListProvider. This could be accessible via Settings or an overflow menu from the notes list (e.g. a “Manage Templates” option). On that screen, show a list of templates (similar to note list but simpler). Allow actions like:
Tap a template to edit it (open in the editor screen with noteType=template – we can reuse the editor for this).
Rename or delete templates (maybe via swipe actions or long-press context menu).
Possibly create a new template from scratch (a FAB on this screen to “New Template” which opens an empty editor in template mode). This covers the case where a user wants to make a template not derived from an existing note.
Given time constraints, this manage screen can be simple, but it’s important for completeness: without it, users can create templates but only edit them if they remember to “Save as Template” again from a note or if they choose one and then edit that instance (which doesn’t update the template).
We plan for this screen but it was not explicitly requested. However, including a mention: “We will add a ‘Templates’ screen in Settings for advanced users to organize their templates, using templateListProvider for content.” ensures future-proofing.
In summary, the UI integration ensures that:
Users can create new notes from templates easily (via FAB or editor action).
Users can save existing notes as templates quickly.
It’s clear when a note was based on a template (via the chip).
Users have a pathway to edit and manage templates (either via template picker on tap or a dedicated screen).
Testing UI behavior:
Test the FAB template picker: when selecting each option, does it correctly route? For blank note, ensure a new note opens as before. For a template, ensure the new note’s content matches the template. Possibly write a widget test that fakes two templates in provider and taps one.
Test Save as Template: create a note with known content in editor, trigger Save as Template, input a name, confirm. Then verify (via providers or direct DB call) that a new template exists with that content and given name. Also verify a snackbar or indication is shown.
Test the chip: create a note from a template, open it in editor, verify the chip is displayed with correct template name. Test tapping it (if implemented clickable) opens the template editor.
Test that Save as Template doesn’t appear for a template note (open a template for editing, open menu – should not show).
UI edge: If a note from template is duplicated into another template (conceivably if someone did Save as Template on a note that itself had an origin), it’s fine – that second-generation template’s content would include the first template’s structure, but we don’t propagate any link (we do not set sourceTemplate for templates themselves).
Ensure the template picker lists include latest changes: e.g. after saving a new template, if the user immediately hits the FAB, the new template should appear in the list (thanks to provider reactivity).
By carefully implementing and testing these UI points, we give users the full power of templates in an intuitive way, consistent with Material design and Duru’s UX.
8. Analytics & Sentry Instrumentation
Incorporate comprehensive logging and monitoring to track template feature usage and catch any issues in production. We will use the existing AnalyticsService for usage events and Sentry (via AppLogger breadcrumbs or direct integration) for error monitoring.
Analytics Events: Add the following events to help understand how templates are used:
template_used – Log when a user creates a new note from a template. This should include details like which template was used. We can call:
analytics.logEvent('template_used', {
    'template_id': templateId, 
    'template_title': templateTitle
});
For instance, right after duplicating the template (before navigating to editor, or once the editor opens). This helps product know which templates are popular.
template_saved – Log when a user saves a note as a template. Include perhaps the length of the content or the source note’s context. Example:
analytics.logEvent('template_saved', {
   'note_id': currentNoteId,
   'template_title': chosenTemplateName,
   'note_length': currentNoteBody.length
});
Logged after successfully creating the template. This event indicates user-generated templates.
template_opened – Log when a user opens a template in the editor for viewing or editing. We’ll trigger this either on navigating to the template editor screen or when the template is actually loaded. E.g., in the Templates management screen, if they tap a template to edit, log event with template_id. Or if user tapped the “From template” chip to view original, log that.
Additionally, we might log template_list_viewed when the user opens the "Manage Templates" screen (if we add one), to gauge interest.
The AnalyticsService likely has methods for logging events (perhaps it’s an amplitude or Firebase under the hood). Using it similarly to existing events (for consistency, see how other events are logged – e.g., analytics.trackEvent('note_shared') maybe exists). We should ensure to throttle or not spam these events. They are triggered by distinct user actions, so it’s fine.
Sentry Error Tracking: Augment error handling to capture any template-related failures:
Sync Failures: If a template fails to sync (e.g., network down, or server error), our SyncService’s retry logic will handle it eventually
GitHub
GitHub
. But we want visibility. We can use the AppLogger to log a warning or breadcrumb in such cases. For example, in pushAllPending, in the catch block where it prints “Failed to push upsert_note…”
GitHub
, also do:
_logger.error('Sync error: Failed to push note ${op.entityId}', error: e);
If AppLogger is configured to send errors to Sentry (likely LoggerFactory.instance ties into Sentry for error-level logs), this ensures the failure is reported. We might see it grouped with other sync errors, but we can include context that noteType was template if we know (we could check if the note we fetched was noteType template and mention that in the log data).
Seeding Failures: Wrap the default template seeding in try-catch. If reading the asset or inserting into DB fails, catch and log to Sentry:
try {
  seed templates...
} catch(e, stack) {
  Sentry.addBreadcrumb(Breadcrumb(message: 'Template seeding failed', data: {'error': e.toString()}));
  Sentry.captureException(e, stackTrace: stack);
}
(or using AppLogger to log an error). This way we are alerted if, say, the JSON asset wasn’t bundled or a migration logic flaw prevented seeding.
Also, if any template fails to insert (maybe a DB constraint, though unlikely), log it.
Template Duplication Errors: Although creating a note from template is straightforward, we add defensive error handling. E.g., in createNoteFromTemplate, wrap the DB calls in try/catch. If an exception occurs (DB write failure, etc.), log a Sentry error:
_logger.error('Failed to create note from template $templateId', error: e);
And maybe show a user-facing toast “Failed to apply template. Please try again.”
Similar for “Save as Template” – if for some reason createTemplate returned null or threw, catch in the UI layer and log error, and show a message “Failed to save template”.
Crypto Errors: If encryption or decryption ever fails for templates (e.g., CryptoBox throws), ensure that’s caught and logged. The existing code already catches decryption issues in pull and prints warnings
GitHub
GitHub
. We can elevate those prints to Sentry logs (so we know if a template failed to decrypt, which might indicate key issues). For instance, if decryptJsonForNote throws for a note, we log a warning with noteId. It might be beyond scope to change those now, but keep in mind.
UI Unexpected States: If any UI action should not happen (like user tries to use template when none exist), log a breadcrumb. For example, if templateListProvider is empty and somehow user taps "From Template", we could log a warning “No templates available to apply” (though UI will likely disable that state).
Breadcrumbs for Template Usage: Besides errors, we might want breadcrumbs to trace template flows. For instance, add a breadcrumb when user selects a template:
Sentry.addBreadcrumb(Breadcrumb(category: 'template', message: 'User applied template $templateTitle'));
This will be attached to any subsequent error report, providing context that a template was involved in the session. Similarly, breadcrumb on save as template action. This level of detail can help debug if, say, a crash happens after applying a template (we’d see that breadcrumb).
We should ensure these breadcrumbs don’t flood Sentry – use them meaningfully.
The Sentry integration may already capture unhandled exceptions; our goal is to capture handled ones (like a sync failure we recover from but want to log).
Performance Monitoring: Templates shouldn’t add heavy operations, but if needed, we could track how long template encryption or duplication takes (probably negligible). Not a priority unless issues arise.
Sentry Tagging: Perhaps tag errors with something like feature:template when relevant, to filter them easily. For example, when logging an error in template duplication, we can add Sentry.configureScope((scope) => scope.setTag('feature', 'template')); before capturing. This way, we can search Sentry for template-related issues quickly.
Monitoring Dashboard: We’ll monitor template_used and template_saved metrics to see adoption. If analytics show low usage, maybe the feature needs more discoverability. High usage of certain default templates can inform future improvements (e.g. if “Meeting Notes” is rarely used but “Daily Journal” is popular, etc.).
In development and QA, test that:
Analytics events fire at the correct times with correct payload. If using a debug analytics logger, verify in console.
Induce some error conditions to ensure Sentry logging works: e.g., try to call createTemplate with an invalid input to force an error (maybe temporarily simulate by throwing inside it) and see that it gets logged. Or simulate a sync failure by pointing to an invalid endpoint and ensure we log the error. These tests might be manual or using a staging environment with Sentry.
Check that no sensitive data is in logs: Our events/logs identify templates by ID or generic name; content is not logged. That’s good (we should avoid logging full note content in Sentry to maintain privacy). So our logging should use IDs or possibly truncated titles at most.
By instrumenting analytics and error logging, we ensure we can measure the feature’s usage and quickly react to any issues or edge-case failures, thus maintaining a robust production rollout.
9. Testing Strategy (Unit, Widget, Integration)
A thorough testing plan will validate both the functional correctness of the template feature and its integration into the app’s workflows:
Database Migration Test: Create a unit test simulating upgrade from schema 9 to 10. For example, instantiate an in-memory Drift database with schemaVersion 9, insert a sample note, then perform migration to schemaVersion 10. Verify:
The local_notes table now has a noteType column defaulting to 0 (for the existing note). You can query the note and ensure its noteType is NoteKind.note.
New notes can be inserted with both noteType values (test inserting a template and a normal note).
The triggers still function (insert a new note and ensure it appears in fts_notes, insert a template and ensure it does not appear in fts_notes).
If possible, test onUpgrade logic: a note inserted pre-migration remains non-deleted, noteType default correctly assigned.
Repository Unit Tests:
Template Creation: Call notesRepository.createTemplate and assert that:
It returns a LocalNote with the given title/body and noteType=template.
The note exists in the DB (db.findNote(id)) with noteType == template.
A PendingOp was enqueued with kind 'upsert_note' for that ID
GitHub
.
The local note’s updatedAt is set (and reasonably close to now).
Note Duplication from Template: Setup a template in the DB (or create via repository), then call createNoteFromTemplate(templateId). Verify:
The returned note has noteType=note, title and body identical to template’s.
Its encryptedMetadata contains sourceTemplateId = templateId (and perhaps sourceTemplateTitle).
It’s present in DB and pendingOps.
After this, calling notesRepository.getNote( newNote.id ) returns the correct data.
If the template had tags or links, decide if those should copy or not; currently we do not copy tags/links in duplication (we didn’t implement that). We can test that new note has no tags (unless we decide to copy – likely not).
“Save as Template”: Simulate by calling createTemplate(title, body) and ensure it yields expected DB state. (This is basically same as first bullet – maybe combine).
Filtering Logic: With a mix of notes and templates in the DB, test that repository and DB query functions yield correct results:
Insert e.g. 2 notes and 2 templates. Then:
db.allNotes() returns only the 2 notes (none of the templates).
db.getNotesInFolder(someFolder) – if one note and one template are in that folder (insert note_folder entries accordingly), the result should contain only the note.
db.getUnfiledNotes() – if one template and one note have no folder, result should include only the note.
Search: if a template and a note share a keyword, db.searchNotes(keyword) should return only the note. Test tag search similarly.
Smart folder: perhaps simulate repository.list() result; ensure templates are absent (this is indirectly tested by allNotes).
You can also test that notesRepository.list() (which likely uses db or folderRepo) returns no templates.
Test that deleting a template (set deleted true or via repository.deleteNote on template ID) keeps it out of queries as well (deleted filters already handle that).
Providers and UI State Tests:
Using a ProviderContainer, add a few template entries to the in-memory DB, then read templateListProvider. It should contain those templates sorted by updatedAt. Add a new template (via repository or direct DB insert) and ensure the provider updates (perhaps by awaiting a short duration or by reading the stream).
Test recentTemplatesProvider: if there are 5 templates, ensure it returns only top 3. If fewer, returns all.
Test that editing a template (update its title) triggers the provider to emit a new sorted list if appropriate.
Ensure that none of the note providers (like filteredNotesProvider) include templates. This might involve injecting some fake currentFolder and filterState to get the list and checking no noteType=template in there.
Analytics Calls: These can be tested by injecting a mock AnalyticsService into the provider (if our providers allow overriding). For simplicity, we can test that our methods call AnalyticsService appropriately via a spy. Alternatively, since analytics is side-effect, unit test might not be strictly needed – but we can assert that when createNoteFromTemplate is executed in a UI context, the event is logged (maybe by checking a log output if our test logger captures it).
Sentry Logging: It’s hard to unit test Sentry integration directly, but we can simulate an error and ensure our logger is called. For example, cause createNoteFromTemplate to throw by passing an invalid templateId and see if our catch block logs something. If our AppLogger is injectable or global, we might replace it with a test logger that records messages.
Widget/Integration Tests:
Template Picker UI: Create a test where templateListProvider is preloaded with some templates (maybe override the provider to return a fixed list). Render the widget that shows the FAB and triggers the picker. Simulate tapping the FAB, selecting a template, and verify that navigation to editor happened with correct state.
This might require a lot of scaffold (like a MaterialApp and routes). If that’s too complex, at least test the TemplatePicker widget in isolation: give it some template items and simulate taps.
Save as Template UI: Write a test for the editor screen:
Load it with a sample note (maybe by providing initialTitle and initialBody to ModernEditNoteScreen).
Open the overflow menu (simulate tap on menu button) and tap “Save as Template”.
In test, provide a way to handle the name dialog. Possibly override showDialog to immediately return a given string, or simulate user typing in a dialog.
After the action, verify that templateListProvider now includes a new template with the expected name. This ensures the whole flow from UI to repository to DB works.
Also verify a Snackbar “Template saved” appears (WidgetTester can check for SnackBar).
From Template Chip: Test that when opening a note created from template, the chip is visible.
Setup: Insert a note with encryptedMetadata containing sourceTemplateTitle “Meeting Notes” into DB, and open editor for that noteId.
Verify that the chip widget is present in the widget tree with text containing “Meeting Notes”.
Simulate tapping it if clickable: ensure it navigates to template editor (maybe check navigator pushed correct route).
Manage Templates Screen: If implemented, test listing and editing:
Render the template list screen with a couple templates in provider, verify the list shows all template titles.
Tap one to edit, ensure the editor opens with that content.
Simulate deleting a template (if we have swipe or delete button), then verify it’s removed from list (provider updates).
Integration Sync Test: (Complex but valuable) Simulate two devices syncing templates:
Use two separate in-memory database and repository instances to mimic Device A and Device B.
On Device A: create a template (via repository.createTemplate). Simulate push sync by directly calling a fake Supabase API that stores the encrypted data in a dummy variable or structure.
On Device B: simulate initial pull by feeding the encrypted data from that dummy store into NotesRepository.pullSince. Ensure that after pull, Device B’s DB now has the template with correct content and noteType.
Then on Device B, create a note from that template via createNoteFromTemplate, and maybe sync it back, and see Device A receives it. This tests cross-device consistency.
This is quite involved to simulate encryption without the real Supabase; one strategy is to bypass actual encryption by using the same CryptoBox on both (since user is same, key is same), essentially the dummy “server” can just shuttle the bytes.
At minimum, test that our pushAllPending correctly calls api.upsertEncryptedNote with properly encrypted payload (perhaps by injecting a stub api that verifies the propsEnc contains an expected field when decrypted with the known key).
Also simulate a conflict or error: e.g., have Device A and B both create a default template “Meeting Notes” offline, sync both – likely you’d get two distinct templates on server. It’s tough to simulate conflict resolution because our system doesn’t have merging for separate notes (they’re separate IDs). So conflict is minimal.
Task Exclusion Test: If we added logic to exclude template tasks:
Create a template with a checklist item (body contains "- [ ] Template task").
Run whatever triggers task extraction (perhaps directly call _db.syncTasksWithNoteContent(templateId, content) as NoteTaskSyncService would).
Verify that no NoteTask was created for that template (the tasks table remains empty).
Conversely, a normal note with "- [ ]" should produce a NoteTask. This ensures our skip logic works.
By covering these tests, we ensure each piece (DB, sync, providers, UI flows) works in isolation and together. Especially important are the migration and filtering tests to catch any oversight that could surface templates where they don’t belong or break existing note logic. We will also use manual exploratory testing on a debug build:
Creating templates, ensuring they sync, trying offline scenarios, etc.
Confirm encryption by checking that on the server the title_enc/props_enc fields indeed appear (and maybe decoding them in a test environment to ensure they contain expected JSON with noteType).
This multi-level testing approach (unit -> widget -> integration) will give confidence that the Note Templates feature is production-grade and doesn’t regress other functionality. We should integrate these tests into our CI pipeline so that any future changes to notes/folders will run template tests as well, catching issues early.
10. Rollout & Operational Readiness
Finally, prepare for a smooth rollout of the template feature in production, ensuring compatibility, monitoring, and user support:
Feature Toggle (if needed): Determine if the template feature should be behind a feature flag for a gradual rollout. If risk is low, we can enable it for all users in the next app update. If a flag system exists, consider wrapping template UI in a check, but likely unnecessary as this is a contained feature.
Backward Compatibility: Acknowledge how older app versions interact:
As noted, older versions will see template notes as normal notes (since they don’t filter noteType). This could cause minor confusion (e.g., a template might show up as a note with weird content). However, given that once the user updates all devices the issue is resolved, and template content is likely obviously a template structure, this is acceptable. We will not attempt to hide templates on the server for old clients, because that would require server logic which complicates things. The time window and user impact is small (tech-savvy users with multiple devices might notice).
Ensure the server database can handle noteType in encrypted data: No changes needed on Supabase side because we embed it in encrypted JSON. The Supabase notes table doesn’t need a new column. So older clients will just store and retrieve that encrypted blob, oblivious to its contents.
Worst-case: If an old client user edits a template (thinking it’s a normal note), they might be editing the template’s content. That edit will sync and actually change the template. This scenario: User A on app v2 creates template T. User B still on app v1 sees note T (because their app doesn’t filter it out) and edits it. This will sync and update template T’s content for User A as well. This is a bit confusing (template changed unexpectedly), but not catastrophic. We accept this edge case since it requires mixed-version usage. Encouraging users to update will mitigate it. (We could also send an in-app message to update if we detect they have templates on one device and an old app on another).
App Update & User Communication: In release notes or onboarding, highlight the new templates feature. Possibly add a small in-app coach mark on the expanded FAB the first time, e.g., “You can now create notes from templates for quick structure!” This can drive adoption. Provide a brief description in App Store update notes (“New: Note Templates – create meeting notes or journals with one tap!”). If the app has a changelog dialog, include it.
Sentry Monitoring: Actively monitor Sentry after release for any template-related errors:
Particularly look for migration errors (if any DB migration to v10 issues arise, e.g., some users on older beta might have had conflicting changes).
Look for any exceptions in SyncService or Template creation flows. We have breadcrumbs to help debug those.
If a serious issue appears (e.g., templates causing crashes), we have the option to disable the UI entry points via a quick config (if we had a remote config). If not, we might issue a hotfix.
Ensure the Sentry environment is correctly set (so that our new logs actually show up). Possibly do a staged rollout (e.g., release to 5% of users) and watch Sentry for a day, then 100%.
Analytics Monitoring: After release, use the analytics dashboard to track:
How many users click “New from Template”.
How many use default templates vs create custom ones (template_saved vs usage of specific default IDs).
This will inform any UX tweaks (if usage is low, perhaps the feature isn’t discoverable enough; if only one template is used often, maybe promote it in UI).
Also track retention: Are template users more engaged? (Beyond scope, but we have data to find correlation).
Performance Considerations: The introduction of templates should not significantly impact performance:
The additional noteType column and filter adds negligible overhead to SQL queries (an indexed enum check is very fast, and our queries already filter by deleted which is similar complexity). To be safe, we included an index on (noteType, deleted) if needed.
Sync payloads include a few extra bytes for "noteType" and maybe template metadata – trivial impact on network and storage.
The default seeding adds 3 notes on first run – minimal overhead.
So we expect no user-facing perf difference. However, we will test that listing notes (especially search) still feels snappy after adding filters. Should be fine since we filter at SQL level (which might even slightly reduce results if anything).
Data Integrity: We should verify that template creation and usage doesn’t corrupt any data:
After rollout, verify that no templates inadvertently show up where they shouldn’t (through dogfooding and possibly writing an automated UI test scenario).
Ensure that deleting a template only deletes that item and doesn’t affect any notes created from it (they are independent).
Check that encryption keys work for templates on multiple devices (they should, as it’s the same mechanism).
App Store Compliance / Encryption Notice: If our app declarations for encryption need to be updated (some app stores require declaring use of encryption), we already had encryption for notes, so nothing new.
Support & Documentation: Update any user guides or FAQs to include “How to use templates”. Ensure customer support team is aware of the feature:
Provide them a summary: templates are stored like notes but hidden, possible issues (like user sees duplicate content if two devices out of sync versions, etc.).
Support should know how to instruct users to create a template, or troubleshoot (e.g., “if your template isn’t syncing, ensure you’re online; it will sync when possible”).
Future Updates: Plan for any future enhancements:
If later we allow sharing templates or downloading new ones, the groundwork (noteType) allows that.
If we discover through analytics that one of the default templates is rarely used, we might replace it in a future release (that’s fine; it will just seed a new one with a new ID, leaving old one as orphan if not used).
If we want to have template marketplace or more localization, we have structure to add it.
Cleanup of Legacy: Remove any now-obsolete code. For instance, if previously some placeholder for templates existed (like a hidden folder hack considered in docs), ensure we’re not still creating a "Templates" folder inadvertently. In our case, we went with noteType, so no old hacks to remove except making sure no UI element references a folder for templates.
Migration of Existing User “Templates”: It’s possible some users already had a note they use as a template manually. We are not auto-converting anything, but we might educate them via blog or tips that they can now formalize those as templates (by opening and doing Save as Template).
Crash Plan: In the unlikely event the template feature causes a severe problem (like data loss or app crashes), be ready to issue a patch or use a remote kill-switch:
Because the changes are integrated (DB migration etc.), disabling might be non-trivial. But worst-case, we could hide UI entry points via a remote config to prevent further use until fixed.
Data already created (templates) wouldn’t vanish, but if causing crash, we might instruct users to refrain until fix.
However, given the testing above, we anticipate a stable launch.
Overall, by adhering to this plan and performing the outlined tests, the Note Templates feature will be delivered in a robust, user-friendly manner. It aligns with Duru’s offline-first, encrypted ethos and will support cross-device consistency with minimal hassle to users. We will monitor its rollout closely through Sentry and analytics, ensuring any issues are quickly resolved and that the feature is meeting user needs.

Kaynaklar


I'm afraid 


No file chosenNo file chosen
ChatGPT hata yapabilir. Önemli bilgileri kontrol edin.

Note Templates Implementation Plan
1. Drift Schema & Migration
To support template notes, extend the local database schema with a new note type field and migrate existing data safely. The LocalNotes Drift table will gain a noteType column (using an enum NoteKind { note, template }). This will distinguish normal notes from templates without a separate table, simplifying sync. Key tasks:
Add noteType Column: Define an IntColumn with an intEnum<NoteKind>() mapping. Set a default value of 0 (NoteKind.note) so all existing notes are classified as regular notes
GitHub
GitHub
. For example:
IntColumn get noteType => intEnum<NoteKind>()
    .withDefault(Constant(NoteKind.note.index))();
This ensures that after migration, every pre-existing note has noteType = NoteKind.note.
Bump Schema Version to 10: Increment the schema version from 9 to 10
GitHub
. Implement an onUpgrade step:
if (from < 10) {
  await m.addColumn(localNotes, localNotes.noteType);
}
This uses Drift’s migrator to add the new column to local_notes for existing users. The default will mark all current entries as normal notes. Verify via a migration test that upgrading retains data and correctly sets noteType = note for old rows.
Enum Definition: Create a NoteKind enum in Dart with values note (index 0) and template (index 1). Ensure the LocalNote data class is updated (via code generation) to include a noteType field of type NoteKind. This allows using the enum in code instead of raw int.
FTS Trigger Updates: Update full-text search triggers to exclude templates. The FTS virtual table (fts_notes) currently indexes note title/body when a note is inserted or updated
GitHub
. Modify these triggers’ WHERE clause to ignore template notes. For example:
INSERT INTO fts_notes ... 
WHERE NEW.deleted = 0 AND NEW.noteType = 0;
Similarly, in the FTS update trigger, only update or remove entries if the note is a normal note. This prevents template content from ever appearing in search indices.
Initial FTS Sync: On fresh installs, the onCreate seeding of FTS should also skip templates. The existing onCreate inserts all non-deleted notes into fts_notes
GitHub
 – append a condition to filter out templates. As a safeguard, when adding the column via migration, run a one-time SQL update to remove any template entries from FTS if they were accidentally indexed (not expected since templates are new).
Indexes (Optional): If needed for performance, add an index on local_notes.noteType (particularly combined with deleted = 0). Given the typically small number of templates, this is optional. All queries will explicitly filter on noteType, so indexing can marginally speed up filtering if note count is very large.
After this step, the schema cleanly differentiates templates, and existing notes are untouched except for the additional column defaulting to “note”. Tests: verify that migrating a pre-v10 database adds the column and that new notes can be inserted with either note type. The migration (v9→v10) should be covered by unit tests to ensure no data loss and correct defaults.
2. Repository & Sync Layer
Implement template creation and syncing in the repository and sync services, mirroring the offline-first approach used for folders and notes. Template creation must be local and instant, with remote updates deferred via the pending ops system. Key changes and additions:
Offline Template Creation: Add a new method (or overload) in NotesRepository to create a template note locally without waiting for server response. For example:
Future<LocalNote?> createTemplate(String title, String body) async { ... }
This will generate a new UUID for the template, set its fields, and mark noteType = NoteKind.template. It should call the database to insert the note and immediately enqueue a sync op:
final id = _uuid.v4();  
final now = DateTime.now();  
final templateNote = LocalNote(  
    id: id, title: title, body: body, updatedAt: now,  
    deleted: false, isPinned: false, noteType: NoteKind.template,  
    encryptedMetadata: null);  
await db.upsertNote(templateNote);  
await db.enqueue(id, 'upsert_note');  // queue for sync  
return templateNote;
This parallels regular note creation (which calls db.upsertNote then db.enqueue('upsert_note'))
GitHub
. The UI dialog for creating or saving a template should close as soon as this returns, since the operation is done locally. The user sees the template added (in the templates list) immediately, and any server communication happens later.
Deferred Remote Sync: The sync pipeline will pick up the new template via the PendingOps table. The existing SyncService periodically calls NotesRepository.pushAllPending() to process queued ops
GitHub
GitHub
. No special op type is needed for templates – they reuse 'upsert_note'. In pushAllPending, ensure it handles notes of both types uniformly: it already fetches the note by entityId and encrypts it, then calls api.upsertEncryptedNote
GitHub
GitHub
. We will include the noteType in the encrypted payload (see Section 3) but otherwise treat it like a normal note upload. The SyncService will retry failed syncs with exponential backoff as usual
GitHub
GitHub
. If the app is offline, the template remains queued; on network restore, SyncService.syncNow() pushes it.
Remote API: The Supabase note API already supports upsert of encrypted notes
GitHub
. The template will be synced as just another note record (with encrypted content). The server doesn’t need a schema change – noteType is embedded in the encrypted blob. Ensure the SupabaseNoteApi.upsertEncryptedNote call carries the encrypted title & props, and deleted: false (since templates are normal notes from the server perspective). On the server, it will get a new notes row with the given id and user ID. Cross-device, this means other clients will receive the template in their next pull (and will identify it via noteType in the decrypted data).
Sync on Other Devices: During pullSince, after fetching remote notes, decrypt and insert templates locally. Modify NotesRepository.pullSince to set noteType appropriately on incoming notes. We will parse the decrypted JSON for a noteType field and use it to assign the right enum value. Specifically, after decrypting props_enc for a note
GitHub
GitHub
, do:
final kindStr = propsJson['noteType'] as String?;  
final kind = (kindStr == 'template') ? NoteKind.template : NoteKind.note;
metadata = Map<String, dynamic>.from(propsJson);  
metadata.remove('noteType');
metadata.remove('body'); // etc. (already removing body, tags, links…)  
Then when constructing the LocalNote for upsert, include noteType: kind. This way, if a template was created on Device A, Device B will correctly mark it as a template on sync. If noteType is missing (e.g. notes created pre-v10), default to NoteKind.note. This ensures backward compatibility.
Duplication: Create Note from Template: Provide logic to apply a template by duplicating its content into a new note. In NotesRepository, implement Future<LocalNote> createNoteFromTemplate(String templateId) which:
Retrieves the template from the local DB: final templ = await getNote(templateId); (this returns a LocalNote with noteType = template).
Generates a new note (type = normal) with the same body (and possibly title) as the template. We can reuse the existing create method by calling, for example:
return createOrUpdate(
   title: templ.title, 
   body: templ.body, 
   metadataJson: { 
       'sourceTemplateId': templ.id, 
       'sourceTemplateTitle': templ.title 
   }
);
This leverages the existing createOrUpdate to handle DB insertion, tagging, and pending op enqueuing
GitHub
GitHub
. The provided metadataJson keys will be merged into the note’s encryptedMetadata. The result is a new LocalNote with the template’s content, stored as a regular note and queued to sync via 'upsert_note'.
Return the new note so the UI can navigate to it. This operation is offline-first as well – the user can start editing the new note immediately.
Prevent UI Blocking: All template operations (create, duplicate, etc.) should avoid awaiting network calls. For example, the “Save as Template” action should not call any API directly. It uses the above repository method, returns quickly, and any errors in syncing later are handled asynchronously. This is consistent with how folder creation was fixed to be local-only (creating a folder calls createLocalFolder and enqueues a sync op)
GitHub
GitHub
.
Folder Assignment: Do not assign folders to templates. When creating a template, leave it unfiled (no entry in note_folders). Templates exist outside the normal folder hierarchy. This simplifies filtering them out. (If a template somehow has a folder, e.g. user manually moved it via DB hack, it would still be excluded from folder views by our queries, as discussed in Section 5.)
Deleting Templates: A user deleting a template should be handled similarly to note deletion (set deleted = true and enqueue a 'delete_note'). Ensure any template deletion goes through the same repository method deleteNote(id) so that it’s flagged and synced
GitHub
. The UI for deleting templates might be in a manage screen or long-press action. No special logic needed except to perhaps confirm with user since templates are not easily recreated except via backup.
These repository changes align with existing patterns: offline DB writes plus queueing ops
GitHub
. Test cases: create a template and verify it appears in local DB with noteType=template and a pending op. Simulate pushAllPending and ensure the API call is made (the encrypted payload should include the template flag). Simulate a pull on another client and verify the template arrives with correct type. Also test createNoteFromTemplate: given a template, it should produce a new note (noteType=note) with identical content and a sourceTemplateId metadata linking back. Verify that duplication sets an op and that the original template remains unchanged.
3. Encryption & Metadata
All template data must be encrypted just like regular notes, preserving Duru’s zero-knowledge security model. We will use the existing CryptoBox mechanisms for content encryption, ensuring templates sync securely across devices. Key points:
Encrypt Template Content: When syncing, treat templates the same as notes for encryption. In pushAllPending, the repository builds a JSON of note properties (title, body, tags, etc.), then encrypts it with CryptoBox before upload
GitHub
GitHub
. We will include noteType in this JSON. For example:
final propsJson = {
  'body': note.body,
  'tags': [...],
  'links': [...],
  'isPinned': note.isPinned,
  'updatedAt': note.updatedAt.toIso8601String(),
  'noteType': note.noteType == NoteKind.template ? 'template' : 'note'
};
The 'noteType' is added as a string indicator. This entire blob is then encrypted via crypto.encryptJsonForNote(...) using the user’s key
GitHub
GitHub
. The encrypted bytes are sent to the server (props_enc column on Supabase). The template’s title is encrypted separately as title_enc (as is done for all notes)
GitHub
GitHub
. This means the server sees only ciphertext; it cannot distinguish a template from a normal note.
Decrypt and Store: On pulling notes from remote, the app decrypts title_enc and props_enc for each note
GitHub
GitHub
. We will parse out the noteType as described in Section 2. Specifically, after decrypting props_enc to a JSON, we remove known fields and get a metadata map
GitHub
GitHub
. We will remove 'noteType' from this map and use it to set the LocalNote.noteType field for the upsert. Any remaining fields in the metadata JSON (e.g. template source info, attachments, etc.) are encoded to string and stored in LocalNote.encryptedMetadata
GitHub
GitHub
. For a template note, typically metadata may be empty unless we add fields like default template flags. For a note created from template, the encryptedMetadata will contain its sourceTemplateId and sourceTemplateTitle which we explicitly added on creation. These too are encrypted in transit as part of props.
Maintaining Encryption Keys: CryptoBox likely derives per-note encryption keys (possibly using the note ID as salt for a symmetric key, or via user’s master key). We will continue to use the note’s UUID as the basis for encryption. This means as long as each template has a unique UUID (which it does, via v4 generation), its encryption is independent. There is no change needed in key management – the same user key that encrypts normal notes will encrypt templates. No plaintext template content or titles are ever sent; everything is in title_enc and props_enc.
Metadata Usage: We leverage the encryptedMetadata JSON field to carry additional info:
For notes created from templates, store { "sourceTemplateId": "<template_uuid>", "sourceTemplateTitle": "<template title>" }. This is saved in local DB (not encrypted at rest, despite the field name) and merged into the encrypted props for sync
GitHub
. Including the title helps display a human-readable reference on the device without needing to lookup the template every time. This is especially useful if the template gets deleted or if we want to show the name in a “From Template” chip. It’s stored client-side but encrypted on the server (within props_enc).
For template notes themselves, we might include a flag in metadata like "isDefaultTemplate": true for seeded ones (to track which were provided by the app). This is optional but can assist with not re-seeding (see Section 4). Regardless, anything in metadata will be encrypted in transit as part of props.
No Plaintext Leakage: By adding noteType and template metadata to the encrypted payload, we ensure that the server and any eavesdropper cannot identify which notes are templates or which note was generated from which template. All they see is encrypted bytes. Only the client, with the decryption key, can interpret the noteType or sourceTemplateId. This aligns with the security model used for all notes and attachments in Duru.
Backward Compatibility of Encrypted Data: Old app versions (pre-template) will ignore the new noteType field in decrypted JSON (since they don’t expect it). As observed in the pull logic, unknown fields simply end up in the metadata map. An older app would therefore place 'noteType': 'template' into the note’s encryptedMetadata JSON if it encountered it, but since that app has no concept of templates, it would still show that note in the main list. This is an acceptable backward compatibility consequence: if a user has one device still on the old version, templates created elsewhere will appear as regular notes (with perhaps a weird metadata JSON visible if the UI displayed it, which it usually doesn’t). Once the app is updated, the filtering will kick in and those will hide. We conclude that including noteType in the payload is safe and does not break decryption on older clients (they simply treat it as extra metadata).
Encryption of Default Templates: The default template content we seed (like “Meeting Notes” structure) will be stored in plaintext locally upon creation. When they sync to server, they too go through CryptoBox encryption. So even the out-of-the-box templates are protected in the remote DB. On other devices, they decrypt and appear exactly as intended.
In summary, by slightly extending the JSON that we already encrypt for notes, we keep templates fully secure. We should add unit tests around encryption: for a given note with noteType=template, after calling the encryption routine, decrypting the result yields the original fields including 'noteType': 'template'. Also test that omitting noteType (for backward compatibility) defaults correctly. With this in place, templates are first-class citizens in the offline-encrypted sync system.
4. Template Seeding
Provide users with a few default templates (e.g. Meeting Notes, Daily Journal, Action Items) automatically, to showcase the feature. These should be created once per user (and not duplicated across devices or app versions unnecessarily). Plan for seeding:
Default Template Definitions: Prepare the content and titles for a set of starter templates. We will store these in a JSON asset file or similar, with support for localization. For example, an assets/default_templates.json could contain entries like:
{
  "Meeting Notes": {
     "body": "# Meeting Notes\n\n**Date:** {{date}}\n**Attendees:** ...\n**Agenda**:\n- [ ] ...\n\n**Notes:**\n"
  },
  "Daily Journal": { "body": "# Daily Journal\n\nToday I ...\n" },
  "Action Items":  { "body": "## Action Items\n- [ ] ...\n" }
}
The keys are template titles (which can be localized by having a separate file per locale or storing translations in a structure). We might maintain separate localized sets (e.g. default_templates_en.json, default_templates_es.json, etc.) so that titles and any boilerplate text are in the user’s language. Alternatively, we integrate with the app’s localization system (e.g. JSON with placeholders that we replace via AppLocalizations). The content can include basic Markdown structure that users can fill in.
Seeding Mechanism: Trigger the creation of default templates after the schema migration or on first launch of the new version:
Implement a method in the repository or a service, e.g. TemplateSeeder.seedDefaultTemplatesIfNeeded(). It will check if the user already has any templates or if a flag is set that seeding was done. We can use a simple SharedPreferences flag like templatesSeededVersion. If not present (or lower than current seed version), proceed to create templates.
For each default template definition:
Generate a new UUID for it and prepare a LocalNote with noteType=template. Use the repository’s createTemplate method to insert it. For example:
await notesRepo.createTemplate(title, body);
This will internally upsert the note and enqueue an upsert_note. Because seeding runs when the user is online or offline alike, we treat it just like user-created templates.
Mark these templates in a way to avoid duplicates. For instance, after seeding, set templatesSeededVersion = 1 in preferences. Also, possibly store the IDs of the default templates in prefs (to avoid re-creating if user deleted them intentionally – see below).
This seeding should ideally occur after initial sync/pull on a new login: if the user already had templates (maybe seeded on another device), we don’t want to add duplicates. One approach is to perform seeding after a successful pullSince(null) (full sync) for a new account or after migration. If pullSince returns no templates (i.e. none exist remotely), then seed locally. If it returns some (meaning another device already seeded), skip local creation.
Alternatively, perform seeding during migration to v10 (in the onUpgrade callback). However, that runs before the app has user context or encryption setup, and it would create templates unconditionally on each device – potentially duplicating templates on multi-device setups. A better location is after user authentication, in an initialization flow. We can piggyback on the provider system: for example, once the user logs in and the notesRepositoryProvider is ready, call seedDefaultTemplatesIfNeeded() (perhaps in an auth change listener or at the end of the first sync).
Avoiding Duplicates: It’s important that default templates are created only once per user. Consider a user with two devices: Device A and Device B.
If both devices go online after update, both might attempt to seed. To prevent double-seed, our approach of checking after initial sync helps. Device A seeds immediately (finding none on server). Device B, upon syncing, will retrieve those templates (since Device A likely pushed them quickly). Device B’s check sees templates exist, so it skips creating. In the worst case where both were offline and seed simultaneously, they’d create duplicate templates with different IDs. This is a rare race condition; if it occurs, the user will just see two “Meeting Notes” templates. We accept this minor risk, or mitigate it by using deterministic IDs.
Deterministic ID approach (optional): We could assign well-known IDs for default templates (e.g., hash of userID + template name). If both devices try to insert the same ID, one will succeed and the other will on sync detect a conflict (the second device’s insert will result in an “update” of the existing template). However, generating deterministic UUIDs has its own complexity and could collide with legitimate notes by chance. We will likely avoid this and rely on the sync check above.
Once seeded, mark it so we do not seed again. We’ll set templatesSeededVersion = 1 in persistent storage. If in a future app update we introduce new default templates or update them, we can bump this version and add only the new ones.
Default Content Localized: Use the app’s current locale to choose the template text. For instance, load the appropriate locale JSON. This ensures a user who uses the app in French gets French template headings, etc. Note that once created, templates are normal data – if the user later changes app language, their existing templates do not automatically translate (we wouldn’t want to overwrite user-edited content). That’s acceptable; the templates are meant as starters. If needed, the user can edit the titles/content manually.
Marking Default Templates: We may add a field in each default template’s encryptedMetadata indicating it’s a system-provided template (e.g., "isDefault": true, along with maybe a version or template key). This could be useful if in a later version we want to programmatically update default templates without touching user-created ones. However, by default we will treat them like normal templates once created.
Integration with Sync: When seeded templates are created, they are enqueued to sync just like any other note. The user will typically be online during first run, so the templates get uploaded (with encryption) immediately after creation (or during the next sync cycle). Other devices will then receive them. If the user is offline on first run, the templates stay in PendingOps; as soon as the user goes online and syncs, they’ll upload. We will add Sentry logging for any failure in seeding (e.g., JSON asset missing or DB error) so we can catch issues in the wild.
One-Time vs Versioned Seeding: Once per user per version means if we dramatically change default templates in a future release (say add a “Project Plan” template in version 2), we can seed that new one without re-adding the old ones. We’ll handle this by versioning as mentioned. In the current release (version 1 for templates), we create the 3 templates if none exist. If user deletes a default template and we haven’t incremented version, we will not recreate it (which respects user choice). Only a version bump or a manual user action would add new ones.
Testing Seeding: Write tests to simulate a fresh user login: ensure that after seeding function runs, the local DB has the expected default templates with correct titles and content, and that noteType is correctly set to template. Test that running it again does not duplicate them. Also simulate scenario where templates exist (pretend to pull ones) and check that seeding skips creation. If possible, simulate two devices: run seeding on one, then the other, ensuring no duplicates when the sync logic is applied (this might be done via integration test with a pseudo remote store).
By providing these starter templates, we enhance user experience. The logic above ensures they appear exactly once and sync across devices like any other data. Users can use them immediately or modify them as desired.
5. Filtering, Indexing, and Smart Folder Exclusion
Templates should never appear in normal note lists or counts unless explicitly requested. We need to filter them out from all existing queries that drive the UI, to maintain a clear separation between user content and templates. Changes required:
Exclude from Note Listings: Update all database queries and repository methods that fetch notes to filter out templates (noteType = note). For example:
AppDb.allNotes() – currently returns all non-deleted notes
GitHub
. Add a condition:
..where((t) => t.deleted.equals(false) & t.noteType.equals(NoteKind.note.index))
so it only returns real notes. Similarly ensure notesAfter() (used for pagination/infinite scroll) filters out templates
GitHub
.
allNotesWithPinned() – add the same filter (exclude templates) when selecting notes
GitHub
. Pinned templates are unlikely (UI won’t show pin for them), but for safety we exclude them anyway.
getPinnedNotes() – already filters isPinned=true and deleted=false
GitHub
; add noteType = note so templates (even if somehow pinned via DB) don’t show.
Repository’s list() method (which seems to be an alias for listing notes)
GitHub
 should include the template filter as well. Currently it calls db.select(localNotes)..where(deleted=false), so add & noteType=note. This is important because SmartFolderEngine.getAllNotes() uses repository.list() to retrieve all notes for applying smart folder rules
GitHub
GitHub
. With the filter in place, smart folders will inherently operate only on real notes, ignoring templates.
Folder Views: Templates should not appear in any folder (even “Unfiled” or “Inbox” special folders). We enforce this by filtering them out of folder queries:
getNotesInFolder(folderId) – currently joins note_folders and returns notes in a given folder
GitHub
GitHub
. Add localNotes.noteType.equals(NoteKind.note.index) to the where clause along with deleted=false
GitHub
GitHub
. This means if a template accidentally had a folder assignment, it would be skipped.
getUnfiledNotes() – returns notes not in any folder (noteFolders join where noteId is null)
GitHub
. This is essentially the “Unfiled” or general list of notes with no folder. Add a filter here too: localNotes.noteType = note. Otherwise, templates (which have no folder by design) would show up in the Unfiled section. After change, Unfiled will list only actual notes without folders.
getNotesCountInFolder(folderId) – used for folder badge counts (e.g. inbox unread count)
GitHub
. This does a COUNT of notes where deleted=false and matches folder. Add AND noteType=0 to the SQL (Drift where clause)
GitHub
 so that templates are not counted. This ensures the “Incoming Mail” badge or any folder count excludes templates. (Templates wouldn’t be in “Incoming Mail” tag anyway, but being thorough.)
getFolderNoteCounts() – returns a map of folderId -> count for all folders
GitHub
GitHub
. It joins local_notes and note_folders. We need to add localNotes.noteType = note to the join condition or the where clause. We can do:
..where(localNotes.deleted.equals(false) & localNotes.noteType.equals(NoteKind.note.index))
before grouping. This way, folder counts exclude any templates.
Search Results: Modify search to omit templates. Duru’s search (unified search) works via FTS or tag queries
GitHub
:
In the FTS query, currently:
SELECT n.* FROM local_notes n 
JOIN fts_notes f ON n.id = f.id 
WHERE n.deleted = 0 AND f MATCH ? 
ORDER BY n.updated_at DESC;
We will change WHERE n.deleted = 0 to WHERE n.deleted = 0 AND n.noteType = 0
GitHub
. This ensures the query doesn’t retrieve templates. We already prevented templates from entering fts_notes via triggers, but adding the condition is an extra guard (in case some template slipped in or noteType wasn’t added to trigger in an older migration scenario).
The tag search (when a query starts with #) looks up note IDs by tag and then selects notes by those IDs
GitHub
GitHub
. It currently filters deleted=false
GitHub
. We need to also filter noteType=note there. So:
..where((t) => t.deleted.equals(false) & t.id.isIn(ids) & t.noteType.equals(NoteKind.note.index))
This way if a template somehow had a tag (which could happen if user tags a template for organization), it won’t show up in tag search results.
Smart Folders & Saved Searches: Smart folders are essentially saved search presets or user-defined filters. Because we filter at the base data source (repository.list or DB queries), smart folder contents will naturally exclude templates. For instance, a smart folder for “All notes with attachments” should not include templates even if a template had an attachment tag, because our getAllNotes() fed into it only returns real notes. Similarly, any saved search execution that goes through db.searchNotes or repository queries will respect the noteType filters we added. We should double-check SavedSearch execution logic: it likely calls db.searchNotes(query) or specific tag/folder queries
GitHub
GitHub
. By updating those underlying calls (as above), saved searches won’t surface templates unless the search explicitly targets them (which normal UI won’t allow).
Bulk Operations: Duru supports bulk actions on selected notes (e.g. multi-select delete or move). We must ensure templates are never inadvertently included in these selections. Since templates aren’t shown in any listing or search, the user cannot multi-select them in the normal UI. Additionally, the provider that tracks selected note IDs for batch ops should only contain IDs visible in the list. For safety, if there’s any batch operation that queries all notes (unlikely), it should also filter by noteType. We can audit functions like TaskRepository.archiveAllCompleted() or similar to ensure they don’t sweep up templates. Most likely not an issue, but worth noting.
Notification/Badge Counts: If the app displays a badge for “Inbox” or similar counts (like unread email notes count via inbox_unread_service.dart or similar), those counts come from queries on notes in the Inbox folder. We have already handled folder counts. We should also ensure any such service filtering uses noteType, but since it likely uses the folder count or direct DB queries with deleted=false, adding noteType to those DB queries is necessary. For example, an Inbox unread service might query local_notes where a tag or folder equals Inbox and not deleted – add noteType=note to that condition. The principle is the same: only count actual notes.
Task Extraction: (Edge consideration) Duru extracts tasks (checkbox list items) from note content into a NoteTasks table for task management. We should ensure templates do not interfere here. If a template contains checklist items (e.g. a “To-Do” template with - [ ] lines), we do not want those appearing in the user’s task list. By default, tasks are extracted when a note is saved or edited (via NoteTaskSyncService which watches notes
GitHub
GitHub
). We should disable task sync for template notes. Implementation: in NoteTaskSyncService.initializeNoteTaskSync(noteId), we can check if that note is a template and simply return without setting up a subscription. Similarly, when toggling a task or adding tasks, if the parent note is a template, skip updating note content. This could be done by checking LocalNote.noteType in these methods. If not addressed, a template with tasks would get tasks extracted (since the service currently listens on all notes changes). Alternatively, we only ever call initializeNoteTaskSync for notes opened in the editor. If we never open templates in the normal editor or we explicitly avoid initializing it for templates, we are fine. For thoroughness, add a check:
final note = await _db.getNote(noteId);
if (note?.noteType == NoteKind.template) return;
at the top of initializeNoteTaskSync. This ensures template content’s checkboxes are ignored. Also ensure any global task queries (like “all open tasks”) exclude tasks whose parent note is a template. This likely requires joining NoteTasks with LocalNotes in the query; adding a join filter for noteType=note. This prevents template-derived tasks from cluttering task lists if they were accidentally extracted.
UI Safeguards: The UI should not list templates in recents or counts. For instance, if there’s an “All Notes count” somewhere, that might call db.getLocalActiveNoteIds()
GitHub
. That currently selects all notes where deleted=false and collects IDs. We should filter that as well so it doesn’t count templates as active notes. If getLocalActiveNoteIds is used for sync or conflict logic, excluding templates is likely fine (templates are active, but treating them separately might simplify logic). Since they sync via same mechanism, it’s probably not critical to exclude in that method, but for consistency we could.
In the UI “Recent notes” section (if any), ensure it uses a query that excludes templates. If they use getRecentlyViewedNotes(limit=5)
GitHub
, that selects where deleted=false, ordered by updatedAt, but no explicit template filter. We should add one there too. Otherwise, if a template was recently created or edited, it might appear in a “Recent” list or widget. So:
..where((n) => n.deleted.equals(false) & n.noteType.equals(NoteKind.note.index))
in that method.
After implementing these filters, templates will live “invisible” to the user unless we deliberately fetch them. We will explicitly fetch them in a separate UI (e.g. a Templates management screen or template pickers). This compartmentalization maintains an uncluttered user experience – users won’t inadvertently come across templates in their note feed, search results, or counts. Testing filters: This is crucial – write tests to verify that template notes do not appear where they shouldn’t:
After creating a template, calls to notesRepository.localNotes() or db.allNotes() should not include it.
Templates should not count towards folder note counts (test that a folder with only a template yields count 0).
Search for a keyword present in a template should return no results (unless explicitly searching templates, which our UI doesn’t do).
Verify that adding a tag to a template and searching by that tag yields no result.
If possible, simulate UI providers: e.g. the filteredNotesProvider which uses currentNotesProvider (backed by db.watch(localNotes)) needs to ensure it’s filtering as well. We might need to adjust the currentNotesProvider if it directly watches the DB; likely it uses a query with deleted filter – ensure we incorporate noteType there.
Smart folder rules: e.g. a smart folder “Open Tasks” that collects notes containing tasks – ensure a template with a checkbox is not in its computed results (by virtue of noteType filter or skipping task extraction as mentioned).
All such tests should pass, confirming that templates remain hidden except where we explicitly surface them.
6. Riverpod Providers
Introduce dedicated Riverpod providers for template data, analogous to those for notes, to integrate templates into the app’s reactive state management. These providers will allow the UI to easily access the list of templates or recent templates and respond to changes (e.g. new template added, template edited).
Template List Provider: Create a provider that yields the list of all template notes (sorted appropriately). For example:
final templateListProvider = StreamProvider<List<LocalNote>>((ref) {
  final db = ref.watch(appDbProvider);
  // Watch all non-deleted templates
  return (db.select(db.localNotes)
           ..where((n) => n.deleted.equals(false) & n.noteType.equals(NoteKind.template.index))
           ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
         .watch();
});
This uses Drift’s .watch() to get a stream of LocalNote whenever the template table subset changes. By watching appDbProvider, it automatically rebuilds if the database instance changes (on login/logout). We filter noteType == template and deleted == false, ordering by last updated (so that newly created or edited templates appear at top). The provider will emit the current list of templates and update in realtime if any template is added, edited, or removed (deleted).
Alternatively, we can expose this via the repository: e.g., add NotesRepository.watchTemplates() that does the above query, then do ref.watch(notesRepositoryProvider).watchTemplates(). Either approach is fine; direct DB access is straightforward here.
Recent Templates Provider: Provide a subset of templates, for quick access (e.g. in a template picker showing most recently used or created templates). If by "recent" we mean recently used (applied) templates, we might need to track usage. However, since usage is also correlated with updatedAt if we update a template’s timestamp on each use, a simpler approach is to use either updatedAt or creation time. We’ll interpret “recent” as recently modified or created for now. Implement:
final recentTemplatesProvider = Provider<List<LocalNote>>((ref) {
  final templates = ref.watch(templateListProvider).maybeWhen(orElse: () => [], data: (t) => t);
  // Return the top 3 templates
  final count = templates.length;
  if (count <= 3) return templates;
  return templates.sublist(0, 3);
});
This takes the data from templateListProvider and simply returns the first 3 entries (which, given the sort by updatedAt, will be the 3 most recently edited/created templates). These can be shown as quick options.
If we wanted to truly track “recently used” templates, we could do something more advanced (like record last-used timestamp in metadata whenever a template is applied, and sort by that). That’s beyond the scope here, so using updatedAt as a proxy is acceptable (especially if the user rarely edits templates, updatedAt will basically reflect creation time, giving the first-created templates; but if they edit a template or we decide to update updatedAt on every apply, then it aligns with usage).
Individual Template Provider (if needed): If we have a screen to edit a single template, we can use an Editor route with the noteId. In that case, we might have something like:
final templateProvider = StreamProvider.family<LocalNote?, String>((ref, templateId) {
  final db = ref.watch(appDbProvider);
  return db.watchNote(templateId); // watchSingleOrNull on local_notes by id
});
This could feed a template editing UI to react to external changes. But since templates likely only change when user edits them on that device, this might not be heavily used. Still, it’s easy to add if needed (similar to how we watch notes).
Usage in UI: The templateListProvider will be used for any Template Management screen or section (see Section 7). The recentTemplatesProvider will be used in places like the New Note FAB menu or template picker dialog to highlight a few templates (if needed). These providers ensure consistency: if a user creates a new template via “Save as Template,” the providers will automatically include it (because the DB insertion triggers the .watch stream to emit a new list). If the user deletes or renames a template, the UI bound to these providers updates automatically.
Folder Providers Impact: There might be providers like unfiledNotesCountProvider or others that should exclude templates. If such providers exist (for example, an InboxCountProvider reading from DB), ensure they use the updated DB queries with noteType filtering. Likely they already rely on the DB functions we updated in Section 5, so no separate provider changes needed – it will naturally produce correct values after our DB query changes.
Ensure No Conflicts: The addition of template providers should not conflict with the existing providers. We name them clearly (templateListProvider, etc.). They will live alongside notes providers in providers.dart or a relevant module. For instance, in providers.dart we might add:
final templateListProvider = StreamProvider<List<LocalNote>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.watchTemplates(); // if we implemented in repository
});
Or use the direct DB approach as shown.
Providers for UI State: If we introduce any UI where templates can be filtered or sorted, we might add state providers for that. For example, if we allow sorting templates by name or date, a templateSortProvider could drive the order. Initially, we assume a default sort by date is fine, so no extra state needed.
Testing Providers: Write tests using ProviderContainer to ensure that adding a template triggers templateListProvider to update. For example, seed a container with a fake in-memory DB, add a template note, and expect the provider’s value contains that note. Similarly, test that deleting a template removes it from the list. If using Riverpod’s StreamProvider, we can simulate by manually calling the underlying DB insertion and then reading the provider state. Also test that recentTemplatesProvider correctly returns a limited sublist.
By introducing these providers, we integrate templates into our reactive app model, making it easy to build UI components that display templates and stay up-to-date. Experienced engineers on the team can follow this pattern (mirroring how notes and folders are handled via providers) to wire templates into the app.
7. UI Integration Points (FAB, Picker, Editor, Chip)
We will introduce several UI affordances for templates to make them accessible and manageable to the user while keeping them out of the main note flow. Key integration points and their implementation details:
New Note FAB Template Picker: Enhance the “New Note” action to allow starting from a template. Instead of the FAB immediately creating a blank note, we provide choices:
FAB Menu or Bottom Sheet: When the user taps the New Note FAB (➕), present a menu of options: “Blank Note” and “From Template…”. Selecting “From Template…” opens a template picker dialog. Alternatively, we can implement an expanding FAB (speed-dial style) that on tap (or long press) reveals sub-actions. For a simpler implementation, tapping FAB can show a bottom sheet listing templates (and an option for blank note).
Template Picker Dialog: Design a dialog or bottom sheet titled “Create from Template”. It will list the available templates fetched from templateListProvider. Each template can be shown with its name (and perhaps a brief preview or icon). Also include a “Blank Note” option at the top or bottom. For visual consistency, use ListTiles or buttons. Example: the sheet could show:
“📄 Blank Note” (always present)
Then a divider or heading “Templates:”
Then each template name as a selectable item (possibly with an icon like 🗒️).
Behavior: If user chooses Blank Note, proceed with existing blank note creation (the app likely already handles this by navigating to the editor with no noteId, which triggers a new note). If a template is chosen:
Call notesRepository.createNoteFromTemplate(templateId) (from Section 2) to instantly duplicate the template content into a new note. This returns a LocalNote for the new note.
Navigate to the note editor screen for that new note (pass its id into the editor). This opens the note for the user to start editing. The editor will show the template’s content and title pre-filled.
Log an analytics event template_used (with template name/ID) at this point (see Section 8).
The template picker dialog should dismiss after selection.
UI Considerations: The FAB icon might change to indicate multiple options (some apps use a FAB with a dropdown arrow or a split FAB). If using a bottom sheet, make sure to blur or dim background for focus. The template list may be scrollable if there are many templates. For a small number, showing them directly is fine. Possibly highlight the default templates with icons (e.g. 📋 for “Meeting Notes”, 📓 for “Journal”, etc., if available).
No Added Wait: The duplication happens locally and is fast (just a DB insert), so we can navigate immediately. We might show a brief toast “Note created from template ‘X’” if desired, but since we take the user to the note, feedback is inherent.
Editor App Bar Template Actions: Within the note editing screen, provide an option to apply a template to a new note or save as template:
Apply Template to Current Note: If the user opens a new blank note and then decides to fill it with a template, we allow that via an app bar action. For instance, an icon button “Apply Template” (could use an icon like 📝 or a templates icon). This is most relevant when the note is empty. We’ll implement:
In the editor’s AppBar overflow menu or toolbar, add “Apply Template” (or “Insert Template”). Tapping it opens the same template picker dialog as the FAB (or a simplified version listing templates).
If the current note is completely empty (no title/body changes), selecting a template will populate the editor fields with the template’s title and body. Under the hood, instead of creating a new note, we modify the existing draft:
Set the editor’s title text and body text controllers to the template’s content. (The ModernEditNoteScreen uses a unified text field where the first line is title and rest is body. We might need to split the template content into title vs body. Alternatively, since the template has a title field, we can set that as the initialTitle and template body as initialBody, then recreate the controller text. But dynamic changes after the controller is already set are tricky. Instead, we might close the current screen and reopen a new one from template, but that’s clunky.)
A simpler approach: when user chooses a template here, we can essentially do the same as createNoteFromTemplate but replace the current draft note:
Delete the current draft note (if it was not yet saved to DB, there might not be anything to delete – if an ID was pre-generated, mark it deleted or reuse it).
Create a new note from template as in FAB flow, and open that. Possibly with a smoother transition.
However, if the current note already has an ID and is being edited, replacing its content might be confusing in terms of sync (the app might treat it as the same note with new content). It might be easier to simply navigate away (pop current editor) and push a new editor loaded from the chosen template.
To avoid complexity, we can restrict “Apply Template” to only be enabled when the note is new and untouched. If _hasChanges is false and no content, then allow it. If the user has typed something already, either disable the action or show a confirmation “Replace current content with template?” and proceed if confirmed.
On applying, treat it similarly to selecting from FAB: navigate to an editor with a new note from that template (essentially discarding the blank draft). This way, we keep the logic unified.
This feature is a convenience; users can always choose templates from the start (FAB). But providing it in-editor covers the case “I opened a blank note, then decided to use a template instead.”
Save as Template (Overflow Action): When viewing/editing a normal note, allow the user to save its content as a reusable template:
In the editor’s overflow menu (“⋮”), add an item “Save as Template”. This is visible only if the current note is a regular note (noteType=note). It should be hidden or disabled for template notes (no point saving a template as another template).
When selected, prompt the user to name the template. We can show a simple dialog: “Save as Template – Enter template name:” with a TextField pre-filled with the current note’s title (or “Untitled” if blank). The user can modify the name if they want this template to have a different title than the note’s title.
On confirm, use NotesRepository.createTemplate(name, body) to create a new template entry locally
GitHub
GitHub
 (fast, offline). The body content will be exactly the note’s body content. (We might also copy the note’s title into the template’s body if we want the template content to include a title line, but since templates have a separate title field, we typically treat that as the template’s name only, and the body carries the content structure).
Immediately close the dialog. We can show a Snackbar “Template saved” for feedback. The template will now appear in the template list (via templateListProvider) and be queued for sync.
Do not navigate the user away from the note – they can continue editing it. Saving as template is like a “Copy” action.
Log template_saved analytics event (with template name) on completion.
Under the hood, createTemplate enqueues sync; if it fails later, we will handle via Sentry (the user still has the template locally, and will sync on retry).
Edge cases: If the note has attachments or other metadata, those will be included in the template’s content? In our approach, we only copy the text content. Attachments might not carry over (unless we handle them – out of scope now). That’s fine; templates likely focus on text structure. We can mention in documentation that attachments aren’t duplicated into templates via this action.
After saving, the template is independent of the note. If the user updates the note later, it doesn’t affect the template (and vice versa).
Prevent misuse: If user tries to “Save as Template” on a note that is itself a template (shouldn’t see the option), or if they spam it, they’ll just create multiple templates (which is allowed). No harm, aside from duplicates the user can delete if needed.
From Template Chip in Editor: When a note was created from a template, indicate this in the editor UI:
If a note has sourceTemplateId metadata (meaning it originated from a template), display a small “From Template” label in the editor. A good approach is a Chip widget (Material Design chip) with text like “From template: Meeting Notes”.
Placement: We want it to be subtle but noticeable. Options:
Under the note title (for a unified editor, perhaps at the top of body content area, we can insert a non-editable element).
Or in the app bar as a subtitle (if the app bar is not too cluttered). Possibly in the app bar, below the note title or next to it.
Or as an overlay at bottom of the screen.
A practical solution: If using a unified text field, we cannot inject the chip into the text easily. Instead, we can show it above the keyboard area or in a sticky footer when editing. However, the simplest might be just below the app bar, with some padding, not part of the scrollable text.
For example, in ModernEditNoteScreen build method, if note.sourceTemplateTitle is not null, render a Row with a Chip:
if (_sourceTemplateTitle != null) 
   Padding(
     padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
     child: Chip(
       label: Text("From template: ${_sourceTemplateTitle}"),
       backgroundColor: Theme.of(context).chipTheme.backgroundColor?.withOpacity(0.1),
     ),
   );
Style it to be subtle (perhaps smaller font or low-opacity background). The text includes the template’s name.
Optionally, make the chip clickable: tapping it could open the original template for reference (perhaps in a read-only view or full edit if we allow editing templates). This would be a nice touch: user can quickly jump to update the template if needed. If we implement this, on tap simply navigate to the template’s editor (we have its ID). For safety, open it read-only or at least indicate clearly that they are now editing the template itself, not the note.
Ensure to load the template title: Since sourceTemplateTitle is stored in encryptedMetadata, when loading the note in editor, parse that JSON. In _loadNoteMetadata()
GitHub
 after fetching the note, do:
if(note.encryptedMetadata != null) {
    final meta = jsonDecode(note.encryptedMetadata!);
    if(meta['sourceTemplateTitle'] != null) {
       _sourceTemplateTitle = meta['sourceTemplateTitle'];
    }
}
Then call setState so that UI shows the chip. We already do something similar for tags and pin state
GitHub
.
The chip should be removed if the note is converted to a template or if the metadata is not present. Since sourceTemplateId stays as part of note metadata for its lifetime, we’ll always show it for those notes. (If a user substantially changes a note that was from a template, the chip still shows origin – which is fine, it’s just a historical note).
This chip does not show for the template itself or for normal notes. Only when metadata indicates origin.
Also, do not show a chip in a template’s own editor indicating “template” – that’s redundant. The UI can have some subtle indicator if needed (like the screen title could say “Edit Template” instead of “Edit Note” if we differentiate mode, but that’s a stretch goal).
Manage Templates UI: (Potential extension) Provide a way for users to view and edit all their templates. Since templates are hidden from main UI, a dedicated screen can list them using templateListProvider. This could be accessible via Settings or an overflow menu from the notes list (e.g. a “Manage Templates” option). On that screen, show a list of templates (similar to note list but simpler). Allow actions like:
Tap a template to edit it (open in the editor screen with noteType=template – we can reuse the editor for this).
Rename or delete templates (maybe via swipe actions or long-press context menu).
Possibly create a new template from scratch (a FAB on this screen to “New Template” which opens an empty editor in template mode). This covers the case where a user wants to make a template not derived from an existing note.
Given time constraints, this manage screen can be simple, but it’s important for completeness: without it, users can create templates but only edit them if they remember to “Save as Template” again from a note or if they choose one and then edit that instance (which doesn’t update the template).
We plan for this screen but it was not explicitly requested. However, including a mention: “We will add a ‘Templates’ screen in Settings for advanced users to organize their templates, using templateListProvider for content.” ensures future-proofing.
In summary, the UI integration ensures that:
Users can create new notes from templates easily (via FAB or editor action).
Users can save existing notes as templates quickly.
It’s clear when a note was based on a template (via the chip).
Users have a pathway to edit and manage templates (either via template picker on tap or a dedicated screen).
Testing UI behavior:
Test the FAB template picker: when selecting each option, does it correctly route? For blank note, ensure a new note opens as before. For a template, ensure the new note’s content matches the template. Possibly write a widget test that fakes two templates in provider and taps one.
Test Save as Template: create a note with known content in editor, trigger Save as Template, input a name, confirm. Then verify (via providers or direct DB call) that a new template exists with that content and given name. Also verify a snackbar or indication is shown.
Test the chip: create a note from a template, open it in editor, verify the chip is displayed with correct template name. Test tapping it (if implemented clickable) opens the template editor.
Test that Save as Template doesn’t appear for a template note (open a template for editing, open menu – should not show).
UI edge: If a note from template is duplicated into another template (conceivably if someone did Save as Template on a note that itself had an origin), it’s fine – that second-generation template’s content would include the first template’s structure, but we don’t propagate any link (we do not set sourceTemplate for templates themselves).
Ensure the template picker lists include latest changes: e.g. after saving a new template, if the user immediately hits the FAB, the new template should appear in the list (thanks to provider reactivity).
By carefully implementing and testing these UI points, we give users the full power of templates in an intuitive way, consistent with Material design and Duru’s UX.
8. Analytics & Sentry Instrumentation
Incorporate comprehensive logging and monitoring to track template feature usage and catch any issues in production. We will use the existing AnalyticsService for usage events and Sentry (via AppLogger breadcrumbs or direct integration) for error monitoring.
Analytics Events: Add the following events to help understand how templates are used:
template_used – Log when a user creates a new note from a template. This should include details like which template was used. We can call:
analytics.logEvent('template_used', {
    'template_id': templateId, 
    'template_title': templateTitle
});
For instance, right after duplicating the template (before navigating to editor, or once the editor opens). This helps product know which templates are popular.
template_saved – Log when a user saves a note as a template. Include perhaps the length of the content or the source note’s context. Example:
analytics.logEvent('template_saved', {
   'note_id': currentNoteId,
   'template_title': chosenTemplateName,
   'note_length': currentNoteBody.length
});
Logged after successfully creating the template. This event indicates user-generated templates.
template_opened – Log when a user opens a template in the editor for viewing or editing. We’ll trigger this either on navigating to the template editor screen or when the template is actually loaded. E.g., in the Templates management screen, if they tap a template to edit, log event with template_id. Or if user tapped the “From template” chip to view original, log that.
Additionally, we might log template_list_viewed when the user opens the "Manage Templates" screen (if we add one), to gauge interest.
The AnalyticsService likely has methods for logging events (perhaps it’s an amplitude or Firebase under the hood). Using it similarly to existing events (for consistency, see how other events are logged – e.g., analytics.trackEvent('note_shared') maybe exists). We should ensure to throttle or not spam these events. They are triggered by distinct user actions, so it’s fine.
Sentry Error Tracking: Augment error handling to capture any template-related failures:
Sync Failures: If a template fails to sync (e.g., network down, or server error), our SyncService’s retry logic will handle it eventually
GitHub
GitHub
. But we want visibility. We can use the AppLogger to log a warning or breadcrumb in such cases. For example, in pushAllPending, in the catch block where it prints “Failed to push upsert_note…”
GitHub
, also do:
_logger.error('Sync error: Failed to push note ${op.entityId}', error: e);
If AppLogger is configured to send errors to Sentry (likely LoggerFactory.instance ties into Sentry for error-level logs), this ensures the failure is reported. We might see it grouped with other sync errors, but we can include context that noteType was template if we know (we could check if the note we fetched was noteType template and mention that in the log data).
Seeding Failures: Wrap the default template seeding in try-catch. If reading the asset or inserting into DB fails, catch and log to Sentry:
try {
  seed templates...
} catch(e, stack) {
  Sentry.addBreadcrumb(Breadcrumb(message: 'Template seeding failed', data: {'error': e.toString()}));
  Sentry.captureException(e, stackTrace: stack);
}
(or using AppLogger to log an error). This way we are alerted if, say, the JSON asset wasn’t bundled or a migration logic flaw prevented seeding.
Also, if any template fails to insert (maybe a DB constraint, though unlikely), log it.
Template Duplication Errors: Although creating a note from template is straightforward, we add defensive error handling. E.g., in createNoteFromTemplate, wrap the DB calls in try/catch. If an exception occurs (DB write failure, etc.), log a Sentry error:
_logger.error('Failed to create note from template $templateId', error: e);
And maybe show a user-facing toast “Failed to apply template. Please try again.”
Similar for “Save as Template” – if for some reason createTemplate returned null or threw, catch in the UI layer and log error, and show a message “Failed to save template”.
Crypto Errors: If encryption or decryption ever fails for templates (e.g., CryptoBox throws), ensure that’s caught and logged. The existing code already catches decryption issues in pull and prints warnings
GitHub
GitHub
. We can elevate those prints to Sentry logs (so we know if a template failed to decrypt, which might indicate key issues). For instance, if decryptJsonForNote throws for a note, we log a warning with noteId. It might be beyond scope to change those now, but keep in mind.
UI Unexpected States: If any UI action should not happen (like user tries to use template when none exist), log a breadcrumb. For example, if templateListProvider is empty and somehow user taps "From Template", we could log a warning “No templates available to apply” (though UI will likely disable that state).
Breadcrumbs for Template Usage: Besides errors, we might want breadcrumbs to trace template flows. For instance, add a breadcrumb when user selects a template:
Sentry.addBreadcrumb(Breadcrumb(category: 'template', message: 'User applied template $templateTitle'));
This will be attached to any subsequent error report, providing context that a template was involved in the session. Similarly, breadcrumb on save as template action. This level of detail can help debug if, say, a crash happens after applying a template (we’d see that breadcrumb).
We should ensure these breadcrumbs don’t flood Sentry – use them meaningfully.
The Sentry integration may already capture unhandled exceptions; our goal is to capture handled ones (like a sync failure we recover from but want to log).
Performance Monitoring: Templates shouldn’t add heavy operations, but if needed, we could track how long template encryption or duplication takes (probably negligible). Not a priority unless issues arise.
Sentry Tagging: Perhaps tag errors with something like feature:template when relevant, to filter them easily. For example, when logging an error in template duplication, we can add Sentry.configureScope((scope) => scope.setTag('feature', 'template')); before capturing. This way, we can search Sentry for template-related issues quickly.
Monitoring Dashboard: We’ll monitor template_used and template_saved metrics to see adoption. If analytics show low usage, maybe the feature needs more discoverability. High usage of certain default templates can inform future improvements (e.g. if “Meeting Notes” is rarely used but “Daily Journal” is popular, etc.).
In development and QA, test that:
Analytics events fire at the correct times with correct payload. If using a debug analytics logger, verify in console.
Induce some error conditions to ensure Sentry logging works: e.g., try to call createTemplate with an invalid input to force an error (maybe temporarily simulate by throwing inside it) and see that it gets logged. Or simulate a sync failure by pointing to an invalid endpoint and ensure we log the error. These tests might be manual or using a staging environment with Sentry.
Check that no sensitive data is in logs: Our events/logs identify templates by ID or generic name; content is not logged. That’s good (we should avoid logging full note content in Sentry to maintain privacy). So our logging should use IDs or possibly truncated titles at most.
By instrumenting analytics and error logging, we ensure we can measure the feature’s usage and quickly react to any issues or edge-case failures, thus maintaining a robust production rollout.
9. Testing Strategy (Unit, Widget, Integration)
A thorough testing plan will validate both the functional correctness of the template feature and its integration into the app’s workflows:
Database Migration Test: Create a unit test simulating upgrade from schema 9 to 10. For example, instantiate an in-memory Drift database with schemaVersion 9, insert a sample note, then perform migration to schemaVersion 10. Verify:
The local_notes table now has a noteType column defaulting to 0 (for the existing note). You can query the note and ensure its noteType is NoteKind.note.
New notes can be inserted with both noteType values (test inserting a template and a normal note).
The triggers still function (insert a new note and ensure it appears in fts_notes, insert a template and ensure it does not appear in fts_notes).
If possible, test onUpgrade logic: a note inserted pre-migration remains non-deleted, noteType default correctly assigned.
Repository Unit Tests:
Template Creation: Call notesRepository.createTemplate and assert that:
It returns a LocalNote with the given title/body and noteType=template.
The note exists in the DB (db.findNote(id)) with noteType == template.
A PendingOp was enqueued with kind 'upsert_note' for that ID
GitHub
.
The local note’s updatedAt is set (and reasonably close to now).
Note Duplication from Template: Setup a template in the DB (or create via repository), then call createNoteFromTemplate(templateId). Verify:
The returned note has noteType=note, title and body identical to template’s.
Its encryptedMetadata contains sourceTemplateId = templateId (and perhaps sourceTemplateTitle).
It’s present in DB and pendingOps.
After this, calling notesRepository.getNote( newNote.id ) returns the correct data.
If the template had tags or links, decide if those should copy or not; currently we do not copy tags/links in duplication (we didn’t implement that). We can test that new note has no tags (unless we decide to copy – likely not).
“Save as Template”: Simulate by calling createTemplate(title, body) and ensure it yields expected DB state. (This is basically same as first bullet – maybe combine).
Filtering Logic: With a mix of notes and templates in the DB, test that repository and DB query functions yield correct results:
Insert e.g. 2 notes and 2 templates. Then:
db.allNotes() returns only the 2 notes (none of the templates).
db.getNotesInFolder(someFolder) – if one note and one template are in that folder (insert note_folder entries accordingly), the result should contain only the note.
db.getUnfiledNotes() – if one template and one note have no folder, result should include only the note.
Search: if a template and a note share a keyword, db.searchNotes(keyword) should return only the note. Test tag search similarly.
Smart folder: perhaps simulate repository.list() result; ensure templates are absent (this is indirectly tested by allNotes).
You can also test that notesRepository.list() (which likely uses db or folderRepo) returns no templates.
Test that deleting a template (set deleted true or via repository.deleteNote on template ID) keeps it out of queries as well (deleted filters already handle that).
Providers and UI State Tests:
Using a ProviderContainer, add a few template entries to the in-memory DB, then read templateListProvider. It should contain those templates sorted by updatedAt. Add a new template (via repository or direct DB insert) and ensure the provider updates (perhaps by awaiting a short duration or by reading the stream).
Test recentTemplatesProvider: if there are 5 templates, ensure it returns only top 3. If fewer, returns all.
Test that editing a template (update its title) triggers the provider to emit a new sorted list if appropriate.
Ensure that none of the note providers (like filteredNotesProvider) include templates. This might involve injecting some fake currentFolder and filterState to get the list and checking no noteType=template in there.
Analytics Calls: These can be tested by injecting a mock AnalyticsService into the provider (if our providers allow overriding). For simplicity, we can test that our methods call AnalyticsService appropriately via a spy. Alternatively, since analytics is side-effect, unit test might not be strictly needed – but we can assert that when createNoteFromTemplate is executed in a UI context, the event is logged (maybe by checking a log output if our test logger captures it).
Sentry Logging: It’s hard to unit test Sentry integration directly, but we can simulate an error and ensure our logger is called. For example, cause createNoteFromTemplate to throw by passing an invalid templateId and see if our catch block logs something. If our AppLogger is injectable or global, we might replace it with a test logger that records messages.
Widget/Integration Tests:
Template Picker UI: Create a test where templateListProvider is preloaded with some templates (maybe override the provider to return a fixed list). Render the widget that shows the FAB and triggers the picker. Simulate tapping the FAB, selecting a template, and verify that navigation to editor happened with correct state.
This might require a lot of scaffold (like a MaterialApp and routes). If that’s too complex, at least test the TemplatePicker widget in isolation: give it some template items and simulate taps.
Save as Template UI: Write a test for the editor screen:
Load it with a sample note (maybe by providing initialTitle and initialBody to ModernEditNoteScreen).
Open the overflow menu (simulate tap on menu button) and tap “Save as Template”.
In test, provide a way to handle the name dialog. Possibly override showDialog to immediately return a given string, or simulate user typing in a dialog.
After the action, verify that templateListProvider now includes a new template with the expected name. This ensures the whole flow from UI to repository to DB works.
Also verify a Snackbar “Template saved” appears (WidgetTester can check for SnackBar).
From Template Chip: Test that when opening a note created from template, the chip is visible.
Setup: Insert a note with encryptedMetadata containing sourceTemplateTitle “Meeting Notes” into DB, and open editor for that noteId.
Verify that the chip widget is present in the widget tree with text containing “Meeting Notes”.
Simulate tapping it if clickable: ensure it navigates to template editor (maybe check navigator pushed correct route).
Manage Templates Screen: If implemented, test listing and editing:
Render the template list screen with a couple templates in provider, verify the list shows all template titles.
Tap one to edit, ensure the editor opens with that content.
Simulate deleting a template (if we have swipe or delete button), then verify it’s removed from list (provider updates).
Integration Sync Test: (Complex but valuable) Simulate two devices syncing templates:
Use two separate in-memory database and repository instances to mimic Device A and Device B.
On Device A: create a template (via repository.createTemplate). Simulate push sync by directly calling a fake Supabase API that stores the encrypted data in a dummy variable or structure.
On Device B: simulate initial pull by feeding the encrypted data from that dummy store into NotesRepository.pullSince. Ensure that after pull, Device B’s DB now has the template with correct content and noteType.
Then on Device B, create a note from that template via createNoteFromTemplate, and maybe sync it back, and see Device A receives it. This tests cross-device consistency.
This is quite involved to simulate encryption without the real Supabase; one strategy is to bypass actual encryption by using the same CryptoBox on both (since user is same, key is same), essentially the dummy “server” can just shuttle the bytes.
At minimum, test that our pushAllPending correctly calls api.upsertEncryptedNote with properly encrypted payload (perhaps by injecting a stub api that verifies the propsEnc contains an expected field when decrypted with the known key).
Also simulate a conflict or error: e.g., have Device A and B both create a default template “Meeting Notes” offline, sync both – likely you’d get two distinct templates on server. It’s tough to simulate conflict resolution because our system doesn’t have merging for separate notes (they’re separate IDs). So conflict is minimal.
Task Exclusion Test: If we added logic to exclude template tasks:
Create a template with a checklist item (body contains "- [ ] Template task").
Run whatever triggers task extraction (perhaps directly call _db.syncTasksWithNoteContent(templateId, content) as NoteTaskSyncService would).
Verify that no NoteTask was created for that template (the tasks table remains empty).
Conversely, a normal note with "- [ ]" should produce a NoteTask. This ensures our skip logic works.
By covering these tests, we ensure each piece (DB, sync, providers, UI flows) works in isolation and together. Especially important are the migration and filtering tests to catch any oversight that could surface templates where they don’t belong or break existing note logic. We will also use manual exploratory testing on a debug build:
Creating templates, ensuring they sync, trying offline scenarios, etc.
Confirm encryption by checking that on the server the title_enc/props_enc fields indeed appear (and maybe decoding them in a test environment to ensure they contain expected JSON with noteType).
This multi-level testing approach (unit -> widget -> integration) will give confidence that the Note Templates feature is production-grade and doesn’t regress other functionality. We should integrate these tests into our CI pipeline so that any future changes to notes/folders will run template tests as well, catching issues early.
10. Rollout & Operational Readiness
Finally, prepare for a smooth rollout of the template feature in production, ensuring compatibility, monitoring, and user support:
Feature Toggle (if needed): Determine if the template feature should be behind a feature flag for a gradual rollout. If risk is low, we can enable it for all users in the next app update. If a flag system exists, consider wrapping template UI in a check, but likely unnecessary as this is a contained feature.
Backward Compatibility: Acknowledge how older app versions interact:
As noted, older versions will see template notes as normal notes (since they don’t filter noteType). This could cause minor confusion (e.g., a template might show up as a note with weird content). However, given that once the user updates all devices the issue is resolved, and template content is likely obviously a template structure, this is acceptable. We will not attempt to hide templates on the server for old clients, because that would require server logic which complicates things. The time window and user impact is small (tech-savvy users with multiple devices might notice).
Ensure the server database can handle noteType in encrypted data: No changes needed on Supabase side because we embed it in encrypted JSON. The Supabase notes table doesn’t need a new column. So older clients will just store and retrieve that encrypted blob, oblivious to its contents.
Worst-case: If an old client user edits a template (thinking it’s a normal note), they might be editing the template’s content. That edit will sync and actually change the template. This scenario: User A on app v2 creates template T. User B still on app v1 sees note T (because their app doesn’t filter it out) and edits it. This will sync and update template T’s content for User A as well. This is a bit confusing (template changed unexpectedly), but not catastrophic. We accept this edge case since it requires mixed-version usage. Encouraging users to update will mitigate it. (We could also send an in-app message to update if we detect they have templates on one device and an old app on another).
App Update & User Communication: In release notes or onboarding, highlight the new templates feature. Possibly add a small in-app coach mark on the expanded FAB the first time, e.g., “You can now create notes from templates for quick structure!” This can drive adoption. Provide a brief description in App Store update notes (“New: Note Templates – create meeting notes or journals with one tap!”). If the app has a changelog dialog, include it.
Sentry Monitoring: Actively monitor Sentry after release for any template-related errors:
Particularly look for migration errors (if any DB migration to v10 issues arise, e.g., some users on older beta might have had conflicting changes).
Look for any exceptions in SyncService or Template creation flows. We have breadcrumbs to help debug those.
If a serious issue appears (e.g., templates causing crashes), we have the option to disable the UI entry points via a quick config (if we had a remote config). If not, we might issue a hotfix.
Ensure the Sentry environment is correctly set (so that our new logs actually show up). Possibly do a staged rollout (e.g., release to 5% of users) and watch Sentry for a day, then 100%.
Analytics Monitoring: After release, use the analytics dashboard to track:
How many users click “New from Template”.
How many use default templates vs create custom ones (template_saved vs usage of specific default IDs).
This will inform any UX tweaks (if usage is low, perhaps the feature isn’t discoverable enough; if only one template is used often, maybe promote it in UI).
Also track retention: Are template users more engaged? (Beyond scope, but we have data to find correlation).
Performance Considerations: The introduction of templates should not significantly impact performance:
The additional noteType column and filter adds negligible overhead to SQL queries (an indexed enum check is very fast, and our queries already filter by deleted which is similar complexity). To be safe, we included an index on (noteType, deleted) if needed.
Sync payloads include a few extra bytes for "noteType" and maybe template metadata – trivial impact on network and storage.
The default seeding adds 3 notes on first run – minimal overhead.
So we expect no user-facing perf difference. However, we will test that listing notes (especially search) still feels snappy after adding filters. Should be fine since we filter at SQL level (which might even slightly reduce results if anything).
Data Integrity: We should verify that template creation and usage doesn’t corrupt any data:
After rollout, verify that no templates inadvertently show up where they shouldn’t (through dogfooding and possibly writing an automated UI test scenario).
Ensure that deleting a template only deletes that item and doesn’t affect any notes created from it (they are independent).
Check that encryption keys work for templates on multiple devices (they should, as it’s the same mechanism).
App Store Compliance / Encryption Notice: If our app declarations for encryption need to be updated (some app stores require declaring use of encryption), we already had encryption for notes, so nothing new.
Support & Documentation: Update any user guides or FAQs to include “How to use templates”. Ensure customer support team is aware of the feature:
Provide them a summary: templates are stored like notes but hidden, possible issues (like user sees duplicate content if two devices out of sync versions, etc.).
Support should know how to instruct users to create a template, or troubleshoot (e.g., “if your template isn’t syncing, ensure you’re online; it will sync when possible”).
Future Updates: Plan for any future enhancements:
If later we allow sharing templates or downloading new ones, the groundwork (noteType) allows that.
If we discover through analytics that one of the default templates is rarely used, we might replace it in a future release (that’s fine; it will just seed a new one with a new ID, leaving old one as orphan if not used).
If we want to have template marketplace or more localization, we have structure to add it.
Cleanup of Legacy: Remove any now-obsolete code. For instance, if previously some placeholder for templates existed (like a hidden folder hack considered in docs), ensure we’re not still creating a "Templates" folder inadvertently. In our case, we went with noteType, so no old hacks to remove except making sure no UI element references a folder for templates.
Migration of Existing User “Templates”: It’s possible some users already had a note they use as a template manually. We are not auto-converting anything, but we might educate them via blog or tips that they can now formalize those as templates (by opening and doing Save as Template).
Crash Plan: In the unlikely event the template feature causes a severe problem (like data loss or app crashes), be ready to issue a patch or use a remote kill-switch:
Because the changes are integrated (DB migration etc.), disabling might be non-trivial. But worst-case, we could hide UI entry points via a remote config to prevent further use until fixed.
Data already created (templates) wouldn’t vanish, but if causing crash, we might instruct users to refrain until fix.
However, given the testing above, we anticipate a stable launch.
Overall, by adhering to this plan and performing the outlined tests, the Note Templates feature will be delivered in a robust, user-friendly manner. It aligns with Duru’s offline-first, encrypted ethos and will support cross-device consistency with minimal hassle to users. We will monitor its rollout closely through Sentry and analytics, ensuring any issues are quickly resolved and that the feature is meeting user needs.
Alıntılar
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L428-L436
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L450-L459
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L355-L363
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L522-L531
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L382-L390
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L267-L275
GitHub
sync_service.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/sync_service.dart#L109-L117
GitHub
sync_service.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/sync_service.dart#L124-L132
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L750-L759
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L798-L805
GitHub
sync_service.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/sync_service.dart#L76-L85
GitHub
sync_service.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/sync_service.dart#L149-L157
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L929-L938
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L935-L942
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L257-L265
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L271-L278
GitHub
folder_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/folder_repository.dart#L86-L95
GitHub
folder_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/folder_repository.dart#L132-L140
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L374-L382
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L270-L278
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L765-L773
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L792-L800
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L766-L774
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L766-L773
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L799-L803
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L889-L898
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L893-L901
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L933-L941
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L979-L987
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L782-L790
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L598-L606
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L604-L612
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L636-L644
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L645-L653
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L651-L660
GitHub
smart_folder_engine.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/features/folders/smart_folders/smart_folder_engine.dart#L16-L19
GitHub
smart_folder_engine.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/features/folders/smart_folders/smart_folder_engine.dart#L26-L33
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1937-L1946
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1948-L1956
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1925-L1933
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1926-L1934
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L2029-L2037
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1919-L1928
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1967-L1975
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1978-L1986
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1218-L1226
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1220-L1228
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1197-L1205
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L1208-L1211
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L85-L94
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L88-L96
GitHub
note_task_sync_service.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/services/note_task_sync_service.dart#L26-L34
GitHub
note_task_sync_service.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/services/note_task_sync_service.dart#L46-L54
GitHub
app_db.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/data/local/app_db.dart#L759-L763
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L280-L288
GitHub
modern_edit_note_screen.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/ui/modern_edit_note_screen.dart#L160-L168
GitHub
modern_edit_note_screen.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/ui/modern_edit_note_screen.dart#L169-L178
GitHub
sync_service.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/sync_service.dart#L140-L148
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L842-L846
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L943-L953
GitHub
notes_repository.dart

https://github.com/onronder/DuruNotes/blob/5cc5edc69dc599bb931e40dde7c027f162199eb9/lib/repository/notes_repository.dart#L953-L961
Tüm Kaynaklar

github
