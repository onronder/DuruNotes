# iOS Black Screen Fix - Testing Guide

## What Was Fixed

### Critical Fix Applied
**File**: `/Users/onronder/duru-notes/ios/Runner/AppDelegate.swift`

**Changes**:
1. ✅ Deferred notification permission request by 500ms (lines 41-56)
2. ✅ Replaced all `print()` with `NSLog()` for early debugging
3. ✅ Moved `registerForRemoteNotifications()` to permission callback
4. ✅ Added comprehensive logging throughout AppDelegate

### Root Cause Identified
The notification permission dialog was appearing BEFORE Flutter completed its first frame render, blocking the main thread and preventing Flutter's rendering pipeline from executing `build()` after `setState()`.

---

## Testing Instructions

### Test 1: Clean Install (MOST IMPORTANT)

**Purpose**: Verify the black screen is resolved on first launch

**Steps**:
1. Delete the app from simulator completely:
   ```bash
   xcrun simctl uninstall booted com.fittechs.durunotes
   ```

2. Clean Flutter and iOS builds:
   ```bash
   flutter clean
   rm -rf ios/build
   rm -rf ios/Pods
   rm -rf ios/Podfile.lock
   ```

3. Reinstall pods and rebuild:
   ```bash
   cd ios && pod install && cd ..
   flutter pub get
   ```

4. Launch in debug mode:
   ```bash
   flutter run --device-id "A597C042-8D8B-4ADC-BAC9-3E73EFD1DCA0"
   ```

5. **EXPECTED BEHAVIOR**:
   - App UI appears immediately (no black screen)
   - Loading indicator shows during bootstrap
   - After ~500ms, notification permission dialog appears
   - App UI visible BEHIND the permission dialog
   - User can see app is working

6. **FAILURE INDICATORS**:
   - Black screen persists
   - Permission dialog appears on black screen
   - App freezes/hangs

### Test 2: Console Output Verification

**Purpose**: Verify NSLog() statements appear in console

**Steps**:
1. Open Console.app on macOS
2. Select your iOS Simulator device
3. Filter for "AppDelegate" or "🔵"
4. Run the app with `flutter run`

5. **EXPECTED OUTPUT**:
   ```
   🔵 [AppDelegate] didFinishLaunchingWithOptions STARTED
   🔵 [AppDelegate] About to configure Firebase...
   ✅ [AppDelegate] Firebase configured successfully
   🔵 [AppDelegate] Setting up notification delegates...
   🔵 [AppDelegate] About to register plugins...
   ✅ [AppDelegate] Plugin registration complete
   🔵 [AppDelegate] About to attach method channels...
   ✅ [AppDelegate] FlutterViewController resolved successfully
   ✅ [AppDelegate] QuickCaptureChannel configured
   ✅ [AppDelegate] ShareExtensionChannel configured
   🔵 [AppDelegate] didFinishLaunchingWithOptions COMPLETED
   [~500ms later]
   🔵 [Notifications] Requesting permission (delayed for Flutter init)
   ```

6. **ALTERNATIVE**: Check flutter run output for NSLog statements
   - Some NSLog output may appear in flutter run console
   - If not, check Console.app

### Test 3: Flutter Rendering Pipeline

**Purpose**: Verify Flutter setState() triggers rebuild

**Steps**:
1. Run the app
2. Check flutter run console for these messages:
   ```
   flutter: [BootstrapHost] BEFORE setState()
   flutter: [BootstrapHost] INSIDE setState() callback
   flutter: [BootstrapHost] AFTER setState()
   flutter: [BootstrapHost] build isBootstrapping=false hasResult=true hasError=false
   flutter: [BootstrapBody] loading=false, hasResult=true, hasError=false
   flutter: [BootstrapBody] -> BootstrapShell warnings=0 failures=0
   ```

3. **EXPECTED**: All these messages appear in sequence
4. **FAILURE**: Messages stop after "AFTER setState()" - indicates render pipeline still blocked

### Test 4: Permission Dialog Timing

**Purpose**: Verify permission dialog appears AFTER UI is visible

**Steps**:
1. Launch app with fresh install (Test 1)
2. Observe timing carefully
3. **EXPECTED SEQUENCE**:
   - T+0ms: App launches
   - T+100ms: White/colored background appears (not black)
   - T+200ms: Loading spinner visible
   - T+500ms: Permission dialog overlays the app
   - App UI still visible behind dialog

