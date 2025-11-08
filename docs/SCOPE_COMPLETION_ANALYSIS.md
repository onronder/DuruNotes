# Duru Notes – Scope Completion Analysis (INITIAL_TODO.md)

**Document version:** 2.0  
**Date:** 2025-10-31  
**Codebase ref:** `main` (workspace snapshot during review)

## 1. Executive Summary

- **Completed items:** Editor V2 refinements, saved-search chips, pin/sort controls, task system (metadata, reminders, calendar view), quick-capture pipeline (Flutter service + native widgets), import/export polish, web clipper & email-in, premium scaffolding primitives.  
- **Partially complete:** Quick capture is missing the iOS share-extension bridge; paywall scaffolding lacks feature consumers; semantic search UI is a stub without embeddings.  
- **Not started:** Handwriting/drawing workflow, secure sharing links, on-device AI models (semantic search, auto-tag, summaries).  
- **Testing posture:** Existing suites cover most implemented areas; no automated coverage yet for trash/restore, anonymization, handwriting, or ML.  
- **Key risks:** Missing restore/purge flows make hard-delete requirement impossible today; premium gating currently cosmetic.

## 2. Scope Coverage Table

| INITIAL_TODO item | Status | Evidence |
| --- | --- | --- |
| Handwriting & Drawing | ❌ Not started | Editor toolbar stops at text formatting (`lib/ui/modern_edit_note_screen.dart#L1174`); no drawing canvases present. |
| On-device AI (semantic search, auto-tags, summaries) | ❌ Not started | Semantic toggle only switches to keyword matching placeholder (`lib/ui/modern_search_screen.dart#L101`); no embedding storage in repositories. |
| Organization (Folders, Saved Searches, Pinning/Sorting) | ✅ Complete | Folder CRUD & hierarchy (`lib/infrastructure/repositories/folder_core_repository.dart#L242`); saved-search chips with counts (`lib/ui/widgets/saved_search_chips.dart#L23`); pin-aware sorting in notes list (`lib/ui/notes_list_screen.dart#L2136`). |
| Tasks & Reminders | ✅ Complete | Task domain model (`lib/domain/entities/task.dart#L1`); enhanced task list/calendar (`lib/ui/enhanced_task_list_screen.dart#L31`); reminder bridge with notifications (`lib/services/task_reminder_bridge.dart#L100`). |
| Quick-Capture (widgets, share sheet, templates) | ⚠️ Partial | Flutter capture service + Android/iOS widgets (`lib/services/quick_capture_service.dart#L60`, `android/app/.../QuickCaptureWidgetProvider.kt#L26`, `ios/QuickCaptureWidgetExtension/QuickCaptureWidgetExtension.swift#L1`); iOS share-extension channel not wired (`lib/services/share_extension_service.dart#L14` vs `ios/Runner/AppDelegate.swift#L9`). |
| Secure Sharing (password-protected links) | ❌ Not started | Sharing still uses plain SharePlus export (`lib/services/export_service.dart#L559`). |
| Import/Export polish (ENEX, MD/PDF) | ✅ Complete | ENEX parser/validator (`lib/services/import_service.dart#L200`); Obsidian import (`lib/services/import_service.dart#L345`); PDF export pipeline (`lib/services/export_service.dart#L298`). |
| Paywall scaffolding (flags & gating) | ⚠️ Partial | Premium gate widget & Adapty service exist (`lib/ui/components/premium_gate_widget.dart#L11`, `lib/services/subscription_service.dart#L101`), but no features currently wrap with the gate and `presentPaywall` short-circuits. |

