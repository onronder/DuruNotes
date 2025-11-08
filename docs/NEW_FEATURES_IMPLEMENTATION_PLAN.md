# Duru Notes – Production Implementation Plan (Q4 2025)

**Document version:** 2.0  
**Date:** 2025-10-31  
**Scope:** Soft delete + hard delete, GDPR anonymization, handwriting notes, local AI/LLM, monetization alignment

---

## 1. Guiding Principles & Decisions

- **Order of execution:**  
  1. Soft delete → trash → purge automation  
  2. GDPR anonymization & key rotation helper  
  3. Handwriting capture (Phase 1: Flutter canvas + encrypted attachment)  
  4. Local AI (embeddings, semantic search, auto-tagging, summaries)  
  5. Secure sharing links & paywall UX go-live (dependent on 4)  
- **Premium strategy:** soft delete + anonymization remain free; AI and secure sharing are premium; handwriting is free but enables premium templates later; offer a one-time “AI pack” entitlement in Adapty for mobile devices.  
- **Telemetry:** every feature ships with analytics, Sentry breadcrumbs, and performance instrumentation.  
- **Testing:** unit + integration + golden tests per feature; add instrumentation tests for platform-specific integrations (PencilKit, share extension, notification scheduling).  
- **Rollout:** feature flags in Supabase config + Adapty paywall toggles; staged rollout (internal → beta → GA).

---

## 2. Cross-Cutting Prerequisites

| Area | Tasks | Owners | Notes |
| --- | --- | --- | --- |
| Database migrations | Draft and review migrations for trash metadata, anonymization audit, handwriting attachments, embedding storage. | Backend | Supabase CLI pipelines. |
| Premium infrastructure | Define Adapty product IDs (monthly/6-month/year + AI one-time); finalize placement IDs; re-enable `presentPaywall`. | Product + Mobile | Needed before AI/secure sharing launch. |
| Feature flags | Add toggles in `config/feature_flags.dart` with Supabase remote config fallback; ensure gating in UI. | Mobile | Use Riverpod providers. |
| Monitoring | Add dedicated Sentry tags (`feature=trash`, etc.) and analytics events. | Mobile + Data | Validate dashboards. |

---

## 3. Soft Delete → Hard Delete (10-Day Recovery)

### 3.1 Decisions
- Track `deleted_at`, `purge_after`, and `deleted_by` for notes, tasks, attachments, folders, templates.  
- Store trash entries in primary tables; no separate trash table to avoid duplication.  
- Purge automation: Supabase scheduled function + client fallback on startup.  
- Trash view filtered by entity type; restore returns item to original folder.  
- Default recovery window 10 days (configurable via remote config for emergency adjustments).

### 3.2 Architecture & Data
- Migrations:  
  - `local_notes`, `note_tasks`, `attachments`, `local_folders`, `saved_searches`: add `deleted_at TIMESTAMP`, `purge_after TIMESTAMP`, `deleted_by TEXT`.  
  - Supabase `notes`, `tasks`, `attachments` mirror with RLS updates.  
- Repository updates:  
  - `NotesCoreRepository.deleteNote()` → set timestamps + writer; new `restoreNote()`; `listAfter`/`localNotes` exclude soft-deleted items unless flagged.  
  - Similar adjustments for folders, tasks, templates.  
- Services:  
  - `TrashService` orchestrator (bulk operations, undo stack).  
  - `TrashExpiryScheduler` (client) + Supabase cron function (server).  
- UI:  
  - New `TrashScreen` accessible from settings sidebar with tabbed categories.  
  - Inline “Undo” snackbar on delete, “Restore”/“Delete permanently” actions in note list.  

### 3.3 Task Breakdown

| Area | Tasks |
| --- | --- |
| Data | Write migrations; update Supabase RLS; add indices on `purge_after`. |
| Repositories | Update CRUD methods, add restore/purge helpers, sync queue integration. |
| Services | Implement `TrashService`, `TrashExpiryScheduler`, analytics hooks. |
| UI | Build trash list + dialogs; integrate undo/restore flows in existing screens. |
| Sync | Ensure soft deletes sync as updates; purge emits `delete` mutations. |
| Tests | Unit tests for repository transitions; integration tests for trash UI; cron job e2e. |

### 3.4 Acceptance & Rollout
- QA scenarios: single restore, bulk restore/delete, cross-device trash sync, auto purge.  
- Rollout: internal flag → beta testers → GA in 1 week after zero-issue burn-in.  
- Monitoring: daily purge job logs + Sentry tag `trash_purge=true`.

