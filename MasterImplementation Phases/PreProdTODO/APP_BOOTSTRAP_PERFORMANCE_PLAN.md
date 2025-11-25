# App Bootstrap Performance Refactor Plan (Launch Hang Fix)

**Objective**: Eliminate the ~30s white-screen / app-hang during initial launch by restructuring the bootstrap pipeline so that:
- First UI (splash/login) appears in <1–2 seconds.
- Heavy backend initialization (Firebase, Supabase, migrations, feature flags, analytics, Adapty) runs **after** `runApp()` in the background.
- Failure of non-critical services never blocks the user from reaching the login screen.

This plan is **architecture-first** and avoids breaking existing behavior; we re-stage work without changing core business logic.

---

## 1. Current Behavior (Baseline)

### 1.1 Startup Flow

- **File**: `lib/main.dart`
  - `main()`:
    - `WidgetsFlutterBinding.ensureInitialized()`
    - `final bootstrap = AppBootstrap();`
    - `final bootstrapResult = await bootstrap.initialize();`
    - `runApp(BootstrapApp(initialResult: bootstrapResult, ...));`

Result: **no Flutter UI is rendered until `AppBootstrap.initialize()` completes**.

### 1.2 Bootstrap Stages (all run before `runApp()`)

- **File**: `lib/core/bootstrap/app_bootstrap.dart`
  - Stages in `AppBootstrap.initialize()`:
    1. `environment` – load `EnvironmentConfig`
    2. `logging` – initialize `LoggerFactory`
    3. `platform` – `AndroidOptimizations.initialize`
    4. `monitoring` – configure & initialize Sentry
    5. `firebase` – `Firebase.initializeApp`
    6. `supabase` – `Supabase.initialize`
    7. `migrations` – local migration tables + seed + templates
    8. `featureFlags` – `FeatureFlags.updateFromRemoteConfig`
    9. `analytics` – `AnalyticsFactory.initialize` + `appLaunched` event
    10. `adapty` – Adapty activation (paywall SDK)
    11. `platform` again – preload `SharedPreferences`

- Each stage is wrapped by `_runStage` with:
  - `_stageTimeout = Duration(seconds: 8);`
  - Failures/Timeouts recorded as `BootstrapFailure`, but the **timeout duration is still waited**.

Worst-case: Several network-bound stages × 8s each → ~30–40 seconds before the first UI frame.

---

## 2. Target Architecture

### 2.1 Design Goals

1. **Fast first paint**:
   - Render a splash/login screen after minimal local setup (<1–2s).
2. **Async backend bootstrap**:
   - Run Sentry, Firebase, Supabase, migrations, feature flags, analytics, Adapty **after** `runApp()`.
3. **Clear critical vs non-critical**:
   - Only block login flows on truly required services (e.g., Supabase, local DB).
4. **Observable performance**:
   - Preserve and extend `stageDurations` so we can monitor boot behavior over time.

### 2.2 New Phases

**Phase A – Fast Bootstrap (Pre-UI, before `runApp`)**
- Load environment config (local).
- Initialize logging.
- Build a minimal `BootstrapResult` that marks remote services as “pending”.

**Phase B – Async Backend Bootstrap (Post-UI, after first frame)**
- In the app layer, kick off:
  - Sentry init
  - Firebase init
  - Supabase + migrations + templates
  - Feature flags
  - Analytics
  - Adapty
  - SharedPreferences preload
- Run independent tasks in **parallel** where possible.

**Phase C – Feature Readiness Gating**
- Use Riverpod or a simple state holder to expose:
  - `backendReady` (overall)
  - Per-service readiness flags (e.g., `supabaseReady`, `analyticsReady`, `adaptyReady`).
- UI uses these flags to:
  - Show login UI immediately.
  - Gate actions that require remote services with spinners / “Connecting…” states, not a blank screen.

---

## 3. Implementation Plan (Step-by-Step)

### 3.1 Add a Lightweight Bootstrap Result Model

- **File**: `lib/core/bootstrap/app_bootstrap.dart`

1. Extend `BootstrapResult` with **readiness flags**:
   - `final bool backendInitialized;`
   - `final bool supabaseReady;`
   - `final bool firebaseReady;`
   - `final bool analyticsReady;`
   - `final bool sentryReady;`
   - `final bool adaptyReady;`
   - All default to `false` in the fast path.

2. Add helper constructors:
   - `BootstrapResult.fast(EnvironmentConfig env, AppLogger logger)`:
     - Initializes `environment`, `logger`, `analytics` as a NoOp instance.
     - All backend flags `false`.
     - `sentryEnabled = false`, `adaptyEnabled = false`.

### 3.2 Split AppBootstrap Into Fast + Full

- **File**: `lib/core/bootstrap/app_bootstrap.dart`

3. Add new method:
   - `Future<BootstrapResult> initializeFast()`:
     - Runs only:
       - Environment stage (`_runStage` for `BootstrapStage.environment`).
       - Logging stage.
     - **Does NOT** call Firebase, Supabase, Sentry, analytics, Adapty, migrations.
     - Builds `BootstrapResult.fast(...)` using loaded `EnvironmentConfig` and `LoggerFactory.instance`.

4. Keep existing `initialize()` but:
   - Refactor its body into a new method:
     - `Future<BootstrapResult> initializeBackend(BootstrapResult base)`.
   - `initializeBackend`:
     - Receives a `BootstrapResult` with environment/logger.
     - Runs stages 3–11 (platform, monitoring, firebase, supabase, migrations, feature flags, analytics, adapty, SharedPreferences preload).
     - Returns a **new** `BootstrapResult` with readiness flags set appropriately.

### 3.3 Change main() to Use Fast Bootstrap Only

- **File**: `lib/main.dart`

