# GitHub Actions Secrets Audit Checklist

## How to Access GitHub Secrets

1. Go to your repository: `https://github.com/onronder/DuruNotes`
2. Navigate to: **Settings** → **Secrets and variables** → **Actions**
3. You'll see a list of "Repository secrets"

## Required Secrets Checklist

### ✅ iOS Deployment Secrets (8 Required)

| Secret Name | Used In | Description | How to Verify |
|-------------|---------|-------------|---------------|
| `ENV_PROD` | deploy-production.yml:156 | Production environment variables (assets/env/prod.env content) | Should contain Supabase URLs, API keys, etc. |
| `GOOGLE_SERVICE_INFO_PLIST` | deploy-production.yml:157 | Firebase iOS configuration (GoogleService-Info.plist content) | Should be valid XML plist format |
| `IOS_CERTIFICATES_P12` | deploy-production.yml:167 | Base64-encoded P12 certificate for code signing | Base64 string, ~8000+ characters |
| `IOS_CERTIFICATES_PASSWORD` | deploy-production.yml:168 | Password for the P12 certificate | String password you set when exporting cert |
| `IOS_PROVISIONING_PROFILE_BASE64` | deploy-production.yml:173 | Base64-encoded provisioning profile (.mobileprovision) | Base64 string, ~4000+ characters |
| `APPSTORE_ISSUER_ID` | deploy-production.yml:184 | App Store Connect API issuer ID (UUID format) | Format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `APPSTORE_API_KEY_ID` | deploy-production.yml:185 | App Store Connect API key ID | 10-character alphanumeric (e.g., `AB12CD34EF`) |
| `APPSTORE_API_PRIVATE_KEY` | deploy-production.yml:186 | App Store Connect API private key (.p8 file content) | Begins with `-----BEGIN PRIVATE KEY-----` |

### ✅ Android Deployment Secrets (6 Required)

| Secret Name | Used In | Description | How to Verify |
|-------------|---------|-------------|---------------|
| `GOOGLE_SERVICES_JSON` | deploy-production.yml:93 | Firebase Android configuration (google-services.json content) | Valid JSON with `project_info`, `client` fields |
| `ANDROID_KEYSTORE_BASE64` | deploy-production.yml:97 | Base64-encoded Android keystore (.jks file) | Base64 string, varies by keystore size |
| `ANDROID_KEYSTORE_PASSWORD` | deploy-production.yml:102 | Keystore password | String password for the keystore |
| `ANDROID_KEY_PASSWORD` | deploy-production.yml:103 | Key password (may be same as keystore password) | String password for the signing key |
| `ANDROID_KEY_ALIAS` | deploy-production.yml:104 | Key alias name | String identifier (e.g., `upload`, `release`) |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | deploy-production.yml:114 | Google Play Console service account credentials | Valid JSON with `type`, `project_id`, `private_key` |

### ⚠️ Optional Secrets (Recommended but not blocking)

| Secret Name | Used In | Description | Impact if Missing |
|-------------|---------|-------------|-------------------|
| `SLACK_WEBHOOK_URL` | deploy-production.yml:267 | Slack webhook for deployment notifications | No Slack notifications |
| `SENTRY_AUTH_TOKEN` | deploy-production.yml:282 | Sentry API token for release tracking | No Sentry release tracking |
| `CODECOV_TOKEN` | ci-build-test.yml | Code coverage reporting | No coverage reports on Codecov |

## Verification Steps

### Step 1: Count the Secrets
Run this checklist in GitHub Settings → Secrets and variables → Actions:

**iOS (8 secrets):**
- [ ] ENV_PROD
- [ ] GOOGLE_SERVICE_INFO_PLIST
- [ ] IOS_CERTIFICATES_P12
- [ ] IOS_CERTIFICATES_PASSWORD
- [ ] IOS_PROVISIONING_PROFILE_BASE64
- [ ] APPSTORE_ISSUER_ID
- [ ] APPSTORE_API_KEY_ID
- [ ] APPSTORE_API_PRIVATE_KEY

**Android (6 secrets):**
- [ ] GOOGLE_SERVICES_JSON
- [ ] ANDROID_KEYSTORE_BASE64
- [ ] ANDROID_KEYSTORE_PASSWORD
- [ ] ANDROID_KEY_PASSWORD
- [ ] ANDROID_KEY_ALIAS
- [ ] GOOGLE_PLAY_SERVICE_ACCOUNT_JSON

**Optional (3 secrets):**
- [ ] SLACK_WEBHOOK_URL
- [ ] SENTRY_AUTH_TOKEN
- [ ] CODECOV_TOKEN

### Step 2: Verify Secret Values (Without Exposing Them)

You cannot view secret values in GitHub, but you can:

1. **Check if secret exists**: Listed in the secrets page
2. **Check when last updated**: Shows "Updated X days ago"
3. **Test in CI**: Run a test workflow that validates format

### Step 3: Test Secret Validation (Safe Method)

