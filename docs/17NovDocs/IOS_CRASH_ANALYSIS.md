# iOS App Crash Analysis - Immediate Exit After setState()

## Problem Summary

The iOS Flutter app completes bootstrap successfully but crashes immediately after `setState()` completes, returning to the iOS home screen with "Lost connection to device" error.

### Evidence from Logs
```
flutter: [AppBootstrap] completed: failures=0 warnings=0 sentry=true
flutter: [BootstrapHost] initialize complete
flutter: [BootstrapHost] Updating bootstrapResultProvider...
flutter: [BootstrapHost] bootstrapResultProvider updated
flutter: [BootstrapHost] Calling setState to mark not bootstrapping...
flutter: [BootstrapHost] setState complete
Lost connection to device.
```

## Root Cause Analysis

### Critical Issue: Provider Chain Crash on First Build

The crash occurs when the widget tree rebuilds after `setState()` completes. Here's the exact execution flow:

#### 1. Bootstrap Completion Flow (main.dart)
```dart
// Line 74-77 in main.dart
setState(() {
  _isBootstrapping = false;
});
debugPrint('[BootstrapHost] setState complete');
```

#### 2. Widget Rebuild Cascade
After `setState()` completes, the build tree executes:
- `_BootstrapBody.build()` → Returns `BootstrapShell`
- `BootstrapShell.build()` → Returns `_AppWithShareExtension`  
- `_AppWithShareExtension.build()` → Returns `App(navigatorKey)`
- `App.build()` → Returns `MaterialApp(home: AuthWrapper())`
- `AuthWrapper.build()` → Eventually returns `AppShell()`
- `AppShell.build()` → Returns `AdaptiveNavigation` with `NotesListScreen` as body
- **`NotesListScreen.build()` → CRASH POINT**

#### 3. The Crash Point (notes_list_screen.dart:208-224)
```dart
@override
Widget build(BuildContext context) {
  if (!SecurityInitialization.isInitialized) {
    return Scaffold(...); // Should show loading
  }
  
  // Line 217 - First provider access
  ref.watch(unifiedRealtimeServiceProvider);
  
  // Line 220 - Second provider access  
  ref.watch(rootFoldersProvider);
  
  // Line 223 - Third provider access - THIS CAUSES THE CRASH
  final notesAsync = ref.watch(filteredNotesProvider);
  ...
}
```

### Provider Dependency Chain That Crashes

When `filteredNotesProvider` is watched, it triggers this chain:

```
filteredNotesProvider (notes_state_providers.dart:50)
  ↓ watches
currentNotesProvider (notes_state_providers.dart:151)
  ↓ watches
notesPageProvider (notes_state_providers.dart:168)
  ↓ watches
notesCoreRepositoryProvider (repository_providers.dart:45)
  ↓ creates
NotesPaginationNotifier
  ↓ immediately calls (line 177)
loadMore()
  ↓ tries to access
notesCoreRepositoryProvider
```

### The Fatal Throw

`notesCoreRepositoryProvider` (repository_providers.dart:45-51):
```dart
final notesCoreRepositoryProvider = Provider<NotesCoreRepository>((ref) {
  if (!SecurityInitialization.isInitialized) {
    throw StateError(
      '[notesCoreRepositoryProvider] Security services must be initialized...'
    );
  }
  ...
});
```

## Why This Happens

### Race Condition Between Widget Build and Security Initialization

Looking at app.dart:855-947, the AuthWrapper returns AppShell after a FutureBuilder completes:

```dart
return FutureBuilder<void>(
  future: _ensureSecurityServicesInitialized(),
  builder: (context, securitySnapshot) {
    if (securitySnapshot.connectionState != ConnectionState.done) {
      return Scaffold(...); // Still initializing
    }
    
    if (securitySnapshot.hasError) {
      return Scaffold(...); // Error screen
    }
    
    // At this point: SecurityInitialization.isInitialized == true
    _maybePerformInitialSync(); // Adds post-frame callbacks
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Multiple async operations...
      _initializeNotificationHandler();
      _initializeShareExtension();
      _syncWidgetCacheInBackground();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          ref.read(connectivityProvider); // ← BLOCKING PLATFORM CHANNEL
        } catch (e) {
          debugPrint('Failed to init connectivity: $e');
        }
      }
    });
    
    return const AppShell(); // ← Builds immediately, before post-frame callbacks
  },
);
```