### Completed extras outside the checklist
- Editor V2 foundational work (all E2.x items checked in INITIAL_TODO).
- Web clipper & inbound email capture (# already marked done in INITIAL_TODO).

### Additional gaps (new requirements from product brief)
- **Soft delete with 10-day recovery:** No trash tables or timers; repository `deleteNote` is a hard flag flip with no recovery window (`lib/infrastructure/repositories/notes_core_repository.dart#L2282`).
- **GDPR anonymization:** GDPR service exports/deletes but lacks defensive anonymization routine aligned with encryption rotation for accounts that stay active (`lib/services/gdpr_compliance_service.dart#L167` handles hard deletion only).
- **Pricing/monetization:** Adapty scaffolding present, but SKU definitions, paywall UX, and “LLM one-time purchase” SKU do not exist in code or config.

## 3. Implementation Quality Notes

- **Folders & saved searches:** Domain & infrastructure layers consistently enforce user scoping and encryption; UI wires counts and filters correctly.  
- **Tasks & reminders:** Metadata dialog manages due dates, reminders, and labels; reminder bridge schedules notifications with retry logic and deep linking.  
- **Quick capture:** Uses encrypted queue + native widgets; missing glue code for iOS share extension means “Share to Duru” remains stubbed.  
- **Imports/exports:** ENEX, Obsidian, Markdown, PDF flows are production-ready with progress reporting and error aggregation.

## 4. Testing & Observability Snapshot

- Unit/integration tests exist for editor, tasks, import/export (see `test/services/*`, `test/ui/*`).  
- No automated coverage yet for premium gating, trash flows, anonymization, or handwriting.  
- Sentry logging already embedded across repositories and UI actions.  
- Analytics events fire for folder, saved-search, quick-capture, and reminder usage; new features must hook into the same infrastructure.

## 5. Recommended Next Steps

1. **Close partial items before net-new work**  
   - Wire iOS share extension method channel and add regression tests.  
   - Wrap existing premium-worthy experiences (semantic search once implemented, secure sharing, AI) with `PremiumGateWidget`.  
   - Update `SubscriptionService.presentPaywall` to open the real Adapty paywall or a temporary “coming soon” dialog with instrumentation.

2. **Implement new product asks in the following order**  
   1. Soft delete → recovery → purge pipeline.  
   2. GDPR-compliant anonymization & key rotation helper.  
   3. Handwriting capture (start with Flutter canvas + attachment pipeline, then PencilKit/S Pen enhancements).  
   4. Local LLM (embeddings, auto-tagging, summaries) with gating and offline capability.  
   5. Secure sharing links backed by Supabase storage/edge functions.

3. **Augment testing**  
   - Add golden tests for trash/restore UI, anonymization flows, drawing persistence, semantic search ranking, and secure link consumption.  
   - Include instrumentation tests for platform integrations (handwriting canvas, share extension, notification scheduling).

4. **Documentation updates**  
   - Produce ADRs for soft-delete architecture, anonymization strategy, handwriting storage format, and ML model selection.  
   - Refresh developer onboarding with new module diagrams once features land.

## 6. Decision Register (new since v1.0)

| ID | Decision | Rationale | Follow-up |
| --- | --- | --- | --- |
| DR-2025-10-01 | Treat soft delete as a compliance-critical requirement; implement before secure sharing and AI. | Enables legal recovery windows and aligns with anonymization pipeline. | Design trash schema & migration. |
| DR-2025-10-02 | Use premium gating for any AI-powered or secure sharing functionality; paywall UX must be functional before GA. | Keeps pricing strategy consistent (LLM as add-on). | Define Adapty placement IDs and SKU plan. |
| DR-2025-10-03 | Initial handwriting implementation will store vector strokes + raster preview in encrypted attachments. | Balances fidelity with sync and export requirements. | Define JSON schema for stroke data; update exporter. |
| DR-2025-10-04 | Local AI stack will be TFLite-based with background embedding refresh and offline-first behavior. | Meets privacy/offline positioning and mobile constraints. | Benchmark candidate models on target devices. |

---

This analysis supersedes the prior v1.0 snapshot and should be treated as the authoritative baseline for upcoming planning and execution. Updates are required after each major feature lands.***