Create a temporary workflow file to test secrets (doesn't expose values):

```yaml
# .github/workflows/validate-secrets.yml
name: Validate Secrets
on: workflow_dispatch

jobs:
  validate-ios:
    runs-on: ubuntu-latest
    steps:
      - name: Check iOS Secrets Exist
        run: |
          [[ -n "${{ secrets.ENV_PROD }}" ]] && echo "✅ ENV_PROD exists" || echo "❌ ENV_PROD missing"
          [[ -n "${{ secrets.GOOGLE_SERVICE_INFO_PLIST }}" ]] && echo "✅ GOOGLE_SERVICE_INFO_PLIST exists" || echo "❌ GOOGLE_SERVICE_INFO_PLIST missing"
          [[ -n "${{ secrets.IOS_CERTIFICATES_P12 }}" ]] && echo "✅ IOS_CERTIFICATES_P12 exists" || echo "❌ IOS_CERTIFICATES_P12 missing"
          [[ -n "${{ secrets.IOS_CERTIFICATES_PASSWORD }}" ]] && echo "✅ IOS_CERTIFICATES_PASSWORD exists" || echo "❌ IOS_CERTIFICATES_PASSWORD missing"
          [[ -n "${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}" ]] && echo "✅ IOS_PROVISIONING_PROFILE_BASE64 exists" || echo "❌ IOS_PROVISIONING_PROFILE_BASE64 missing"
          [[ -n "${{ secrets.APPSTORE_ISSUER_ID }}" ]] && echo "✅ APPSTORE_ISSUER_ID exists" || echo "❌ APPSTORE_ISSUER_ID missing"
          [[ -n "${{ secrets.APPSTORE_API_KEY_ID }}" ]] && echo "✅ APPSTORE_API_KEY_ID exists" || echo "❌ APPSTORE_API_KEY_ID missing"
          [[ -n "${{ secrets.APPSTORE_API_PRIVATE_KEY }}" ]] && echo "✅ APPSTORE_API_PRIVATE_KEY exists" || echo "❌ APPSTORE_API_PRIVATE_KEY missing"

  validate-android:
    runs-on: ubuntu-latest
    steps:
      - name: Check Android Secrets Exist
        run: |
          [[ -n "${{ secrets.GOOGLE_SERVICES_JSON }}" ]] && echo "✅ GOOGLE_SERVICES_JSON exists" || echo "❌ GOOGLE_SERVICES_JSON missing"
          [[ -n "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" ]] && echo "✅ ANDROID_KEYSTORE_BASE64 exists" || echo "❌ ANDROID_KEYSTORE_BASE64 missing"
          [[ -n "${{ secrets.ANDROID_KEYSTORE_PASSWORD }}" ]] && echo "✅ ANDROID_KEYSTORE_PASSWORD exists" || echo "❌ ANDROID_KEYSTORE_PASSWORD missing"
          [[ -n "${{ secrets.ANDROID_KEY_PASSWORD }}" ]] && echo "✅ ANDROID_KEY_PASSWORD exists" || echo "❌ ANDROID_KEY_PASSWORD missing"
          [[ -n "${{ secrets.ANDROID_KEY_ALIAS }}" ]] && echo "✅ ANDROID_KEY_ALIAS exists" || echo "❌ ANDROID_KEY_ALIAS missing"
          [[ -n "${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}" ]] && echo "✅ GOOGLE_PLAY_SERVICE_ACCOUNT_JSON exists" || echo "❌ GOOGLE_PLAY_SERVICE_ACCOUNT_JSON missing"
```

## How to Add Missing Secrets

### In GitHub UI:
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Enter **Name** and **Value**
4. Click **"Add secret"**

### For Base64-Encoded Files:

**iOS Certificate (.p12):**
```bash
base64 -i path/to/certificate.p12 | pbcopy
# Then paste into GitHub secret
```

**iOS Provisioning Profile (.mobileprovision):**
```bash
base64 -i path/to/profile.mobileprovision | pbcopy
# Then paste into GitHub secret
```

**Android Keystore (.jks):**
```bash
base64 -i path/to/keystore.jks | pbcopy
# Then paste into GitHub secret
```

### For File Contents (JSON, XML, .env):

**GoogleService-Info.plist (iOS):**
```bash
cat ios/Runner/GoogleService-Info.plist | pbcopy
# Then paste into GitHub secret
```

**google-services.json (Android):**
```bash
cat android/app/google-services.json | pbcopy
# Then paste into GitHub secret
```

**ENV_PROD (prod.env):**
```bash
cat assets/env/prod.env | pbcopy
# Then paste into GitHub secret
```

## App Store Connect API Setup

If you don't have App Store Connect API credentials:

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to **Users and Access** → **Integrations** → **App Store Connect API**
3. Click **"+"** to generate a new key
4. Select **Access**: "App Manager" or "Admin"
5. Download the `.p8` file (you can only download once!)
6. Copy the **Issuer ID** (UUID format)
7. Copy the **Key ID** (10 characters)

Store:
- `APPSTORE_ISSUER_ID` = Issuer ID
- `APPSTORE_API_KEY_ID` = Key ID
- `APPSTORE_API_PRIVATE_KEY` = Contents of the .p8 file

## Google Play Service Account Setup

If you don't have Google Play service account:

1. Go to [Google Play Console](https://play.google.com/console/)
2. Navigate to **Setup** → **API access**
3. Click **"Create new service account"**
4. Follow the link to Google Cloud Console
5. Create service account with **"Service Account User"** role
6. Create a JSON key for the service account
7. Grant **"Release manager"** permission in Play Console

Store the entire JSON file contents in `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.

## Critical Deployment Blockers

Before merging to main and triggering deployments:

1. **MUST HAVE**: All 8 iOS secrets OR disable iOS deployment
2. **MUST HAVE**: All 6 Android secrets OR disable Android deployment
3. **RECOMMENDED**: Update `ios/ExportOptions.plist` placeholders (see IOS_CODE_SIGNING_GUIDE.md)

## Audit Status

After completing your audit, update this section:

- **Last Audited**: [DATE]
- **iOS Secrets**: [X/8] present
- **Android Secrets**: [X/6] present
- **Optional Secrets**: [X/3] present
- **Deployment Ready**: ✅ Yes / ❌ No
- **Blockers**: [List any missing critical secrets]

## Next Steps

1. Complete the checklist above
2. Add any missing secrets to GitHub
3. Run the validation workflow to confirm
4. Update ExportOptions.plist if needed
5. Test a deployment to a non-production environment first
