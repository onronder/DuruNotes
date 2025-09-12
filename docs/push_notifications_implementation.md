# Push Notifications Implementation - DuruNotes

## Overview
This document describes the complete implementation of push notifications for DuruNotes using Firebase Cloud Messaging (FCM) and Supabase for token storage.

## Architecture

### Components Implemented

1. **PushNotificationService** (`lib/services/push_notification_service.dart`)
   - Manages FCM token registration and refresh
   - Handles permission requests (iOS and Android 13+)
   - Syncs tokens with Supabase backend
   - Generates unique device IDs for tracking

2. **Database Schema** (`supabase/migrations/20240912_user_devices_push_tokens.sql`)
   - `user_devices` table for storing FCM tokens
   - RPC functions for secure token upsert
   - Row-Level Security (RLS) policies
   - Maintenance functions for cleanup

3. **Integration Points**
   - **Authentication Flow**: Token registration on login
   - **App Initialization**: Firebase setup in main.dart
   - **Provider System**: Service registered in providers.dart

## Setup Requirements

### Firebase Configuration

#### Android
1. Add `google-services.json` to `android/app/`
2. Obtain from Firebase Console > Project Settings > Android app

#### iOS
1. Add `GoogleService-Info.plist` to `ios/Runner/`
2. Enable Push Notifications capability in Xcode
3. Configure APNs authentication key in Firebase Console
4. Follow instructions in `ios/FirebaseConfiguration.md`

### Permissions

#### Android
- `POST_NOTIFICATIONS` permission already added in AndroidManifest.xml
- Runtime permission request handled for Android 13+

#### iOS
- Permission request automatically triggered on first app launch
- Users prompted with system dialog for notification permission

## Features Implemented

### Token Management
- ✅ Automatic token generation on login
- ✅ Token refresh handling with stream listener
- ✅ Secure storage in Supabase with user association
- ✅ Device-specific tracking (one token per device per user)
- ✅ Platform and app version metadata storage

### Security
- ✅ Row-Level Security (RLS) on user_devices table
- ✅ Users can only view/manage their own device tokens
- ✅ Secure RPC function using auth.uid() for user association
- ✅ No client-side user ID manipulation possible

### Database Operations
- ✅ Upsert logic prevents duplicate device entries
- ✅ Automatic timestamp updates on token refresh
- ✅ Cleanup function for stale tokens (90+ days old)
- ✅ Server-side functions for notification delivery (future use)

## Testing Checklist

### Permission Flow
- [ ] iOS: System permission dialog appears on first launch
- [ ] Android 13+: Runtime permission request works
- [ ] Permission denial handled gracefully
- [ ] App continues to function without notifications if denied

### Token Registration
- [ ] Token successfully sent to Supabase after login
- [ ] Verify token appears in user_devices table
- [ ] Correct user_id, platform, and app_version stored
- [ ] No token sync when user is logged out

### Token Refresh
- [ ] Token updates automatically on refresh events
- [ ] Updated_at timestamp changes on refresh
- [ ] Same device record updated (not duplicated)

### Multiple Devices
- [ ] Different devices create separate records
- [ ] Same user can have multiple device tokens
- [ ] Each device maintains its own unique token

## Database Queries

### View User Devices
```sql
-- View all devices for a specific user
SELECT * FROM user_devices 
WHERE user_id = 'YOUR_USER_ID'
ORDER BY updated_at DESC;
```

### Clean Up Stale Tokens
```sql
-- Remove tokens older than 90 days
SELECT cleanup_stale_device_tokens(90);
```

### Get Active Tokens for Notification
```sql
-- Server-side function to get all tokens for a user
SELECT * FROM get_user_device_tokens('USER_ID');
```

## Next Steps

### Immediate Actions
1. Add Firebase configuration files (google-services.json, GoogleService-Info.plist)
2. Configure APNs in Firebase Console for iOS
3. Test on physical devices (push notifications don't work in simulators)

### Future Enhancements (Prompts H-J)
1. **Message Handling**: Implement foreground/background message handlers
2. **Notification Display**: Create notification UI and actions
3. **Deep Linking**: Navigate to specific notes from notifications
4. **Rich Notifications**: Add images, buttons, and custom layouts
5. **Notification Categories**: Different types (reminders, shares, updates)
6. **Analytics**: Track notification delivery and engagement

## Troubleshooting

### Common Issues

1. **No Token Generated**
   - Ensure Firebase is initialized before requesting token
   - Check internet connectivity
   - Verify Firebase configuration files are present

2. **iOS Token Issues**
   - APNs token must be available before FCM token
   - Physical device required (not simulator)
   - Valid provisioning profile needed

3. **Permission Denied**
   - App handles gracefully without crashes
   - User can enable permissions in system settings
   - Consider implementing permission priming UI

4. **Token Not Syncing**
   - Verify user is authenticated
   - Check Supabase connection
   - Review RLS policies on user_devices table

## Security Considerations

1. **Token Privacy**: FCM tokens are sensitive and stored securely
2. **User Association**: Tokens always tied to authenticated user via auth.uid()
3. **RLS Protection**: Users cannot access other users' tokens
4. **Cleanup**: Old tokens removed to maintain database hygiene
5. **Logout Handling**: Consider removing token on explicit logout

## Performance Notes

- Token registration happens asynchronously to not block UI
- Failure to register token doesn't prevent app usage
- Token refresh listener efficiently handles updates
- Database indexes optimize token lookups

## Dependencies Added

```yaml
firebase_core: ^3.8.0
firebase_messaging: ^15.2.0
```

## Files Modified

1. `pubspec.yaml` - Added Firebase dependencies
2. `lib/main.dart` - Firebase initialization
3. `lib/services/push_notification_service.dart` - New service
4. `lib/providers.dart` - Service provider registration
5. `lib/ui/auth_screen.dart` - Token registration on login
6. `lib/app/app.dart` - Token registration for existing sessions
7. `supabase/migrations/20240912_user_devices_push_tokens.sql` - Database schema

## Conclusion

The push notification infrastructure is now fully implemented and ready for message delivery features. The system is secure, scalable, and handles edge cases like token refresh and multiple devices per user. The foundation is set for rich notification experiences in future updates.
