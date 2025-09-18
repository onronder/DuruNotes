# About Duru Notes

## Executive Snapshot
Duru Notes is a cross-platform, privacy-first knowledge capture platform that blends the speed of ubiquitous capture (mobile apps, share extensions, home screen widgets, email-in, and web clipper) with the structure required by operational teams. The product is built in Flutter with an encrypted Supabase backend, giving users realtime sync, offline resilience, and rich workflows such as tasks, reminders, tagging, folders, and smart saved searches.

---

## Business Purpose & Value Proposition
- **Business Problem:** Knowledge workers and teams struggle to consolidate unstructured inputs (emails, meeting notes, action items, web research) into a single, searchable, and secure workspace without sacrificing speed or privacy.
- **Value Delivered:** Duru offers a trusted vault for high-signal notes that can be captured from anywhere, auto-organized, and augmented with reminders/tasks while maintaining enterprise-grade observability and compliance.
- **Target Personas:** Product managers, customer-facing leads, and operations teams who need dependable capture flows, encrypted storage, and cross-device access.
- **Revenue Model (current direction):** Core app is the foundation for paid tiers that unlock collaboration, deeper automations, and insights surfaced via analytics pipelines instrumented across the stack.

---

## Vision & Mission
- **Vision:** Become the most reliable partner for teams who need to remember, route, and act on every important detail—regardless of where the information originates.
- **Mission:** Deliver a secure, intelligent note system that captures information instantly, structures it automatically, and keeps teams aligned through realtime sync, reminders, and actionable insights.

---

## Strategic Differentiators
1. **Secure-by-Design Architecture:** End-to-end encryption via `CryptoBox`, permission-aware Drift migrations, and rigorous Supabase RLS policies shield user data while enabling realtime collaboration.
2. **Ubiquitous Capture:** Home screen widgets, native share extensions, email ingestion, quick capture flows, and a Supabase-backed web clipper minimize friction at the point of inspiration.
3. **Operationally Useful Notes:** Built-in task extraction, reminders, tagging, saved searches, smart folders, and folder hierarchies turn raw notes into trackable workloads.
4. **Production Observability:** Deep Sentry integration, performance tracing, and analytics hooks ensure the product scales without regressions.
5. **Offline-First Reliability:** Drift-backed local cache, pending operation queues, and debounced realtime syncing maintain usability in low-connectivity environments.
6. **Global Readiness:** Full localization (EN/TR today), accessibility compliance (WCAG 2.1), and adaptive theming make the experience inclusive by default.

---

## Product Capabilities Snapshot
- **Capture Inputs:** Modern editor, quick capture widget, iOS/Android share extensions, email-inbox ingestion, web clipper, bulk imports.
- **Organization:** Folders, smart folders, tag management, saved searches, pinning, note linking, note templates (upcoming).
- **Actionability:** Inline task extraction & sync, advanced reminders (time, recurring, geofenced), analytics-backed saved searches, inbox badge counts.
- **Collaboration & Sync:** Supabase realtime updates via `UnifiedRealtimeService`, conflict handling, undo/redo services, debounced update queues.
- **Governance & Monitoring:** Comprehensive logging, Sentry breadcrumbs, performance tracking, analytics events, feature flags prepared for premium execution.

---

## Technical Overview
### Core Stack
- **Client:** Flutter (Material 3 design system) targeting iOS, Android, and potential desktop/web with Riverpod state management.
- **Local Storage:** Drift/SQLite database (`lib/data/local/app_db.dart`) with schema migrations, FTS indexes, and note/task/folder tables.
- **Crypto:** `CryptoBox` encrypts note payloads before sync, keyed via `KeyManager` and `AccountKeyService`.
- **Backend:** Supabase (Postgres + Edge Functions + Storage) for realtime sync, RLS enforcement, and RPC helpers. Firebase initializes supporting services; Adapty handles monetization instrumentation.
- **Sync Engine:** `SyncService` pushes/pulls pending ops, reconciles deletes, and coordinates with a unified realtime channel.
- **Automation Surfaces:** Edge functions for quick capture, Supabase RPC for widgets, share extension bridging, incoming mail manager, and analytics pipelines.