5. Update `main()`:
   - Instead of:
     ```dart
     final bootstrap = AppBootstrap();
     final bootstrapResult = await bootstrap.initialize();
     runApp(BootstrapApp(initialResult: bootstrapResult, ...));
     ```
   - Use:
     ```dart
     final bootstrap = AppBootstrap();
     final fastResult = await bootstrap.initializeFast();
     runApp(
       BootstrapApp(
         initialResult: fastResult,
         bootstrapOverride: bootstrap,
       ),
     );
     ```
   - Now `runApp()` happens after only environment + logging.

### 3.4 Orchestrate Backend Init Inside BootstrapApp

- **File**: `lib/main.dart`

6. Extend `_BootstrapAppState` to track backend initialization:
   - Add:
     - `bool _backendInitialized = false;`
     - `BootstrapFailure? _backendError;` (optional).
   - In `initState()`:
     - After assigning `_result`, call an async method:
       - `unawaited(_initBackend());`

7. Implement `_initBackend()`:
   - Calls `_bootstrap.initializeBackend(_result)` in a try/catch:
     - On success:
       - `setState(() { _result = backendResult; _backendInitialized = true; });`
     - On failure/timeout:
       - Capture into `_backendError` and mark `_backendInitialized = false;`
       - Optionally log via `_result.logger`.

8. Provider overrides remain the same:
   - `bootstrapResultProvider.overrideWithValue(_result)` will now:
     - Provide fast result initially.
     - Later provide full backend-initialized result when `_initBackend()` completes.

9. UI behavior in `BootstrapShell`:
   - **No change to failure handling**, but:
     - Use `result.backendInitialized`, `supabaseReady`, etc., to adjust UI:
       - For example, show a small “Connecting to server…” indicator on login screen until `supabaseReady == true`.

### 3.5 Parallelize Network Stages in initializeBackend

- **File**: `lib/core/bootstrap/app_bootstrap.dart`

10. Adjust `initializeBackend` to run independent stages in parallel where safe:
    - Example:
      - After environment/logger:
        ```dart
        final futures = <Future<void>>[];

        futures.add(_runStage<void>(stage: BootstrapStage.monitoring, ...));  // Sentry
        futures.add(_runStage<void>(stage: BootstrapStage.firebase, ...));    // Firebase
        // Supabase may be required for migrations; keep it sequential or parallel with Firebase if safe.

        await Future.wait(futures);
        ```
      - Then run Supabase + migrations sequentially (if they depend on each other).
      - Feature flags & analytics can run after Supabase but do not need to be serialized with Sentry/Firebase.

11. Reduce `_stageTimeout` for non-critical network stages:
    - Consider:
      - `monitoring`, `analytics`, `adapty`: 3s timeout.
      - `firebase`, `supabase`: keep at 8s or reduce to 5s based on real-world testing.
    - Implementation:
      - Allow `_runStage` to accept an optional `timeout` parameter:
        - `Future<T?> _runStage<T>({ ..., Duration? timeout, ... })`
        - Use `timeout ?? _stageTimeout` in `action().timeout(...)`.

### 3.6 Feature Readiness Flags and UI Usage

- **File**: `lib/core/bootstrap/app_bootstrap.dart`, `lib/main.dart`, and relevant UI screens.

12. Set readiness flags inside `initializeBackend`:
    - After successful Sentry init:
      - `sentryEnabled = true;`
      - `sentryReady = true;`
    - After Firebase init:
      - `firebaseReady = true;`
    - After Supabase + migrations:
      - `supabaseReady = true;`
    - After analytics init:
      - `analyticsReady = true;`
    - After Adapty init (or recognized “already activated” condition):
      - `adaptyReady = true;`
    - At the end of `initializeBackend`:
      - `backendInitialized = true;`

13. In critical UI flows (e.g., login screen):
    - If `supabaseReady == false` and environment requires Supabase:
      - Show a small inline “Connecting to server…” state.
    - Allow navigation and basic UI even while some services are still initializing.

### 3.7 Monitoring and Sentry AppHang Tuning

- **Files**: `lib/core/monitoring/sentry_config.dart` (and Sentry config files)

14. Keep `stageDurations` logging:
    - Continue to record stage durations and include them in:
      - Logs.
      - Optionally a Sentry breadcrumb or a custom `bootstrap_summary` event.

15. Adjust Sentry AppHang behavior in **development**:
    - Increase AppHang threshold in dev builds (e.g., 5–8s) to reduce noise from simulator.
    - Keep production threshold at 2s if you want strict monitoring for real users.

---

## 4. Risk Assessment & Guardrails

### 4.1 Compatibility

- Existing bootstrap behavior (which services are initialized) remains; only the **timing** changes.
- Riverpod overrides stay the same; only `BootstrapResult` content evolves over time.
- All “critical failure” handling is preserved via `BootstrapFailure` and `BootstrapShell`.

### 4.2 Gradual Rollout

1. Implement **initializeFast** + `main()` change and verify:
   - App starts quickly.
   - `stageDurations` still recorded.
2. Implement `initializeBackend` with parallelization but keep `_stageTimeout` as-is.
3. After verifying stability, reduce timeouts for non-critical stages.
4. Add readiness flags and slowly wire UI to them (start with read-only display/logging, then use them for “Connecting…” states).

---

## 5. Expected Outcome

After this refactor:

- The white-screen / splash phase at launch drops from ~30s to **<2s** in normal conditions.
- Backend services (Sentry, Firebase, Supabase, feature flags, analytics, Adapty) initialize in the background without blocking first paint.
- Sentry AppHang events at launch disappear or become rare, because the main thread is no longer stalled waiting for network-bound bootstrap.
- You still retain full visibility into bootstrap performance via `stageDurations` and Sentry/analytics, allowing continuous tuning.

