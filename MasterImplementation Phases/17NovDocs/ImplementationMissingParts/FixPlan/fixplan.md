# Duru Notes – Urgent Stabilization Fix Plan

This document aggregates every blocking issue surfaced in the latest iOS run plus the Flutter bootstrap hang, and translates them into an actionable plan. Scope: **all work required to ship a bug-free Flutter app build (iOS + shared Dart stack)**.

---

## 1. Critical Findings

| Area | Finding | Evidence |
| --- | --- | --- |
| Bootstrap | `AppBootstrap.initialize()` can hang indefinitely when any stage waits on network/SDK init. UI stays black because `FutureBuilder` never resolves. | `lib/main.dart:29`, `lib/core/bootstrap/app_bootstrap.dart` |
| Environment | We silently fall back to empty `EnvironmentConfig` when `.env` missing or malformed, so Supabase/Firebase pointers are unset without user-facing diagnostics. | `EnvironmentConfigLoader` fallback branch |
| Firebase | `GoogleService-Info.plist` exists but isn’t copied into every target (Runner + extensions). At runtime `FirebaseApp.configure()` is not called and push notifications never initialize. | Xcode log `❌ GoogleService-Info.plist not found` |
| iOS Config | Bundle identifiers differ between Flutter xcconfigs and plist/entitlements. Extensions use 1.0.0-dev while Runner uses 1.0.0 → Xcode warning “app extension version must match parent”. | `ios/Flutter/*.xcconfig`, `Runner.entitlements`, extension Info.plist |
| Build Output | Simulator build stores frameworks outside the sandbox root causing hundreds of “stale file … outside allowed root paths” warnings. | Issue Navigator dump |
| Pods | Deployment target mismatches (9.0/11.0 vs project 15.0) and outdated plugin APIs (deprecated window APIs, UNNotificationPresentationOption) flood build with warnings and risk crashes. | Pod targets list |
| Swift 6 | AdaptyUI pods compiled with Swift 6 flag but still produce “non-sendable key path” errors that will become build failures when Swift 6 is enforced. | Pod warnings from Sentry log |
| Share Ext. | Method channels (QuickCapture, ShareExtension) assume `window?.rootViewController` in `AppDelegate`, which is deprecated and occasionally nil on iOS 15+ leading to `[QuickCapture] Unable to locate FlutterViewController`. | `ios/Runner/AppDelegate.swift:52` |

---

## 2. Objectives

1. **Guarantee app bootstrap resolves (success or failure) within bounded time** and surfaces actionable diagnostics inside the Flutter UI.
2. **Align iOS project config** (bundle IDs, versions, entitlements, build dirs, Firebase assets) across Runner + extensions.
3. **Modernize plugin/native code** to the current iOS SDK level so the build is warning-free and future-proof (deployment target ≥ 15, Swift 6 safe).
4. **Verify high-risk functionality** (push notifications, share extension, quick capture widget, encryption unlock) with automated tests.

---

## 3. Work Breakdown (Sequenced)

### 3.1 Bootstrap & Diagnostics (Dart)

1. Instrument each `BootstrapStage` with logging + timeout fallback (`lib/core/bootstrap/app_bootstrap.dart`).
2. Expose bootstrap summary + warnings in `BootstrapFailureContent` (add detail cards).
3. Add `EnvironmentConfigLoader` validation: fail fast if Supabase URL/key absent, list which env file loaded (`assets/env/*.env`).
4. Update `App` widget to check that `bootstrapResult` contains required services before building `AuthWrapper`. Route to failure UI if not.
5. Create `integration_test/bootstrap_smoke_test.dart` to assert the app renders a signed-out shell with mocked Supabase/Firebase.

### 3.2 iOS Project Alignment

1. **Firebase assets**
   - Add `GoogleService-Info.plist` to Runner, ShareExtension, QuickCapture widget Copy Resources.
   - Ensure `Runner` and extensions call `FirebaseApp.configure()` once (centralize in AppDelegate helper).
2. **Bundle identifiers & versions**
   - Update `ios/Flutter/*.xcconfig` to use real bundle IDs (`com.fittechs.duruNotesApp[.dev/.staging]`) and remove hard-coded 1.0.0-dev for extensions. Set `MARKETING_VERSION=$(FLUTTER_BUILD_NAME)` uniformly.
   - Sync entitlements (`Runner.entitlements`, extensions) with new bundle IDs.
3. **Build directory / stale files**
   - Create `ios/Flutter/BuildOverrides.xcconfig` to set `FLUTTER_BUILD_DIR=$(PROJECT_DIR)/FlutterBuild`.
   - Include from Dev/Staging/Prod configs, clean `build/` + DerivedData.