### The Actual Problem: Two Competing Issues

#### Issue #1: Platform Channel Blocking (iOS-Specific)
At line 940 in app.dart, there's a post-frame callback that reads `connectivityProvider`:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    try {
      ref.read(connectivityProvider); // ← This makes a SYNCHRONOUS platform channel call
    } catch (e) {
      debugPrint('Failed to init connectivity: $e');
    }
  }
});
```

From offline_indicator.dart:8-10:
```dart
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged; // ← Creates Connectivity() instance
});
```

**The `Connectivity()` constructor makes a synchronous platform channel call to iOS**, which can block the main thread during the first frame after AppShell renders. This is documented in the CRITICAL_ISSUE_setState_Rendering_Freeze_Analysis.md file.

#### Issue #2: Provider Access During Build
NotesListScreen watches multiple providers immediately in its build() method:
- `unifiedRealtimeServiceProvider` (line 217)
- `rootFoldersProvider` (line 220)
- `filteredNotesProvider` (line 223)

The third one (`filteredNotesProvider`) triggers a cascade that:
1. Creates `NotesPaginationNotifier`
2. Immediately calls `loadMore()` (line 177 in notes_state_providers.dart)
3. Tries to access `notesCoreRepositoryProvider`

**If SecurityInitialization has been reset or is not actually initialized, this throws.**

## Why iOS Crashes but We Don't See Exception

On iOS, when there's a synchronous platform channel call during a critical rendering phase, combined with a state error being thrown, the Flutter engine can lose connection to the debug bridge before the exception is properly logged.

The "Lost connection to device" message indicates the app process terminated abruptly, likely due to:
1. Main thread blocking from Connectivity() initialization
2. Unhandled exception from provider access
3. iOS watchdog killing the app for being unresponsive

## Solutions

### Solution 1: Defer NotesListScreen Provider Access (RECOMMENDED)

Modify `NotesListScreen.build()` to defer provider access until after first frame:

**File:** `/Users/onronder/duru-notes/lib/ui/notes_list_screen.dart`

```dart
@override
Widget build(BuildContext context) {
  if (!SecurityInitialization.isInitialized) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  // CRITICAL FIX: Defer provider initialization to post-frame callback
  // This prevents blocking the initial render and allows the app to fully initialize
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    
    try {
      // Initialize these providers asynchronously after first frame
      ref.read(unifiedRealtimeServiceProvider);
    } catch (e) {
      debugPrint('[NotesListScreen] Error initializing realtime service: $e');
    }
  });

  // Initialize unified realtime service (only if authenticated)
  // REMOVED: ref.watch(unifiedRealtimeServiceProvider);

  // Trigger early loading of folders for deterministic first paint
  // KEPT: This is a FutureProvider, safer to watch
  ref.watch(rootFoldersProvider);

  final user = Supabase.instance.client.auth.currentUser;
  final notesAsync = ref.watch(filteredNotesProvider);
  final hasMore = ref.watch(hasMoreNotesProvider);
  ...
}
```

### Solution 2: Remove Synchronous Connectivity Check

The connectivity check in app.dart:936-945 is already trying to be async, but it's still problematic on iOS.

**File:** `/Users/onronder/duru-notes/lib/app/app.dart`

```dart
// CRITICAL FIX: Don't initialize connectivity during app startup
// Let the OfflineIndicator initialize it lazily when it's first used
// WidgetsBinding.instance.addPostFrameCallback((_) {
//   if (mounted) {
//     try {
//       ref.read(connectivityProvider);
//     } catch (e) {
//       debugPrint('Failed to init connectivity: $e');
//     }
//   }
// });

