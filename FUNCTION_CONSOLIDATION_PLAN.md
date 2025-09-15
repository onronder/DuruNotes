# Function Consolidation Plan

## Current Duplicate Functions

### Web Clipper Functions (3 versions!)
1. **inbound-web** - HMAC/secret authentication (OLD)
2. **inbound-web-auth** - JWT authentication (HAS ISSUES)
3. **inbound-web-unified** - Combined approach (NEVER DEPLOYED)

### Notification Processors (2 versions!)
1. **process-notification-queue** - Complex with imports (BOOT ERROR)
2. **process-notifications-simple** - Simplified version (WORKING)

### Push Notification Sender
1. **send-push-notification-v1** - Has import issues (BOOT ERROR)

## ✅ RECOMMENDED CONSOLIDATION

### 1. Keep ONE Web Clipper: `inbound-web`
**Why:** It's working and handles both webhooks and Chrome extension
**Action:** 
- Delete `inbound-web-auth` 
- Delete `inbound-web-unified` (never deployed)
- Update `inbound-web` to handle both JWT and secret auth

### 2. Keep ONE Processor: `process-notifications-simple`
**Why:** It's working without boot errors
**Action:**
- Delete `process-notification-queue`
- Rename `process-notifications-simple` to `process-notifications`
- Delete `send-push-notification-v1` (broken, not needed)

### 3. Final Function List (Only 3 functions!)
1. **inbound-web** - Handles ALL incoming data (webhooks, Chrome extension)
2. **process-notifications** - Handles ALL notification processing
3. **email_inbox** - Keep as is (separate concern)

## Migration Steps

### Step 1: Create the consolidated inbound-web
```typescript
// Handles both JWT (Chrome extension) and secret (webhooks)
// Single source of truth for all incoming data
```

### Step 2: Rename process-notifications-simple
```bash
# Just rename the working one
mv process-notifications-simple process-notifications
```

### Step 3: Delete unused functions
```bash
supabase functions delete inbound-web-auth --project-ref jtaedgpxesshdrnbgvjr
supabase functions delete process-notification-queue --project-ref jtaedgpxesshdrnbgvjr
supabase functions delete send-push-notification-v1 --project-ref jtaedgpxesshdrnbgvjr
```

### Step 4: Update all references
- Cron jobs → point to `process-notifications`
- Chrome extension → point to `inbound-web`
- Webhooks → point to `inbound-web`

## Benefits
✅ Single source of truth
✅ No duplicate code
✅ Easier maintenance
✅ Clear purpose for each function
✅ No confusion about which to use
