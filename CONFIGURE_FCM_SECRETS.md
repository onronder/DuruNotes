# Configure FCM Secrets for Push Notifications

## ⚠️ Important: FCM API Changes

Google has deprecated the Legacy FCM API (which used Server Keys) in favor of the **FCM HTTP v1 API** that uses OAuth2 with Service Accounts. Your project shows the Legacy API is disabled, which is why you can't find the Server Key.

**Good news:** I've already updated your system to use the modern FCM v1 API!

## Steps to Configure FCM Credentials:

### 1. Get FCM Service Account Key (Required)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **durunotes**
3. Navigate to: **Project Settings** (gear icon) → **Service Accounts**
4. Click **"Generate new private key"**
5. A JSON file will download - this contains your service account credentials
6. Open the JSON file and copy its entire contents

### 2. Set the Service Account Key in Supabase

Format the JSON as a single line and set it as a secret:

```bash
# Option 1: If you have the JSON file locally
supabase secrets set FCM_SERVICE_ACCOUNT_KEY="$(cat ~/Downloads/durunotes-*.json | jq -c .)"

# Option 2: Manually paste the JSON (ensure it's on one line)
supabase secrets set FCM_SERVICE_ACCOUNT_KEY='{"type":"service_account","project_id":"durunotes","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"...","client_id":"...","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"..."}'
```

### 4. Set Webhook Secret

Generate and set a webhook secret for email/web clipper authentication:

```bash
# Generate a random secret
openssl rand -hex 32

# Set it in Supabase (use the generated value)
supabase secrets set INBOUND_PARSE_SECRET="YOUR_GENERATED_SECRET"
```

### 5. Verify Secrets Are Set

Check that your secrets are configured:

```bash
supabase secrets list
```

You should see:
- FCM_SERVER_KEY
- INBOUND_PARSE_SECRET
- (Optional) FCM_SERVICE_ACCOUNT_KEY

## Testing the Setup

After setting the secrets, test the notification system:

```bash
# Test the push notification function
curl -X POST https://jtaedgpxesshdrnbgvjr.supabase.co/functions/v1/send-push-notification \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"batch_size": 10}'
```

## Need Help?

1. **FCM Server Key Not Found?**
   - Make sure Cloud Messaging API (Legacy) is enabled in Firebase Console
   - You might need to enable it first if it shows as disabled

2. **Authentication Issues?**
   - Ensure the FCM_SERVER_KEY matches exactly from Firebase Console
   - Check that the project ID in google-services.json matches Firebase project

3. **Test Notifications Not Working?**
   - Ensure a device is registered (run the app and login)
   - Check user_devices table has entries
   - Review Edge Function logs in Supabase Dashboard

## Your Firebase Project Info

Based on your configuration:
- **Project ID**: durunotes
- **Project Number**: 259019439896
- **Package Name**: com.fittechs.duruNotesApp

Use these values when configuring Firebase Console settings.
secre