### Data Flow (High Level)
1. Capture surface creates/updates note via `NotesRepository`.
2. Repository writes to Drift, encrypts payload, enqueues pending ops.
3. `SyncService` pushes ops to Supabase and ingests remote changes.
4. `UnifiedRealtimeService` fans out updates to Riverpod providers.
5. UI layers consume providers for list pagination, detail editing, and widgets.

---

## Codebase Structure
```
lib/
├── app/                 # App bootstrap, routing, auth wrapper
├── core/                # Cross-cutting utilities (crypto, errors, formatting, parser)
├── data/                # Drift schema, migrations, generated ORM artifacts
├── features/            # Domain-specific modules (folders, notes pagination, smart folders, quick capture)
├── models/              # Plain data models (note metadata, reminders, tasks)
├── repository/          # Data orchestration (NotesRepository, SyncService, FolderRepository)
├── services/            # Application services (analytics, reminders, share extension, monitoring)
├── ui/                  # Screens and widgets (modern editor, lists, components)
├── main.dart            # Entry point with environment + service init
└── providers.dart       # Riverpod provider graph and dependency wiring
```
Additional directories:
- `android/` & `ios/`: Native integrations (share extensions, widgets, platform channels).
- `supabase/`: SQL migrations, edge functions, configuration.
- `tools/`: Web clipper extension, automation scripts.
- `test/` & `integration_test/`: Unit, widget, integration, and manual test plans with helper tooling.
- `docs/`: Implementation reports, monitoring guides, deployment notes.

---

## Key Modules & Responsibilities
- **NotesRepository (`lib/repository/notes_repository.dart`):** Central CRUD layer handling encryption, tagging, folder associations, metadata, and sync queuing.
- **SyncService (`lib/repository/sync_service.dart`):** Manages push/pull cycles, realtime subscriptions, exponential backoff, and reconciliation.
- **UnifiedRealtimeService (`lib/services/unified_realtime_service.dart`):** Consolidates Supabase realtime events across notes, folders, inbox, and tasks.
- **ModernEditNoteScreen (`lib/ui/modern_edit_note_screen.dart`):** Rich editor handling unified text, formatting toolbar, preview mode, tags, and reminder hooks.
- **IncomingMailFolderManager (`lib/services/incoming_mail_folder_manager.dart`):** Ensures email-ingested notes land in the canonical Inbox folder and heals duplicates.
- **ShareExtensionService & QuickCapture flows (`lib/services/share_extension_service.dart`, `lib/services/quick_capture_service.dart`):** Handle native bridge payloads, attachments, metadata enrichment, and analytics.
- **Monitoring & Analytics (`lib/services/monitoring`, `lib/services/analytics`):** Provide structured logging, Sentry instrumentation, performance tracking, and standardized event vocabularies.

---

## Development Practices & Quality Bar
- **Type-Safe Error Handling:** Result-based APIs and `AppError` hierarchy ensure predictable failure paths.
- **Observability:** Sentry breadcrumbs, performance spans, analytics events, and logger hooks are mandatory for new features.
- **Testing Culture:** Plans call for unit, widget, integration, SQL, and manual QA coverage (see `WORLD_CLASS_REFINEMENT_PLAN.md`, priority reports, and dedicated test directories).
- **Accessibility & Localization:** All UI components honor semantic annotations, keyboard navigation, WCAG contrast, and l10n ARB translations.
- **CI/CD Hooks:** `ci_scripts/` automate Flutter builds, fix permissions, and prepare assets. Supabase migrations and edge functions align with deploy scripts (`deploy_edge_functions.sh`).
- **Security & Privacy:** Encryption-by-default, permission-aware mobile integrations, and compliance-driven monitoring guard rails are woven through the stack.

---

## Market Positioning & Roadmap Themes
- **Short-Term Focus:** Note templates, richer onboarding, and continued refinement of folder workflows (see priority completion reports).
- **Medium-Term Initiatives:** Collaborative workspaces, insights dashboards leveraging analytics, and premium automation packs.
- **Long-Term Ambition:** Become the operating system for operational knowledge—bridging structured tasks, customer insights, and cross-channel capture with trustworthy, privacy-first infrastructure.

---

## Summary
Duru Notes combines robust capture tooling, secure storage, and scalable architecture to give teams confidence that every critical detail is captured, searchable, and actionable. The codebase reflects production standards—modular architecture, encrypted sync, observability, and a disciplined test strategy—positioning the product to evolve rapidly while maintaining trust.
