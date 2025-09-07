# Cross-Device Unlock Fix Guide

## Issues Fixed

### 1. Incorrect Passphrase Error
**Problem**: Even with the correct passphrase, users were getting "Incorrect passphrase" errors.

**Root Cause**: The wrapped encryption key was being stored as postgres bytea but the app expected a different format when decoding.

**Solution**: 
- Changed to store wrapped_key as base64 text instead of bytea
- Added proper format detection and conversion for existing data
- Improved error handling and logging

### 2. Double Unlock Screens
**Problem**: Two unlock screens appeared - one modal dialog and one full screen.

**Root Cause**: Both `auth_screen.dart` and `app.dart` were trying to handle the unlock process.

**Solution**: 
- Removed the modal dialog from `auth_screen.dart`
- Let `app.dart` handle all unlock scenarios consistently
- Single, unified unlock experience

## Immediate Actions Required

### For Existing Users with Broken Passphrases

Since existing wrapped_keys might be in the wrong format, you have two options:

#### Option 1: Run Database Migration (Recommended)
Run this SQL in your Supabase SQL editor:
```sql
-- Check current format
SELECT user_id, 
       CASE 
         WHEN wrapped_key::text LIKE '\x%' THEN 'bytea hex format (needs migration)'
         WHEN wrapped_key::text LIKE '{%' THEN 'JSON array format (needs migration)'
         ELSE 'base64 format (good)'
       END as format_type
FROM user_keys;

-- If you see "needs migration", run the migration script:
-- (Located at supabase/migrations/20250908_fix_wrapped_key_format.sql)
```

#### Option 2: Reset User Encryption
If migration doesn't work, reset the user's encryption:
```sql
-- Delete the user's wrapped_key to force re-provisioning
DELETE FROM user_keys WHERE user_id = 'YOUR_USER_ID';
```
Then sign in again and enter a new passphrase when prompted.

## Testing Steps

### Step 1: Clean Start on Device 1
1. **Sign out** completely
2. **Clear app data** (iOS: Delete and reinstall app)
3. **Create a new test account**:
   - Email: test@example.com
   - Password: TestPass123!
   - Passphrase: MySecurePass123
4. **Verify**: Should go directly to Notes screen (no unlock prompt)
5. **Create a test note**: "Test Note from Device 1"

### Step 2: Sign In on Device 2
1. **Install app** on second device
2. **Sign in** with same test account
3. **Expected**: See ONE unlock screen (not two)
4. **Enter passphrase**: MySecurePass123
5. **Verify**: 
   - Unlock succeeds
   - Can see "Test Note from Device 1"
   - Content is fully decrypted

### Step 3: Verify Fix
1. **Sign out** on Device 2
2. **Sign in again** on Device 2
3. **Expected**: Go directly to Notes (AMK cached)
4. **Create note** on Device 2: "Test Note from Device 2"
5. **On Device 1**: Pull to refresh, verify new note appears

## Troubleshooting

### Still Getting "Incorrect Passphrase"?

1. **Check wrapped_key format in database**:
```sql
SELECT user_id, 
       length(wrapped_key) as key_length,
       left(wrapped_key::text, 50) as key_preview
FROM user_keys 
WHERE user_id = 'YOUR_USER_ID';
```

If key_preview starts with `\x` or `{`, the format is wrong.

2. **Force re-provisioning**:
```sql
DELETE FROM user_keys WHERE user_id = 'YOUR_USER_ID';
```

3. **Check logs** for error details:
- Look for "AMK unlock" or "Failed to unwrap AMK" messages
- Check if wrapped_key type shows as String vs List

### Double Unlock Screens Still Appearing?

This should be fixed, but if it happens:
1. Ensure you're running the latest code
2. Check that `auth_screen.dart` no longer has `_promptPassphrase` method
3. Verify only `app.dart` shows `UnlockPassphraseView`

## Technical Details

### What Changed

1. **Wrapped Key Storage** (`account_key_service.dart`):
   - Now stores as: `base64Encode(wrapped)` instead of raw bytes
   - Handles legacy formats for backward compatibility
   - Better error messages and logging

2. **Unlock Flow** (`auth_screen.dart`):
   - Removed duplicate passphrase prompt
   - Simplified sign-in flow

3. **Database Migration**:
   - Converts bytea to base64 text
   - Preserves existing data

### Format Examples

**Old Format (Broken)**:
```
\x5b3132332c33342c3131302c... (postgres bytea hex)
```

**New Format (Working)**:
```
eyJuIjoiYmFzZTY0bm9uY2U... (base64 string)
```

## Verification Checklist

- [ ] No double unlock screens
- [ ] Correct passphrase works on first try
- [ ] Cross-device unlock works
- [ ] Notes sync properly between devices
- [ ] Sign out/in on same device doesn't show unlock
- [ ] New users don't see unlock after signup

## Next Steps

After testing, if everything works:
1. Deploy to production
2. Run migration on production database
3. Notify existing users to re-enter passphrase if needed