---

## 4. GDPR Anonymization & Key Rotation

### 4.1 Decisions
- Provide two flows: **export+delete** (existing) and **anonymize-in-place** (new).  
- Anonymization kills Supabase auth, rotates account master key, wipes personal metadata, and leaves anonymized content for teams if needed.  
- All logs/audit entries store anonymization event with hashed user ID.  
- Operation must complete within 30 seconds; runs on background isolate with progress UI.

### 4.2 Architecture & Data
- Extend `GDPRComplianceService` with `anonymizeUserData()` orchestrator.  
- Add `anonymized_at`, `anonymization_id` columns to user metadata tables.  
- Integrate with `EncryptionService` to rotate keys and re-encrypt retained shared content if policy requires.  
- Update Supabase edge functions to revoke tokens and delete push endpoints.

### 4.3 Task Breakdown

| Area | Tasks |
| --- | --- |
| Data | Add columns + audit table; update Supabase policy docs. |
| Services | Implement anonymization flow (revoke auth, rotate keys, scrub profile metadata). |
| UI | Add settings entry with multi-step confirmation + email confirmation code. |
| Notifications | Inform user via email template; log sent event. |
| Tests | Unit tests for anonymization steps; integration test verifying anonymized data cannot be linked back. |

### 4.4 Acceptance & Rollout
- Dry-run on staging with test accounts; verify logs + exported audit file.  
- Coordinate with legal to update privacy policy language.  
- Release simultaneously with soft delete to cover compliance story.

---

## 5. Handwriting & Drawing

### 5.1 Phase Strategy
- **Phase 1 (Flutter canvas, vector strokes + PNG preview):** all platforms supporting touch; ensures attachment pipeline, undo stack, export integration.  
- **Phase 2 (Platform enhancements):** PencilKit integration on iOS/iPadOS; stylus APIs for Android/Samsung; optional handwriting recognition roadmap.

### 5.2 Architecture
- Storage:  
  - Add `attachment_type = drawing`, store zipped JSON strokes + PNG preview via `AttachmentService`.  
  - Extend encryption to cover stroke payloads.  
- Editor UI:  
  - Add “Draw” action in formatting toolbar; opens modal canvas (`HandwritingCanvasWidget`).  
  - Provide pen, highlighter, eraser, undo/redo, grid toggle.  
  - Insert drawing block in note content referencing attachment.  
- Sync/export:  
  - Sync attachments via existing pipeline.  
  - Update Markdown/PDF exporters to embed PNG preview; include raw strokes in ZIP export.  
- Templates/quick capture: optional Phase 2 enhancements.

### 5.3 Task Breakdown

| Area | Tasks |
| --- | --- |
| Canvas | Implement Flutter custom painter with stroke smoothing + undo stack; support pressure/velocity metadata. |
| Storage | Extend `AttachmentService` + Supabase storage rules; update migrations for attachment metadata. |
| UI | Toolbar button, modal UX, inline preview widget, editing entrypoint for existing drawings. |
| Export | Update Markdown/PDF/zip exporters; add tests. |
| Platform | Phase 2: PencilKit bridge (SwiftUI wrapper), stylus APIs for Android. |
| Tests | Golden tests for drawing block; widget tests for toolbar interactions; integration test for save/load/restore. |

### 5.4 Acceptance & Rollout
- Performance: ≥60 FPS while drawing on mid-tier devices; ≤50 MB per drawing file by default.  
- Rollout: ship Flutter canvas first behind feature flag; enable PencilKit after beta feedback.  
- Analytics: track strokes count, time spent, undo events, export usage.

---

## 6. Local AI / LLM Feature Set

### 6.1 Scope
- **Embeddings + semantic search** stored locally.  
- **Auto-tag suggestions** based on embeddings/keywords.  
- **Note summaries** generated on-demand.  
- **Premium gating**: semantic search, auto-tag, summary all require subscription or AI pack one-time purchase.

### 6.2 Architecture
- Model choice: lightweight MiniLM or similar TFLite/ggml; host via on-demand download with checksum verification.  
- Storage: new `note_embeddings` table (note_id, vector, updated_at).  
- Services:  
  - `EmbeddingService` (model lifecycle, vector computation).  
  - `SemanticSearchService` (vector retrieval + hybrid search).  
  - `AutoTagService` (top-N tag suggestion).  
  - `SummaryService` (on-demand summarization; choose extractive approach if generative too heavy).  
