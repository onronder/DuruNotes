# Quick Capture & Templates Rebuild: Technical Design

## 1. Scope & Success Criteria
- Provide a production-grade quick capture experience spanning:
  - Flutter core service + controller exposing quick actions (text, voice stub, camera stub, template-based capture).
  - Android home-screen widget (existing Kotlin implementation hardened, encrypted storage, robust analytics).
  - New iOS WidgetKit extension with feature parity.
- Seed and surface encrypted note templates (system + user) across the capture flow and existing template gallery.
- Guarantee offline resilience, cross-device sync via repositories, and observability (analytics, logs, Sentry).
- Deliver comprehensive automated test coverage (unit, widget, integration, platform harness) and migration scripts.

## 2. Functional Requirements
1. **Fast capture entry points**
   - Widget quick actions: text input launch, voice memo shortcut (placeholder if ASR not ready), camera capture shortcut.
   - In-app capture sheet for incoming MethodChannel events (widget, deep link, shortcuts).
   - Optional template selection per capture.
2. **Template management**
   - Ship curated system templates encrypted in AppDb; expose via TemplateCoreRepository.
   - Allow user-defined templates (existing Template UI) and ensure they appear in capture picker.
3. **Offline & queue handling**
   - Queue captures when offline; automatically process when connectivity/auth is restored.
   - Persist queue encrypted and size-bounded (FIFO eviction).
4. **Security & privacy**
   - All stored template/capture data encrypted at rest (SharedPreferences replacement, iOS shared container).
   - Authenticate widget actions (ensure active session, fail gracefully otherwise).
5. **Observability**
   - Emit analytics events and logs for capture lifecycle, queue processing, template usage, widget refresh.
   - Add Sentry breadcrumbs for failures.
6. **Cross-platform parity**
   - Android widget + iOS WidgetKit share identical feature sets and data schema.

## 3. Architecture Overview

### 3.1 Flutter Core Layers
- **QuickCaptureService (new)**  
  - Stateless API orchestrating captures, referencing repositories via injected interfaces.  
  - Responsibilities:
    - Validate input (length, template existence, user auth).
    - Construct capture payloads (title/body metadata).
    - Enqueue tasks when offline; process queue when online.
    - Provide recent captures list and template metadata for widgets/UI.
  - Implementation details:
    - Introduce `QuickCaptureRepository` abstraction wrapping AppDb tables for queue + widget cache (encrypted columns).
    - Interact with `TemplateCoreRepository`, `NotesCoreRepository`, `AttachmentService`, `AnalyticsService`.
    - Manage background processing via `FutureQueue` or `IsolatedExecutor` pattern to avoid UI blocking.

- **QuickCaptureController / Riverpod Provider**
  - Bridge between UI, MethodChannel events, and service API.
  - Handles state (loading, success, error), template picking, voice/camera fallback flows.
  - Observes connectivity/auth providers to trigger queue processing.

- **MethodChannel Bridge**
  - Standardize channel name `com.fittechs.durunotes/quick_capture`.
  - Define message schema:
    - `handleWidgetCapture` (type: text/voice/camera/template, payload fields).
    - `requestWidgetDataRefresh`, `updateWidgetData`, `getAuthStatus`, `getPendingCaptures`, etc.
  - Provide strongly typed dispatcher in Dart with error handling + analytics.

### 3.2 Data Model & Persistence
- **AppDb additions**
  - `quick_capture_queue` table: id, user_id, payload (encrypted JSON), created_at, platform, retry_count.
  - `widget_cache` table: id, user_id, data (encrypted JSON), updated_at.
  - Migrations ensure multi-user isolation and cleanup.
- **Template seeding**
  - Add migration generating system templates on first run. Use encrypted insert via TemplateCoreRepository utilities.
  - Include template metadata (category, icon) to align with widget quick actions.