4. **AppDelegate modernisation**
   - Replace `window?.rootViewController` with scene-based lookup.
   - Guard Firebase-only code paths with `if FirebaseApp.app() != nil`.
5. **Pod deployment target**
   - In `post_install`, enforce `IPHONEOS_DEPLOYMENT_TARGET = 15.0` for every pod target.

### 3.3 Plugin / Pod Updates

1. Upgrade Flutter plugins where upstream already fixed iOS 15+ APIs: `share_plus`, `url_launcher_ios`, `image_picker_ios`, `printing`, `open_file`, `sentry_flutter`, `firebase_*`, `flutter_local_notifications`, `permission_handler`, `connectivity_plus`, `device_info_plus`, `battery_plus`, `fl_location`, `geolocator`.
2. Where upstream fix is unavailable, patch via dependency overrides (store diffs in `patches/` or `packages/` folder):
   - `argon2_ffi`: guard `DEBUG` macro, fix `unsigned long` → `uint32_t`.
   - `objective_c`: add parameter names, fix casts.
   - `flutter_local_notifications` & `firebase_messaging`: include new `UNNotificationPresentationOptions`.
   - `file_picker`: migrate to `UTType` and new document picker initializers.
3. Adapty / AdaptyUI pods: update to latest release. If warnings remain, add interim patches (`@Sendable`, remove unused vars).
4. Document every override in `pubspec.yaml` comments + `docs/MasterImplementation Phases/…`.

_Nov 2025 status:_ `pubspec.yaml` now pins the latest Firebase (4.2.1 core / 16.0.4 messaging), Adapty (3.11.3), Sentry (9.8.0), crypto (3.0.7), and forces the newest `url_launcher_ios`, `image_picker_ios`, `shared_preferences_*`, and `path_provider_*` via `dependency_overrides` per this section. Added `test/services/share_extension_service_test.dart` to validate that the Flutter share-extension pipeline ingests App Group payloads into the repository without hitting Supabase, `test/services/quick_capture_widget_syncer_test.dart` to ensure widget payloads are pushed/cleared over the iOS MethodChannel, `test/services/push_notification_service_test.dart` to cover the FCM registration flow with mocked Firebase/Supabase dependencies, and `scripts/ci_ios.sh` to run analyze/tests/integration smoke builds plus `xcodebuild` on CI.

### 3.4 Testing & Verification

1. Write integration tests for:
   - Push notification registration (mock `UNUserNotificationCenter` via platform channel in test harness).
   - Share extension ingestion (`shareExtensionServiceProvider` should read items inserted via method channel).
   - Quick capture widget sync (ensure App Group store writes propagate).
   - Encryption unlock flow (simulate both device-only and cross-device modes).
2. Add CI entry (`scripts/ci_ios.sh`) to run `flutter analyze`, `flutter test`, `integration_test`, and `xcodebuild` (simulator, codesign off). Fail on warnings using `OTHER_CFLAGS = -Werror`.
3. Update `QA_MANUAL_TESTING_CHECKLIST.md` with new scenarios (bootstrap fallback, share extension, widget).

---

## 4. Deliverables Checklist

- [x] Bootstrap instrumentation + timeout fallback merged.
- [x] Environment validation errors surfaced in-app.
- [x] Firebase plist copied to all targets; push notifications verified.
- [x] Bundle IDs, versions, entitlements aligned for Runner + extensions.
- [x] Build artifacts relocated (no “stale file outside root” warnings).
- [x] Pod deployment target locked at 15.0, build logs warning-free.
- [x] Plugin upgrades/patches applied; Swift 6 warnings resolved.
- [ ] Integration + CI tests covering bootstrap, push, share, widget, encryption.
- [ ] Documentation updated (env instructions, CI steps, new tests).

---

## 5. Open Questions / Dependencies

1. **Production Firebase keys** – confirm latest plist before shipping (current dev keys from `assets/env/dev.env` are placeholders).
2. **Adapty credentials** – align environment variables per flavor to avoid accidental activation against production during dev runs.
3. **Supabase migrations** – confirm `MigrationTablesSetup` doesn’t require online access during bootstrap; otherwise add offline short-circuit.
4. **Testing infrastructure** – need confirmation we can run `integration_test` suite on CI (which simulator/device matrix is allowed?).

---

Prepared by Codex (GPT‑5) for the Duru Notes stabilization effort. All further implementation tasks should reference section numbers above to keep commits traceable.