4. **FAILURE INDICATORS**:
   - Permission dialog appears immediately on black screen
   - No app UI visible when dialog shows

### Test 5: Performance Baseline

**Purpose**: Ensure fix doesn't degrade performance

**Steps**:
1. Run app and check Console.app for timing logs
2. Note the time between:
   - "didFinishLaunchingWithOptions STARTED"
   - "didFinishLaunchingWithOptions COMPLETED"

3. **EXPECTED**: < 100ms
4. **WARNING**: > 200ms indicates performance issue

---

## Debugging Failed Tests

### Black Screen Persists

**Check**:
1. Open Console.app and filter for "AppDelegate"
2. Verify NSLog statements appear
3. Check if this log appears:
   ```
   ❌ [AppDelegate] FlutterViewController NOT FOUND anywhere!
   ```

**If FlutterViewController not found**:
- This indicates a deeper Flutter initialization issue
- Check Flutter logs for errors
- Verify Flutter engine is initialized

**Next Steps**:
1. Try increasing delay from 0.5s to 1.0s:
   ```swift
   DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
   ```

2. Check if Firebase is causing issues:
   - Temporarily comment out Firebase initialization
   - Test if app launches

### No NSLog Output

**Check**:
1. Ensure you're checking Console.app, not just flutter run
2. Filter by process name "Runner" or "Duru"
3. Clear filters and search manually

**If still no output**:
- AppDelegate may not be running at all
- Check Info.plist for correct App Delegate class
- Verify @main annotation in AppDelegate.swift

### Permission Dialog Never Appears

**Check**:
1. Look for this log in Console.app:
   ```
   ⚠️ [AppDelegate] Push notifications disabled - Firebase not configured
   ```

2. If Firebase not configured:
   - Verify GoogleService-Info.plist exists
   - Check file is included in Xcode target

**If Firebase configured but no dialog**:
- Check iOS Simulator settings
- Reset all permissions: Device > Erase All Content and Settings

---

## Success Criteria

All of these must pass:

- [ ] App launches without black screen
- [ ] App UI visible immediately (loading spinner or content)
- [ ] NSLog statements appear in Console.app
- [ ] Permission dialog appears ~500ms after launch
- [ ] App UI visible behind permission dialog
- [ ] Flutter build() method called after setState()
- [ ] No main thread blocking during launch
- [ ] Launch time < 500ms total

---

## Rollback Plan

If the fix causes new issues:

1. **Immediate Rollback**:
   ```bash
   git checkout HEAD -- ios/Runner/AppDelegate.swift
   ```

2. **Alternative Fix** - Move to Flutter side:
   - Request permissions from Dart after first frame
   - Use `permission_handler` package
   - Remove all notification code from AppDelegate

3. **Nuclear Option** - Disable notifications temporarily:
   ```swift
   // Comment out entire notification block in AppDelegate
   // if firebaseState.isReady { ... }
   ```

---

## Next Steps After Successful Tests

1. **Physical Device Testing**:
   - Test on actual iPhone (not just simulator)
   - Verify permission dialog behavior
   - Check performance on older devices

2. **Edge Cases**:
   - Test with Firebase disabled
   - Test with no internet connection
   - Test with permissions already granted
   - Test with permissions denied

3. **Performance Profiling**:
   - Use Instruments Time Profiler
   - Check main thread usage during launch
   - Verify no blocking operations

4. **Monitoring**:
   - Add analytics event for permission request
   - Track time between launch and first frame
   - Monitor crash rates in production

---

## Questions to Answer During Testing

1. **How long does the app take to show UI?**
   - Expected: < 300ms
   - Acceptable: < 500ms
   - Concerning: > 1000ms

2. **When does the permission dialog appear?**
   - Expected: After app UI visible
   - Concerning: Before any UI shows

3. **Are all 29 plugins loading successfully?**
   - Check for plugin registration errors
   - Verify method channels work

4. **Is FlutterViewController found immediately?**
   - Check for "NOT FOUND" logs
   - Verify window hierarchy is ready

---

## Contact/Support

If issues persist after applying this fix:

1. Check documentation: `/Users/onronder/duru-notes/MasterImplementation Phases/iOS_BLACK_SCREEN_INVESTIGATION.md`
2. Review complete fix implementation in AppDelegate.swift
3. Enable verbose Flutter logging: `flutter run -v`
4. Capture Console.app output during launch
5. Share logs for further investigation

---

**Last Updated**: November 9, 2025
**Fix Version**: 1.0
**Status**: Ready for testing