- **Shared Storage**
  - Android: Replace direct SharedPreferences with EncryptedSharedPreferences + JSON schema {recentCaptures:[], templates:[], authToken}.
  - iOS: Use App Group container + `NSUserDefaults(suiteName:)` with CryptoKit encryption wrapper or share minimal data (IDs) and retrieve bodies from Flutter via background refresh.

### 3.3 Platform Integrations
- **Android**
  - Harden `QuickCaptureWidgetProvider`:
    - Inject encrypted storage helper.
    - Validate auth state before actions.
    - Use WorkManager or AlarmManager for periodic refresh.
    - Clean up logging, ensure main-thread safety.
  - Update `MainActivity` MethodChannel handler to use new schema, add queue sync invocation.

- **iOS WidgetKit (detailed steps later)**
  - Create `QuickCaptureWidget` target with SwiftUI view.
  - Use shared App Group for cache data; schedule timeline updates.
  - Mirror MethodChannel API via `FlutterMethodChannel` bridging.
  - Provide intents extension if template selection needed.

## 4. Detailed Implementation Plan

### Phase A: Foundations & Service Refactor
1. Define new AppDb tables + migration scripts (with tests).
2. Create `QuickCaptureRepository` (AppDb facade) + unit tests.
3. Refactor `QuickCaptureService` to:
   - Accept repository interfaces.
   - Implement capture, queue, template retrieval, widget cache updates.
   - Integrate analytics/logging.
4. Introduce Riverpod provider + controller for UI + MethodChannel binding.
5. Update template seeding pipeline (reuse TemplateCoreRepository).
6. Author unit/widget tests for service/controller.

### Phase B: Flutter UI & Template UX
1. Build capture sheet UI (text input, template list, voice stub).
2. Hook into `handleWidgetCapture` flows.
3. Ensure template selection pulls from TemplateCoreRepository.
4. Expand template gallery to show new system templates + metadata.
5. Add widget tests covering capture dialog interactions and queue error states.

### Phase C: Android Platform Hardening
1. Implement encrypted storage helper (Jetpack Security).
2. Refactor widget provider/config activity to use helper + new schema.
3. Align analytics/logging; add WorkManager-based refresh pipeline.
4. Update `MainActivity` channel handlers + pending capture flow.
5. Write Robolectric/unit tests for storage helper + widget serialization (# instrumented tests optional).

### Phase D: iOS WidgetKit Extension (step-by-step guide to follow)
1. Create app group & entitlements.
2. Scaffold WidgetKit target, shared models, and encryption helper.
3. Implement Swift ↔ Flutter bridge; ensure MethodChannel messages propagate.
4. Add timeline provider, placeholder, snapshot, and event handling.
5. Validate with unit/UI tests; document manual setup.

### Phase E: QA, Analytics & Release
1. Write integration tests spanning capture → template → widget update.
2. Add analytics event constants & monitor dashboards.
3. Update documentation (user guide, developer setup).
4. Staged rollout with feature flags and telemetry tracking.

## 5. Testing Strategy
- **Unit tests**: QuickCaptureService, repository, template seeding, storage helpers.
- **Widget tests**: capture dialog, template picker.
- **Integration tests**: MethodChannel interactions, offline queue processing.
- **Platform tests**: Android instrumentation for widget intents, iOS unit/UI tests for WidgetKit timeline.
- **Migration tests**: Validate new AppDb tables + template seeds with drift tests.

## 6. Risks & Mitigations
- **Authentication mismatch**: Ensure capture attempts verify session; queue items tagged with userId to avoid leakage.
- **Encryption failures**: Wrap crypto operations with fallbacks + telemetry to detect issues early.
- **Widget data staleness**: Use scheduled refresh + manual triggers, track last update timestamp.
- **iOS extension complexity**: Provide granular setup guide (forthcoming) and scripts to automate entitlements/config.

## 7. Next Steps
- Execute Phase A tasks (service refactor + repo/migrations).
- Prepare detailed WidgetKit development checklist before Phase D.
- Coordinate with product/design for template copy and widget UX assets.
