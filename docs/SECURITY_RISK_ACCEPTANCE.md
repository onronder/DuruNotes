# Security Risk Acceptance

Date: 2026-01-05T10:43:30Z

Context:
- App is distributed via TestFlight only (not public production).
- CI writes environment files to `assets/env/*.env` for builds.
- `sentry.properties` is used for local tooling.

Accepted risks:
- Existing values in `assets/env/dev.env`, `assets/env/staging.env`, and `assets/env/prod.env` are retained (no rotation at this time).
- `sentry.properties` remains present locally.

Controls in place:
- Secrets are removed from VCS and ignored via `.gitignore`.
- `assets/env/example.env` remains tracked for reference only.

Review:
- Revisit before public production launch or if credentials need rotation.
