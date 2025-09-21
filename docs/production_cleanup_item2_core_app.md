# Item 2 – Core Application Bootstrap Cleanup

This document analyses the current startup flow (`lib/main.dart`, `lib/app/app.dart`, `core/config`, `core/monitoring`) and defines the work required to harden the production bootstrap. Tasks build on Item 1; complete them sequentially to avoid regressions.

---
## 1. Current State Assessment

### 1.1 Entry Point & Service Initialization
- `lib/main.dart` initializes environments, Firebase, Supabase, Sentry, analytics, Adapty, and feature flags inline. Global `late` variables (`logger`, `analytics`) are set at top-level, making ordering fragile.
- Initialization errors are swallowed after a single catch block; the app still runs even if Supabase/Firebase fail, leaving services in undefined states.
- Navigation relies on a global `navigatorKey` exported from `main.dart`.
- `_initializeServices()` configures Adapty with hard-coded API keys, writes to analytics immediately, and logs using global instances.

### 1.2 Environment Configuration
- `EnvironmentConfig` loads `.env` assets but embeds production Supabase defaults directly in code (`jtaedgpxesshdrnbgvjr.supabase.co`, anon key). Secrets remain compiled in builds.
- Debug flags (crash reporting, analytics) are tied to env variables but default to disabled; there is no injection via providers.
- `EnvironmentConfig` also handles remote feature flags, Supabase initialisation, and Sentry toggles, mixing concerns.

### 1.3 Logging & Monitoring
- `LoggerFactory.initialize()` is invoked manually; the instance is stored globally (`logger`) and reused across modules rather than injected.
- Sentry is initialized both in `SentryConfig` and inside services; error boundary also references `AppLocalizations` keys that may not exist.
- `analytics` global uses `AnalyticsFactory`, but events are fired during bootstrap regardless of initialization success.

### 1.4 Supabase/Firebase Integration
- Supabase and Firebase initialisation is synchronous and uses values from `EnvironmentConfig.current`; there is no error surface to the UI if configuration is invalid.
- Supabase credentials are not refreshed or validated; missing environment variables fall back to the compiled defaults.

### 1.5 App Composition
- `AppWithShareExtension` wraps the root widget in `ErrorBoundary`, `ProviderScope`, and `SentryAssetBundle`, but dependency injection happens before Riverpod providers are ready.
- `FeatureFlaggedProviders` uses static fetch in `_initializeFeatureFlags()`; no central place to override for tests.

---
## 2. Cleanup & Refactor Plan

### Phase 1 — Introduce Bootstrap Layer
1. Create a dedicated `AppBootstrap` class (e.g. `lib/core/bootstrap/app_bootstrap.dart`) responsible for:
   - Loading environment configuration.
   - Initialising logging, monitoring, backend SDKs, feature flags, and analytics.
   - Surfacing initialization failures (return result object with success/errors).
2. Update `main.dart` to:
   - Call `WidgetsFlutterBinding.ensureInitialized()`.
   - Instantiate `AppBootstrap`, await `initialize()`, and pass the result to a revised root widget.
   - Remove global `late` variables; use Riverpod providers (or inherited widgets) to expose dependencies.

### Phase 2 — Harden Environment Configuration
1. Strip hard-coded Supabase defaults from `EnvironmentConfig`; require `.env` or `--dart-define` to supply secrets.
2. Move environment detection and DTO creation into bootstrap; expose results via a `Provider<EnvironmentConfig>` instead of static singleton.
3. Replace `dotenv` usage where possible with compile-time defines for production builds; document fallback behaviour.
4. Ensure sensitive values (keys, secrets) are never logged; adjust `getSafeConfigSummary()` accordingly.

### Phase 3 — Logging & Monitoring Refactor
1. Replace global `logger` with a Riverpod provider (e.g. `loggerProvider`) that wraps `LoggerFactory.instance`.
2. Move Sentry initialization into bootstrap, returning a bool/instance to indicate readiness.
3. Update `ErrorBoundary` to consume the logger provider rather than static globals; handle missing localization keys gracefully.
4. Ensure analytics is provided via Riverpod (`analyticsProvider`) and only emits events after successful initialization.

### Phase 4 — Backend SDK Initialization
1. Encapsulate Firebase and Supabase setup inside bootstrap; surface typed failure events (e.g. `BootstrapFailure.firebase`, `BootstrapFailure.supabase`).
2. Remove inline Adapty configuration; introduce a feature flag or environment gate to disable it when not configured.
3. Update services (`EnhancedTaskService`, reminder coordinator) to read Supabase/Firebase instances via providers rather than global state.

### Phase 5 — Root Widget & Navigation
1. Refactor `AppWithShareExtension` to accept a `BootstrapState` (loaded/loading/error) and display meaningful fallback UI if initialization fails.
2. Provide the navigation key through Riverpod (e.g. `navigatorKeyProvider`) or `NavigatorObservers` instead of a global.
3. Ensure Riverpod `ProviderScope` is the first widget after `runApp`, and inject dependencies via overrides based on bootstrap results.

### Phase 6 — Tests & Documentation
1. Add unit tests for `AppBootstrap` validating behaviour under missing env values, failed service initialisation, and success paths.
2. Update integration tests to use provider overrides instead of global overrides.
3. Document the bootstrap flow in `docs/toolchain.md` (summary) and a new section in `README.md`.
4. Verify no modules reference removed globals or default secrets; run `dart analyze`/`flutter test`.

---
## 3. Deliverables Checklist
- [ ] `AppBootstrap` module with error reporting and dependency wiring.
- [ ] Updated `main.dart` free of global `late` singletons; dependencies provided via Riverpod overrides.
- [ ] `EnvironmentConfig` refactored to avoid embedded secrets and exposed through providers.
- [ ] Logging/analytics/Sentry initialised through bootstrap and consumed via providers.
- [ ] Supabase/Firebase/Adapty setup centralised with graceful failure handling.
- [ ] Root widget adapts to bootstrap state and displays an error/retry UI when needed.
- [ ] Updated documentation and tests confirming the new startup path.
- [ ] Analyzer/tests passing with no references to removed globals or secrets.
