# Encryption Flow Fix - Test Guide

## Issues Fixed

1. **Unlock screen appearing after signup**: Fixed race condition where AMK wasn't being stored with correct user ID
2. **Unlock button not working**: Added proper error handling and retry logic
3. **Passphrase not saved properly**: Fixed user ID consistency during provisioning
4. **Cross-device sync issues**: Improved AMK storage and retrieval logic

## Testing Instructions

### Test 1: New User Signup (Same Device)
1. **Clean start**: Sign out if logged in
2. **Create new account**:
   - Enter email and password
   - Enter and confirm password
   - Enter encryption passphrase (remember this!)
   - Confirm passphrase
   - Click Sign Up
3. **Expected behavior**:
   - Should see "Check your email to confirm your account!" message
   - After email confirmation, should go directly to Notes screen
   - Should NOT see unlock encryption screen
4. **Create a note**:
   - Tap + to create a new note
   - Enter title and content
   - Save the note
   - Verify note appears in list

### Test 2: Sign Out and Sign In (Same Device)
1. **Sign out**: Go to Settings > Sign Out
2. **Sign in** with same credentials
3. **Expected behavior**:
   - Should go directly to Notes screen (AMK cached locally)
   - Should NOT see unlock encryption screen
   - All notes should be visible and decrypted

### Test 3: New Device Login
1. **On a different device** (or after clearing app data):
2. **Sign in** with existing account
3. **Expected behavior**:
   - SHOULD see unlock encryption screen
   - Enter the passphrase you used during signup
   - Click Unlock
   - Should proceed to Notes screen
   - All notes should be visible and decrypted

### Test 4: Wrong Passphrase
1. **On unlock screen**, enter wrong passphrase
2. **Expected behavior**:
   - Should see "Incorrect passphrase" error
   - Should remain on unlock screen
   - Can retry with correct passphrase

### Test 5: Cross-Device Sync
1. **Device A**: Create a note with title "Test Cross-Device"
2. **Device B**: 
   - Sign in with same account
   - Unlock with passphrase
   - Pull to refresh notes list
3. **Expected behavior**:
   - "Test Cross-Device" note should appear
   - Content should be fully decrypted and readable

## Technical Details

### What Changed

1. **AccountKeyService**:
   - `provisionAmkForUser` now accepts optional `userId` parameter
   - Consistent user ID usage for AMK storage/retrieval
   - Better error handling and logging
   - Improved `unlockAmkWithPassphrase` to handle all scenarios

2. **AuthScreen**:
   - Passes explicit user ID during AMK provisioning
   - Ensures AMK is stored with correct user ID after signup

3. **App (AuthWrapper)**:
   - Added retry mechanism for AMK check (handles timing issues)
   - Improved unlock screen with loading states
   - Better error messages

4. **UnlockPassphraseView**:
   - Converted to StatefulWidget for better state management
   - Added loading indicator during unlock
   - Improved error handling
   - Added keyboard submit support

## Troubleshooting

### Still seeing unlock screen after signup?
1. Check console logs for AMK provisioning errors
2. Verify user_keys table exists in Supabase
3. Clear app data and try again

### Unlock button not working?
1. Ensure you're entering the exact passphrase from signup
2. Check for network connectivity
3. Look for error messages in red snackbar

### Notes not syncing across devices?
1. Verify both devices are using same account
2. Check sync mode in Settings (should be Automatic or Manual)
3. Try manual sync (pull to refresh)

## Verification Checklist

- [ ] New user signup goes directly to Notes screen
- [ ] Existing user on same device doesn't see unlock screen
- [ ] Existing user on new device sees unlock screen
- [ ] Unlock with correct passphrase works
- [ ] Unlock with wrong passphrase shows error
- [ ] Notes created on one device appear on another
- [ ] All encrypted content is readable after unlock

## Related Files Modified
- `/lib/services/account_key_service.dart`
- `/lib/ui/auth_screen.dart`
- `/lib/app/app.dart`
