# 🚨 Complete Sync Fix - Follow These Steps Exactly

## Problem Summary
1. Your notes were encrypted with incompatible keys on different devices
2. Sign out wasn't clearing the AMK, so it never asked for passphrase again
3. The 2 notes in your database can't sync because they use different encryption keys

## ✅ Step-by-Step Fix

### Step 1: Database Cleanup (Do this FIRST)
Run this in your **Supabase SQL Editor**:

```sql
-- Delete all notes (they're encrypted with incompatible keys)
DELETE FROM notes 
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';

-- Delete the user's encryption key to force fresh setup
DELETE FROM user_keys 
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';

-- Verify cleanup
SELECT COUNT(*) as notes_count FROM notes 
WHERE user_id = '49b58975-6446-4482-bed5-5c6b0ec46675';
-- Should return 0
```

### Step 2: Update Your App Code
The fix has been applied to your code. Now you need to:

1. **Stop the Flutter app** (press `q` in terminal)
2. **Run the app again**:
```bash
flutter run
```

### Step 3: Clean Setup on BOTH Devices

#### On Device 1:
1. **Force quit** the app completely (swipe up and remove from memory)
2. **Open** the app
3. **Sign out** (Settings → Sign Out)
4. **Sign in** again
5. **IMPORTANT**: It SHOULD now ask for a passphrase
6. Enter a passphrase (e.g., "MySecurePass123") - **REMEMBER THIS!**
7. Create a test note: "Test from Device 1"

#### On Device 2:
1. **Force quit** the app completely  
2. **Open** the app
3. **Sign out** (Settings → Sign Out)
4. **Sign in** again
5. **IMPORTANT**: It SHOULD now ask for a passphrase
6. Enter the **SAME** passphrase: "MySecurePass123"
7. Sync (pull to refresh or Settings → Manual Sync)
8. You should see "Test from Device 1"
9. Create another note: "Test from Device 2"

#### Back on Device 1:
1. Sync (pull to refresh)
2. You should see "Test from Device 2"

## 🎯 What We Fixed

1. **Sign out now properly clears AMK** - Will ask for passphrase on next login
2. **Database cleaned** - Removed notes with incompatible encryption
3. **Fresh encryption setup** - Both devices will use the same key format

## ✅ Success Checklist

After following these steps:
- [ ] Sign out clears all encryption keys
- [ ] Sign in asks for passphrase
- [ ] Same passphrase works on both devices
- [ ] Notes created on Device 1 appear on Device 2
- [ ] Notes created on Device 2 appear on Device 1
- [ ] All notes are readable on both devices

## 🚫 If It Still Doesn't Work

If you still have issues after following all steps:

1. **Check the app version** - Make sure both devices are running the updated code
2. **Check Supabase** - Verify notes and user_keys tables are empty
3. **Clear app data completely**:
   - iOS: Settings → General → iPhone Storage → Duru Notes → Delete App
   - Reinstall from Xcode/TestFlight
4. **Start fresh** with a new passphrase

## 💡 Important Notes

- **Always use the SAME passphrase** on all devices
- **Sign out properly** using the app's sign out button (not force quit)
- **Wait for sync** to complete before creating notes
- The "Migrate Legacy Encryption" button is for old notes - you don't need it for fresh setup

## 🎉 Once Working

Your cross-device sync is now properly configured! 
- All future notes will sync seamlessly
- Your encryption is working correctly
- You can add as many devices as needed (just use the same passphrase)
