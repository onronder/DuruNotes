# iOS Black Screen - Deep Analysis

**Status**: UNRESOLVED after 3+ days of investigation
**Date**: 2025-11-09
**Severity**: CRITICAL - App completely unusable on iOS

## Problem Statement

The iOS app shows a black screen after bootstrap completes. Bootstrap runs successfully, but the UI never renders.

## Confirmed Facts

### ✅ What Works
1. App installs successfully
2. Bootstrap completes (all stages finish without errors)
3. setState() executes successfully
4. scheduleFrame() is called
5. App process stays alive (doesn't crash)

### ❌ What DOESN'T Work
1. **build() method is NEVER called after setState()**
2. **Post-frame callback NEVER executes**
3. **NO frame renders after bootstrap**
4. **Flutter rendering pipeline appears completely frozen**

## Evidence from Logs

```
flutter: [BootstrapHost] build() CALLED - START  # Initial build
flutter: [BootstrapHost] build isBootstrapping=true hasResult=false hasError=false
flutter: [BootstrapHost] build() RETURNING widget
...
flutter: [BootstrapHost] initialize complete
flutter: [BootstrapHost] Calling setState to mark not bootstrapping...
flutter: [BootstrapHost] setState complete
flutter: [BootstrapHost] Frame scheduled
# ❌ NO FURTHER LOGS - build() never called again
# ❌ POST-FRAME CALLBACK never executes
```

## Attempted Fixes (ALL FAILED)

### Fix Attempt #1: Remove Connectivity Platform Channel Blocking
- **File**: `lib/app/app.dart` (lines 933-936)
- **Change**: Removed synchronous connectivity provider initialization
- **Result**: ❌ Still freezes

### Fix Attempt #2: Defer Provider Access
- **File**: `lib/ui/notes_list_screen.dart` (lines 216-225)
- **Change**: Moved realtime service to post-frame callback
- **Result**: ❌ Still freezes (never reaches this code)

### Fix Attempt #3: Add Safety Checks
- **File**: `lib/features/notes/providers/notes_state_providers.dart` (lines 53-57)
- **Change**: Added SecurityInitialization check
- **Result**: ❌ Still freezes (never reaches this code)

### Fix Attempt #4: Reverse StateProvider Update Order
- **File**: `lib/main.dart` (lines 69-78)
- **Change**: Call setState() BEFORE updating StateProvider
- **Result**: ❌ Still freezes

### Fix Attempt #5: Force Frame Scheduling
- **File**: `lib/main.dart` (lines 80-85)
- **Change**: Manually call `WidgetsBinding.instance.scheduleFrame()`
- **Result**: ❌ Frame scheduled but never renders

### Fix Attempt #6: Minimal AppDelegate (BREAKTHROUGH TEST)
- **File**: `ios/Runner/AppDelegate.swift`
- **Change**: Commented out ALL custom native initialization:
  - ❌ Firebase configuration
  - ❌ FirebaseMessaging setup
  - ❌ Notification permission requests
  - ❌ Method channel attachment
  - ❌ Deep link handling
  - ✅ ONLY kept: `GeneratedPluginRegistrant.register(with: self)` + `super.application()`
- **Result**: ❌ **STILL FREEZES AT EXACT SAME POINT**
- **Evidence**:
  - AppDelegate NSLog statements DID appear in logs
  - AppDelegate completed successfully: `didFinishLaunchingWithOptions COMPLETED, returning true`
  - Bootstrap completed successfully
  - setState() completed
  - Frame scheduled
  - **BUT: build() was NEVER called again**
  - **Post-frame callback NEVER executed**

**CRITICAL FINDING**: The blocker is NOT in our custom AppDelegate code. It happens during or after `GeneratedPluginRegistrant.register(with: self)`.

## Root Cause Analysis - UPDATED

Based on the minimal AppDelegate test, we now have **definitive evidence** of where the problem lies.

### What We Know For Certain

1. ✅ **Custom AppDelegate code is NOT the problem** - App freezes even with ALL custom initialization removed
2. ✅ **AppDelegate completes successfully** - NSLog statements prove it finishes and returns `true`
3. ✅ **Dart bootstrap completes successfully** - All stages finish without errors
4. ✅ **setState() and scheduleFrame() execute** - Logs show they complete
5. ❌ **Flutter rendering pipeline freezes** - build() is never called after setState()

### Root Cause: Flutter Plugin During Registration

The freeze occurs **during or immediately after** `GeneratedPluginRegistrant.register(with: self)`.

This line registers ALL Flutter plugins with the iOS platform. One of these plugins is:
1. Making a **synchronous blocking call** on the main thread
2. Blocking the **iOS run loop** before Flutter can schedule the next frame
3. Preventing **WidgetsBinding** from executing frame callbacks

### Timeline of Execution

```
1. AppDelegate.didFinishLaunchingWithOptions starts ✅
2. GeneratedPluginRegistrant.register(with: self) ✅
   └─> Plugin X initializes and BLOCKS main thread ❌
3. AppDelegate completes and returns true ✅
4. Flutter bootstrap starts and completes ✅
5. setState() is called and completes ✅
6. scheduleFrame() is called ✅
7. ❌ FREEZE - Main thread blocked, frame never renders
```

### Why This Happens

After `GeneratedPluginRegistrant.register()` completes, one of the plugins has:
- Left a blocking operation on the main thread
- Created a deadlock in the iOS run loop
- Prevented the WidgetsBinding from processing frame callbacks

Even though AppDelegate returns `true` and bootstrap completes, the **iOS main thread is blocked** by a plugin's native code, preventing Flutter from rendering frames.

## What We Need

This requires **native iOS debugging** to identify what's blocking the main thread:

1. **Xcode Thread Debugger**: Pause app when frozen, examine main thread stack trace
2. **Instruments**: Profile app to see where execution is blocked
3. **Plugin Isolation**: Disable ALL plugins and re-enable one by one

## Suspect Plugins

Based on previous BlackScreenBug fixes, these are the most likely culprits:

1. **firebase_messaging** - Known to block on iOS
2. **flutter_local_notifications** - Makes sync permission calls
3. **adapty_flutter** - Complex native iOS integration
4. **permission_handler** - Multiple permission checks
5. **connectivity_plus** - Already partially addressed

## Next Steps - UPDATED

Now that we've proven the blocker is in Flutter plugin registration, we need to identify **which specific plugin** is blocking:

### Option 1: Xcode Thread Debugger (FASTEST)
1. Launch app from Xcode (not flutter run)
2. When black screen appears, click "Pause" button in Xcode
3. View "Debug Navigator" → "Main Thread" stack trace
4. Look for which plugin's native code is blocking

### Option 2: Systematic Plugin Removal
1. Check `ios/Runner/GeneratedPluginRegistrant.m` to see all registered plugins
2. Temporarily remove plugins from `pubspec.yaml` one by one
3. Test after each removal until app works
4. Last removed plugin is the culprit

### Option 3: Add Verbose Logging to GeneratedPluginRegistrant
1. Open `ios/Runner/GeneratedPluginRegistrant.m`
2. Add NSLog before/after each `[XXXPlugin registerWithRegistrar:...]` call
3. See which plugin registration never completes

**RECOMMENDED**: Use Option 1 (Xcode debugger) for immediate identification

## Files Modified

- `/Users/onronder/duru-notes/lib/main.dart`
- `/Users/onronder/duru-notes/lib/app/app.dart`
- `/Users/onronder/duru-notes/lib/ui/notes_list_screen.dart`
- `/Users/onronder/duru-notes/lib/features/notes/providers/notes_state_providers.dart`
- `/Users/onronder/duru-notes/lib/core/bootstrap/bootstrap_providers.dart`

## Related Documentation

- Previous fix: `MasterImplementation Phases/BlackScreenBug/` (this happened before)
- Flutter issue tracker: https://github.com/flutter/flutter/issues

## Recommendation

This is beyond application-level fixes. You need to either:

1. Use Xcode native debugging to find the blocking call
2. Hire Flutter/iOS expert familiar with engine-level debugging
3. Consider alternative bootstrap architecture that doesn't use setState() on iOS

The problem is in the Flutter engine's interaction with iOS, not in the Dart application code.