return const AppShell();
```

### Solution 3: Make filteredNotesProvider More Defensive

Add error handling to the provider chain:

**File:** `/Users/onronder/duru-notes/lib/features/notes/providers/notes_state_providers.dart`

```dart
final filteredNotesProvider = FutureProvider.autoDispose<List<domain.Note>>((
  ref,
) async {
  final currentFolder = ref.watch(currentFolderProvider);
  final filterState = ref.watch(filterStateProvider);

  // CRITICAL FIX: Add safety check before accessing repository
  if (!SecurityInitialization.isInitialized) {
    debugPrint('[filteredNotesProvider] Security not initialized, returning empty list');
    return <domain.Note>[];
  }

  // Get base notes based on folder selection
  List<domain.Note> notes;
  if (currentFolder != null) {
    try {
      final folderRepo = ref.watch(folderCoreRepositoryProvider);
      notes = await folderRepo.getNotesInFolder(currentFolder.id);
    } catch (e) {
      debugPrint('[filteredNotesProvider] Error loading folder notes: $e');
      return <domain.Note>[];
    }
  } else {
    // IMPORTANT: Use watch instead of read to trigger rebuilds when notes update
    notes = ref.watch(currentNotesProvider);
  }
  ...
});
```

### Solution 4: Add Global Error Boundary

Ensure the ErrorBoundary in BootstrapShell (main.dart:239) is actually catching errors:

**File:** `/Users/onronder/duru-notes/lib/main.dart`

```dart
debugPrint('[BootstrapShell] Creating DefaultAssetBundle with SentryAssetBundle...');
return DefaultAssetBundle(
  bundle: SentryAssetBundle(),
  child: ErrorBoundary(
    onError: (error, stackTrace) {
      // CRITICAL FIX: Log errors before showing fallback
      debugPrint('[ErrorBoundary] Caught error: $error');
      debugPrint('[ErrorBoundary] Stack trace: $stackTrace');
    },
    fallback: BootstrapFailureContent(
      failures: result.failures,
      warnings: result.warnings,
      onRetry: onRetry,
      stageDurations: result.stageDurations,
    ),
    child: Builder(
      builder: (context) {
        debugPrint('[BootstrapShell] Builder callback executing...');
        final widget = appBuilder != null
            ? appBuilder!(context)
            : _AppWithShareExtension(navigatorKey: navigatorKey);
        debugPrint('[BootstrapShell] Builder callback complete, returning widget');
        return widget;
      },
    ),
  ),
);
```

## Recommended Implementation Order

1. **FIRST**: Remove the connectivity initialization from app.dart (Solution 2) - This is the most likely cause of the iOS-specific crash
2. **SECOND**: Defer unifiedRealtimeServiceProvider access in NotesListScreen (Solution 1) - Prevents provider cascade during initial build
3. **THIRD**: Add defensive checks to filteredNotesProvider (Solution 3) - Extra safety layer
4. **OPTIONAL**: Add error logging to ErrorBoundary (Solution 4) - Better debugging

## Testing Plan

After implementing fixes:
1. Clean build iOS app
2. Test cold start
3. Verify bootstrap logs show completion
4. Verify app actually renders NotesListScreen
5. Check that no "Lost connection" occurs
6. Test connectivity changes work correctly
7. Test offline mode indicator appears when needed

## Related Files

- `/Users/onronder/duru-notes/lib/main.dart` - Bootstrap and error handling
- `/Users/onronder/duru-notes/lib/app/app.dart` - AuthWrapper and connectivity
- `/Users/onronder/duru-notes/lib/ui/notes_list_screen.dart` - First screen that crashes
- `/Users/onronder/duru-notes/lib/features/notes/providers/notes_state_providers.dart` - Provider chain
- `/Users/onronder/duru-notes/lib/infrastructure/providers/repository_providers.dart` - Repository providers
- `/Users/onronder/duru-notes/lib/ui/widgets/offline_indicator.dart` - Connectivity provider
