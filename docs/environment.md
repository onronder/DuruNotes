# Environment Configuration Guide

Use this guide to configure environment variables across development, staging, and production. Start by copying `env.example` to the appropriate file (`.env.local`, `.env.staging`, `.env.production`, `.env.docker`, etc.) and fill in the secrets described below.

## Supabase
| Variable | Description |
| --- | --- |
| `SUPABASE_URL` | Base URL for your Supabase project (e.g. `https://xyz.supabase.co`). |
| `SUPABASE_ANON_KEY` | Public anon key used by client applications. |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key with elevated privileges (keep secret). |
| `SUPABASE_PROJECT_REF` | Supabase project reference used by CLI tooling. |
| `API_EXTERNAL_URL` | Public URL for the Supabase API gateway (defaults to localhost for development). |
| `SITE_URL` | URL used in auth emails and redirects. |
| `ADDITIONAL_REDIRECT_URLS` | Comma-separated allow list of additional redirect URLs. |

## Authentication & JWT
| Variable | Description |
| --- | --- |
| `JWT_SECRET` | Symmetric secret for GoTrue JWT generation (minimum 32 bytes). |
| `JWT_EXPIRY` | Token expiry time in seconds. |
| `DISABLE_SIGNUP` | Set to `true` to disable new sign-ups. |
| `ENABLE_EMAIL_SIGNUP` | Enables email/password registration flows. |
| `ENABLE_EMAIL_AUTOCONFIRM` | Automatically confirms emails when `true`. |
| `ENABLE_ANONYMOUS_USERS` | Allows anonymous/guest accounts when `true`. |

## Email & Inbound Processing
| Variable | Description |
| --- | --- |
| `INBOUND_HMAC_SECRET` | HMAC secret used to verify inbound email payloads. |
| `INBOUND_ALLOWED_IPS` | Optional list of IPs allowed to hit inbound endpoints. |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_SENDER_NAME` | SMTP credentials for outbound auth email delivery. |

## Push Notifications
| Variable | Description |
| --- | --- |
| `FCM_SERVICE_ACCOUNT_KEY` | Firebase service account JSON used for push notifications. |

## Monitoring & Analytics
| Variable | Description |
| --- | --- |
| `SENTRY_DSN` | DSN for error reporting (leave empty to disable). |
| `ANALYTICS_ENABLED` | Enables client analytics collection. |
| `CRASH_REPORTING_ENABLED` | Enables crash/error forwarding. |
| `ANALYTICS_SAMPLING_RATE` | Percentage of sessions to capture analytics for (0–1). |
| `SENTRY_TRACES_SAMPLE_RATE` | Sampling rate for Sentry performance traces. |
| `SENTRY_SEND_DEFAULT_PII` | If `true`, allows Sentry to send PII. |

## Runtime Flags
| Variable | Description |
| --- | --- |
| `ENVIRONMENT` | Environment label (`development`, `staging`, `production`). |
| `DEBUG_MODE` | Enables verbose logging when `true`. |
| `LOG_LEVEL` | Structured logging level (`debug`, `info`, `warn`, `error`). |
| `ENABLE_DEBUG_TOOLS` | Toggles in-app developer tooling. |
| `ENABLE_LOCAL_STORAGE_ENCRYPTION` | Encrypts local storage when enabled. |
| `BACKGROUND_SYNC_INTERVAL_MINUTES` | Minutes between background sync jobs. |
| `SESSION_TIMEOUT_MINUTES` | Idle timeout before logout. |

## Docker / Local Supabase Overrides
| Variable | Description |
| --- | --- |
| `POSTGRES_PASSWORD` | Password for the local Supabase Postgres instance. |
| `ANON_KEY`, `SERVICE_ROLE_KEY` | Local equivalents used by Dockerised Supabase. |
| `API_TIMEOUT` | Default API timeout in milliseconds. |
| `MAX_RETRY_ATTEMPTS` | Number of retries for transient API failures. |
| `ENABLE_CACHING`, `CACHE_DURATION_MINUTES` | Toggle and configure server-side caching. |

## Platform Identifiers
| Variable | Description |
| --- | --- |
| `IOS_BUNDLE_IDENTIFIER` | iOS bundle identifier for app builds. |
| `ANDROID_APPLICATION_ID` | Android application ID/package name. |

## Optional Integrations
| Variable | Description |
| --- | --- |
| `SLACK_WEBHOOK_URL` | Webhook for critical alerting. |
| `FORCE_HTTPS` | Enforce HTTPS redirects when `true`. |
| `ENABLE_CERTIFICATE_PINNING` | Enables TLS certificate pinning for clients. |
| `MINIMUM_PASSWORD_STRENGTH` | Password policy (`weak`, `medium`, `strong`). |

### Additional Notes
- Never commit populated `.env` files. Sensitive keys should be stored in your secrets manager and injected during deployment.
- For CI, create environment specific files (e.g. `.env.ci`) and load them via workflow secrets.
- If you add new environment variables, update both `env.example` and this document.