- UI:  
  - Update `ModernSearchScreen` to merge vector scores with keyword results.  
  - Editor surface for auto-tags plus accept/dismiss UI.  
  - Summary panel in note view with gating component.  
- Background jobs: isolate for model loading + batch embedding refresh; invalidation on note edits.

### 6.3 Task Breakdown

| Area | Tasks |
| --- | --- |
| Model Ops | Select model, run benchmarks, define download/cache strategy, implement versioning. |
| Data | Migration for embeddings table; indexes for cosine similarity. |
| Services | Implement embedding generation, hybrid search, tagging, summaries; integrate with premium gate. |
| UI | Semantic search toggle, results section, gating treatment; auto-tag chips; summary drawer. |
| Billing | Configure Adapty AI-pack product; update gating logic to check subscription OR purchase. |
| Tests | Unit tests for vector math; integration tests for search ranking; instrumentation tests on mid-tier devices. |

### 6.4 Acceptance & Rollout
- Performance: embedding generation ≤1.5s per note; semantic query ≤400ms on mid devices.  
- Accuracy: user testing with >20 notes returns expected results; auto-tags accepted ≥70% in beta.  
- Rollout: internal dogfood → beta with analytics gating → GA once stability confirmed.  
- Support: fallback to keyword search when model unavailable; display clear messaging.

---

## 7. Secure Sharing Links

### 7.1 Decisions
- Password-protected, time-limited links hosted via Supabase storage + edge function delivering encrypted payload; decrypt client-side with user-supplied password.  
- Tied to premium/AI pack; UI integrated in note overflow menu.  
- Include revocation controls and analytics.

### 7.2 Key Tasks
- Storage schema for encrypted note packages; supabase edge function to serve metadata.  
- Client flow: gather password, derive key, encrypt note + attachments (bundled as HTML + assets).  
- Viewer: responsive web page (Svelte/Next) served from edge function; password prompt + WebCrypto decrypt.  
- Management: share management panel showing active links, revoke/regenerate options.  
- Tests: cryptographic unit tests, e2e link consumption, revocation verification.

---

## 8. Monetization & Pricing Alignment

- Define Adapty offerings:  
  - Subscription tiers (Monthly, 6-Month, Annual).  
  - AI Pack one-time product (per platform) unlocking AI + secure sharing.  
- Update `SubscriptionService.presentPaywall` to launch Adapty UI; handle restore flows; ensure analytics.  
- Pricing experiments: store remote config for introductory offers; add AB testing hook.  
- Update settings UI with pricing table, manage subscription, AI pack purchase entry.  
- Coordinate with marketing on competitive pricing positioning.

---

## 9. Timeline & Staffing (High-Level)

| Sprint | Focus | Key Deliverables |
| --- | --- | --- |
| Sprint 1 | Soft delete groundwork | DB migrations, repository updates, basic trash UI. |
| Sprint 2 | Soft delete polish + anonymization | Purge automation, restore UX, anonymization flow, docs. |
| Sprint 3 | Handwriting Phase 1 | Canvas widget, attachment integration, exporters, tests. |
| Sprint 4 | Handwriting polish + AI groundwork | PencilKit spike, model benchmarking, embedding storage. |
| Sprint 5-6 | Local AI rollout | Embedding service, semantic search UI, auto-tagging, premium gating, Adapty paywall. |
| Sprint 7 | Secure sharing + monetization finalization | Link infrastructure, viewer, management UI, SKU launch. |

Roles:  
- **Mobile team (2 devs):** Flutter features, platform channels, UI.  
- **Backend (1 dev):** Supabase migrations, cron jobs, edge functions.  
- **ML engineer (contract/part-time):** Model selection, embedding pipeline.  
- **QA (1 FTE):** Test plan creation, automation, release validation.  
- **Product/Design:** UX flows, pricing decisions, documentation.

---

## 10. Verification & Launch Checklist

- [ ] All migrations applied on staging → production.  
- [ ] Feature flags + remote config validated.  
- [ ] Adapty paywall live with QA receipts.  
- [ ] Security review for anonymization + secure sharing.  
- [ ] Performance benchmarks recorded.  
- [ ] Telemetry dashboards created (trash recoveries, AI usage, handwriting adoption).  
- [ ] Support & documentation ready (help center updates, FAQ).  
- [ ] Release notes drafted; marketing assets prepared.

---

This implementation plan replaces version 1.0. Update after each major milestone or when scope changes. Keep engineering issues linked to sections above for traceability.***
