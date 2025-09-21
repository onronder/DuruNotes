# Toolchain & Automation Guide

This document defines the supported toolchain and automation workflows for the Duru Notes repository.

## Supported Versions
| Component | Version |
| --- | --- |
| Flutter | 3.22.2 (stable) |
| Dart | >= 3.4.0 < 4.0.0 |
| Supabase CLI | 1.172.5 or newer |
| Docker | 24.x or newer |

Install Flutter through [fvm](https://fvm.app/) or the official SDK to guarantee version alignment. The GitHub Actions workflow (`.github/workflows/ci.yml`) uses the same Flutter release.

## Required CLI Tools
- **Flutter/Dart SDK** – builds, analysis, formatting, testing.
- **Supabase CLI** – optional; used for local migrations and edge function deployments.
- **Docker & Docker Compose plugin** – orchestrates the local Supabase stack (`make up`).

Optional tooling: Firebase CLI (push notifications), Xcode/Android Studio for platform builds.

## Local Development Workflow
1. Check out the repo and install Flutter 3.22.2.
2. Copy the environment template: `cp env.example .env` and populate secrets (see `docs/environment.md`).
3. Install dependencies with `flutter pub get`.
4. (Optional) Start the Supabase stack: `make up`.
5. Run linting and tests:
   ```bash
   dart format --set-exit-if-changed .
   flutter analyze
   flutter test
   ```
   Or use `scripts/verify_task_system.sh` to run the same checks.

## Automation & CI
- **CI Pipeline** – GitHub Actions workflow `ci.yml` runs format, analyze, and tests on every push/PR.
- **Local Verification** – `scripts/verify_task_system.sh` mirrors CI checks.
- **Docker Orchestration** – the `Makefile` wraps `docker compose` commands for starting/stopping Supabase services.

## Application Bootstrap Flow
The Flutter entry-point delegates startup to `AppBootstrap` (`lib/core/bootstrap/app_bootstrap.dart`). The sequence is:

1. Load environment variables via `EnvironmentConfigLoader`. Missing Supabase credentials trigger a critical failure and surface warnings without crashing the app.
2. Initialise logging (`LoggerFactory`), Android platform optimisations, Sentry (if DSN provided), Firebase, and Supabase. Each stage emits a `BootstrapFailure` when it cannot complete.
3. Hydrate feature flags, configure analytics through `AnalyticsFactory`, and optionally activate Adapty if a public API key is present.

Bootstrap results are injected into Riverpod through overrides defined in `lib/core/bootstrap/bootstrap_providers.dart`. Key providers include:

- `bootstrapResultProvider` – exposes the immutable `BootstrapResult` for downstream consumers.
- `environmentConfigProvider`, `bootstrapLoggerProvider`, `bootstrapAnalyticsProvider`, and `navigatorKeyProvider` – convenience providers derived from the result.

`main.dart` renders a loading screen while bootstrap runs, then chooses between:

- `BootstrapShell` – the standard app (`App`) wrapped with `ErrorBoundary` and `SentryAssetBundle`.
- `BootstrapFailureApp` – a retry-capable fallback UI that lists critical failures when bootstrap cannot finish.

Tests that use these providers should override `bootstrapResultProvider` and `navigatorKeyProvider` with context-specific values.

### Removed Legacy Scripts
Historic deployment/migration scripts (`deploy_edge_functions.sh`, `deploy_quick_capture_function.sh`, etc.) have been removed. Supabase deployments should be handled with the Supabase CLI and documented runbooks.

## Updating Dependencies
- Use `flutter pub upgrade --major-versions` when updating dependencies.
- Regenerate `pubspec.lock` and ensure `dart format`, `flutter analyze`, and `flutter test` pass.
- Bump Flutter/Dart versions only after confirming compatibility in CI.

## Policy
- Do not commit populated `.env` files or generated artefacts (`.flutter-plugins-dependencies`, `node_modules`, etc.).
- Keep new scripts small, cross-platform, and documented in `scripts/README.md`.
- Update this document whenever the supported toolchain changes.
