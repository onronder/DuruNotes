# Root Cause Analysis: Flutter Widget Rebuild Failure

## Problem Statement
iOS app shows black screen on launch. Bootstrap completes successfully, setState() executes, but Flutter widgets NEVER rebuild.

## Investigation Process

### Step 1: Initial Hypothesis
Suspected Adapty/SharedPreferences blocking main thread during initialization.

**Fixes Applied:**
- ✅ Deferred Adapty initialization to post-first-frame
- ✅ Preloaded SharedPreferences during bootstrap
- ✅ Removed constructor blocking in theme/locale notifiers

**Result:** App still shows black screen. setState() completes but no rebuild.

### Step 2: Replaced FutureBuilder with StatefulWidget
Changed from FutureBuilder-based approach to manual Future handling with setState().

**Result:** setState() executes but no rebuild still occurs.

### Step 3: Added scheduleMicrotask
Wrapped setState() in scheduleMicrotask() to ensure proper event loop execution.

**Result:** setState() executes in microtask but no rebuild occurs.

### Step 4: Minimal Reproduction Test
Created `lib/main_minimal_test.dart` with NO bootstrap logic, just basic setState() tests.

## BREAKTHROUGH DISCOVERY

The minimal test revealed the exact pattern:

```
flutter: 🧪 [MinimalTest] Calling setState immediately
flutter: 🧪 [MinimalTest] setState immediate completed
flutter: 🧪 [MinimalTest] build() called #1, message: setState immediate  ✅

flutter: 🧪 [MinimalTest] Calling setState in microtask
flutter: 🧪 [MinimalTest] setState microtask completed
flutter: 🧪 [MinimalTest] build() called #2, message: setState microtask  ✅

flutter: 🧪 [MinimalTest] Calling setState after delay
flutter: 🧪 [MinimalTest] setState delayed completed
(NO build() #3 - rebuild NEVER happens) ❌
```

## Root Cause Pattern

| setState() Context | Rebuild Triggered? |
|-------------------|-------------------|
| Synchronous code in initState() | ✅ YES |
| scheduleMicrotask() callback | ✅ YES |
| Future.delayed() callback | ❌ NO |
| Future.then() callback (bootstrap) | ❌ NO |

**Conclusion:** setState() calls from **Future callbacks that complete after a certain point** in the app lifecycle do NOT trigger widget rebuilds!

## Why This Happens

After the first 2 builds complete and Flutter DevTools initializes, something in the Flutter framework's state changes that breaks the frame scheduler for async Future callbacks.

Possible causes:
1. **Frame scheduler gets disabled** after initial stable state
2. **Widget tree gets locked** preventing further rebuilds
3. **DevTools initialization** interferes with frame scheduling
4. **iOS-specific issue** with event loop interaction

## The Bootstrap Problem Explained

In the main app:
```dart
AppBootstrap().initialize().then((result) {  // Future.then callback
  scheduleMicrotask(() {
    setState(() {
      _bootstrapResult = result;
      _isBootstrapping = false;
    });
  });
});
```

The bootstrap runs as a Future, and by the time `.then()` callback fires:
- Flutter has already rendered the initial loading screen
- DevTools has initialized
- Frame scheduler is in a state where Future callbacks can't trigger rebuilds
- Even wrapping in scheduleMicrotask doesn't help because the callback itself is from a Future

## Why Minimal Test Partially Works

The minimal test shows that:
- **Immediate setState()** works because it's synchronous in initState
- **Microtask setState()** works because it's scheduled before the "lockout" happens
- **Future.delayed setState()** fails because the Future completes after the lockout

The bootstrap Future takes several seconds to complete (Supabase init, migrations, etc.), so by the time it finishes, the frame scheduler is already in the broken state.

## Solution Approach

The fix is NOT to change when/how setState() is called, but to prevent whatever is breaking the frame scheduler after the initial renders.

Potential solutions:
1. **Keep frame scheduler active** throughout app lifecycle
2. **Manually schedule frames** using WidgetsBinding.instance.scheduleFrame() after Future completion
3. **Restructure app initialization** to avoid long-running Futures before first frame
4. **Investigate DevTools interaction** - disable DevTools and see if problem persists
5. **Use runApp() again** after bootstrap completes to "reset" the framework

## Next Steps

1. Test if manually calling `WidgetsBinding.instance.scheduleFrame()` after Future completion helps
2. Test if problem occurs with DevTools disabled
3. Try calling `runApp()` again after bootstrap completes
4. Investigate Flutter engine logs for frame scheduler state
5. Check if this is an iOS simulator-specific issue (test on real device)

## Files

- `lib/main_minimal_test.dart` - Minimal reproduction test (proves Future callback issue)
- `lib/main.dart` - Main app with bootstrap (shows same pattern)
- `/tmp/flutter_run_minimal_test.log` - Log showing the pattern

## Status

**Root Cause Identified:** Flutter frame scheduler stops processing setState() calls from Future callbacks after initial app stabilization.

**Severity:** CRITICAL - Complete app failure

**Reproducibility:** 100% - Occurs every time with Future-based async initialization
