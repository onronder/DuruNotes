# Environment Configuration Setup

This guide explains how to set up different environments (development, staging, production) for the Duru Notes app.

## Overview

The app supports three environments:
- **Development** (`dev`) - For local development with debug features
- **Staging** (`staging`) - For testing and QA with production-like settings
- **Production** (`prod`) - For live deployment with optimized settings

## Environment Files

Environment-specific configuration is stored in `assets/env/` directory:

- `assets/env/dev.env` - Development configuration
- `assets/env/staging.env` - Staging configuration  
- `assets/env/prod.env` - Production configuration

## Setting Up Your Environment

### 1. Configure Environment Files

Copy the template files and update them with your actual values:

```bash
# The template files are already created with placeholder values
# Update them with your actual Supabase project details
```

#### Development Environment (`assets/env/dev.env`):
```bash
SUPABASE_URL=https://your-dev-project.supabase.co
SUPABASE_ANON_KEY=your_development_anon_key_here
ENVIRONMENT=development
DEBUG_MODE=true
# ... other development settings
```

#### Staging Environment (`assets/env/staging.env`):
```bash
SUPABASE_URL=https://your-staging-project.supabase.co
SUPABASE_ANON_KEY=your_staging_anon_key_here
ENVIRONMENT=staging
DEBUG_MODE=false
# ... other staging settings
```

#### Production Environment (`assets/env/prod.env`):
```bash
SUPABASE_URL=https://your-prod-project.supabase.co
SUPABASE_ANON_KEY=your_production_anon_key_here
ENVIRONMENT=production
DEBUG_MODE=false
# ... other production settings
```

### 2. Running Different Environments

#### Using Flutter Command Line:

```bash
# Development
flutter run --flavor dev --dart-define=FLAVOR=dev

# Staging
flutter run --flavor staging --dart-define=FLAVOR=staging

# Production
flutter run --flavor prod --dart-define=FLAVOR=prod
```

#### Using VS Code:

1. Open the Debug panel (Ctrl+Shift+D / Cmd+Shift+D)
2. Select the desired configuration:
   - "Duru Notes (Development)"
   - "Duru Notes (Staging)"
   - "Duru Notes (Production)"
3. Press F5 or click the play button

#### Building for Different Environments:

```bash
# Development APK
flutter build apk --flavor dev --dart-define=FLAVOR=dev

# Staging APK
flutter build apk --flavor staging --dart-define=FLAVOR=staging

# Production APK
flutter build apk --flavor prod --dart-define=FLAVOR=prod
```

### 3. Environment Configuration Details

#### Available Configuration Options:

| Setting | Description | Dev | Staging | Prod |
|---------|-------------|-----|---------|------|
| `SUPABASE_URL` | Supabase project URL | Dev project | Staging project | Prod project |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | Dev key | Staging key | Prod key |
| `DEBUG_MODE` | Enable debug features | `true` | `false` | `false` |
| `LOG_LEVEL` | Logging verbosity | `debug` | `info` | `error` |
| `ENABLE_ANALYTICS` | Analytics tracking | `false` | `true` | `true` |
| `API_TIMEOUT` | Request timeout (ms) | `30000` | `15000` | `10000` |
| `SESSION_TIMEOUT_MINUTES` | Session duration | `60` | `30` | `15` |

### 4. Security Best Practices

#### Environment File Security:

1. **Never commit real secrets** to version control
2. **Use different Supabase projects** for each environment
3. **Rotate API keys regularly** in staging and production
4. **Limit permissions** of staging/prod API keys

#### .gitignore Configuration:

The `.gitignore` file is configured to prevent accidental commits of:
- Root-level `.env*` files
- API key files
- Signing configurations
- Build artifacts with embedded secrets

#### Template vs Real Configuration:

- **Template files** (`assets/env/*.env`) contain placeholder values and should be committed
- **Real configuration files** with actual secrets should be kept secure and not committed
- **Local override files** (if used) should be in `.gitignore`

### 5. Troubleshooting

#### Common Issues:

1. **"Environment variable not found"**
   - Ensure the environment file exists in `assets/env/`
   - Check that all required variables are defined
   - Verify the file is properly formatted

2. **"Failed to load environment config"**
   - Check file permissions on the environment file
   - Ensure the file is included in `pubspec.yaml` assets
   - Verify the file syntax (no spaces around `=`)

3. **"Invalid environment configuration"**
   - Ensure `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set
   - Check that URLs are valid and accessible
   - Verify API keys are correct

#### Debug Information:

When running in debug mode, the app will print:
- Current environment name
- Configuration summary (without sensitive values)
- Supabase URL (for verification)

### 6. CI/CD Integration

#### GitHub Actions Example:

```yaml
- name: Build Development
  run: flutter build apk --flavor dev --dart-define=FLAVOR=dev
  env:
    SUPABASE_URL: ${{ secrets.DEV_SUPABASE_URL }}
    SUPABASE_ANON_KEY: ${{ secrets.DEV_SUPABASE_ANON_KEY }}

- name: Build Production
  run: flutter build apk --flavor prod --dart-define=FLAVOR=prod
  env:
    SUPABASE_URL: ${{ secrets.PROD_SUPABASE_URL }}
    SUPABASE_ANON_KEY: ${{ secrets.PROD_SUPABASE_ANON_KEY }}
```

#### Environment Variables in CI:

Store secrets as environment variables in your CI/CD system:
- `DEV_SUPABASE_URL` / `DEV_SUPABASE_ANON_KEY`
- `STAGING_SUPABASE_URL` / `STAGING_SUPABASE_ANON_KEY`
- `PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY`

### 7. Next Steps

1. **Set up Supabase projects** for each environment
2. **Configure environment files** with real values
3. **Test each environment** to ensure proper configuration
4. **Set up CI/CD pipelines** for automated builds
5. **Monitor** each environment for issues

---

## Support

For issues with environment configuration:
1. Check this documentation first
2. Verify your environment files are properly formatted
3. Test with the development environment first
4. Check Flutter and Supabase documentation for specific issues
