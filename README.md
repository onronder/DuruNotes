# Duru Notes

Duru Notes is a Flutter application that syncs with Supabase to deliver advanced note taking, reminders, and automation. This repository has been trimmed to focus on the current production toolchain.

## Supported Toolchain
- **Flutter**: 3.22.2 (stable channel)
- **Dart**: >= 3.4.0 < 4.0.0
- **Supabase CLI**: optional (for local self-hosted stack)
- **Docker**: required for running the full Supabase stack locally

See [`docs/toolchain.md`](docs/toolchain.md) for the complete setup checklist.

## Getting Started
1. Install the prerequisites listed above.
2. Copy the environment template and populate secrets:
   ```bash
   cp env.example .env
   # edit .env with your project specific values
   ```
3. (Optional) Spin up the local Supabase stack:
   ```bash
   make up          # or `make web` to include Flutter web
   ```
4. Fetch packages and run the app:
   ```bash
   flutter pub get
   flutter run
   ```

## Bootstrap Overview
- `AppBootstrap` orchestrates environment loading, logger initialisation, Firebase/Supabase setup, feature flags, analytics, and optional Adapty activation.
- Results are injected into Riverpod through providers in `lib/core/bootstrap/bootstrap_providers.dart` (e.g. `environmentConfigProvider`, `bootstrapLoggerProvider`, `navigatorKeyProvider`).
- `main.dart` shows a loading indicator while bootstrap runs, launches the app when successful, and displays a retryable failure screen if critical stages (environment, Supabase, Firebase) cannot complete.

## Quality Gates
- Ensure formatting and tests pass before committing:
  ```bash
  scripts/verify_task_system.sh
  ```
- CI runs `dart format`, `flutter analyze`, and `flutter test` through GitHub Actions (`.github/workflows/ci.yml`).

## Project Documentation
- [`docs/environment.md`](docs/environment.md) — Environment variable reference.
- [`docs/toolchain.md`](docs/toolchain.md) — Toolchain requirements, CLI usage, and automation notes.
- [`docs/production_cleanup_plan.md`](docs/production_cleanup_plan.md) — High-level cleanup roadmap.

## Local Docker Shortcuts
Common commands are exposed through the `Makefile` (powered by `docker compose`):
- `make up` — start Supabase core services.
- `make down` — stop services.
- `make logs` — tail logs.
- `make clean` — stop and remove volumes (destructive).

Refer to the help target (`make help`) for the full list.

## Contributing
1. Create a feature branch.
2. Run the verification script.
3. Submit a pull request targeting `develop` or `main`.

Please keep new automation consistent with the tooling documented in `docs/toolchain.md`.
