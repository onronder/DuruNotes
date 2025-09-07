# Cross-Device Sync Fix Instructions

## The Problem
Your note created on Device 1 cannot be decrypted on Device 2 because it was encrypted with a different key. This happened because the note was created before we fixed the AMK (Account Master Key) storage format.

## Quick Fix Steps

### Step 1: Run Diagnostics (in Supabase SQL Editor)
```sql
-- Check the problematic note
SELECT id, user_id, created_at FROM notes
WHERE id = 'f9cb5286-28a7-4c8d-8570-78088b420483';

-- Check your user_keys format
SELECT user_id, 
       left(wrapped_key::text, 50) as key_preview,
       CASE 
         WHEN wrapped_key::text ~ '^[A-Za-z0-9+/]+=*$' THEN 'Base64 (GOOD)'
         ELSE 'OLD FORMAT (NEEDS FIX)'
       END as format
FROM user_keys
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';
```

### Step 2: Delete the Problematic Note
Since this note was encrypted with the wrong key, the easiest fix is to delete it:

```sql
DELETE FROM notes 
WHERE id = 'f9cb5286-28a7-4c8d-8570-78088b420483';
```

### Step 3: Ensure Both Devices Have Same AMK
On **BOTH** devices:

1. **Sign out** completely
2. **Sign in** again
3. Enter your passphrase when prompted
4. This ensures both devices download and use the same AMK

### Step 4: Test Sync
1. **On Device 1**: Create a new test note "Test from Device 1"
2. **On Device 2**: Pull to refresh
3. The note should appear and be readable

## Alternative: Complete Reset (if above doesn't work)

If you still have issues, do a complete reset:

### On Supabase:
```sql
-- Delete all encryption keys and notes for fresh start
DELETE FROM user_keys WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';
DELETE FROM notes WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';
```

### On Both Devices:
1. **Delete the app** completely
2. **Reinstall** the app
3. **Sign in** with your account
4. **Set a new passphrase** when prompted (use the same on both devices)
5. Create notes fresh - they will sync properly

## Why This Happened

1. **Device 1** created a note with an old encryption key format
2. We fixed the key storage format (bytea → base64)
3. **Device 2** got the new format but can't decrypt old notes
4. The MAC (Message Authentication Code) fails because the keys don't match

## Going Forward

After following these steps:
- ✅ Both devices will use the same AMK
- ✅ All new notes will sync properly
- ✅ Cross-device encryption will work correctly

## Verification

After the fix, verify everything works:

1. **Device 1**: Create note "Hello from Device 1"
2. **Device 2**: Sync and verify you can read it
3. **Device 2**: Create note "Hello from Device 2"  
4. **Device 1**: Sync and verify you can read it

Both notes should sync and be readable on both devices.
