# Folder Provider Architecture

## Overview
This document describes the folder provider architecture after the FD-3 hygiene improvements.

## Provider Hierarchy

### 1. `folderHierarchyProvider` (Single Source of Truth)
- **Type**: StateNotifierProvider<FolderHierarchyNotifier, FolderHierarchyState>
- **Purpose**: Manages the complete folder tree structure
- **State**: Immutable state with folders list, expansion states, loading status
- **Updates**: Via `loadFolders()` which atomically replaces all folders
- **Used by**: Folder picker, tree views, navigation

### 2. `rootFoldersProvider` (Pure Derived Provider)
- **Type**: FutureProvider<List<LocalFolder>>
- **Purpose**: Provides just root-level folders for chips
- **Dependencies**: 
  - Watches `folderHierarchyProvider` (auto-rebuilds on hierarchy changes)
  - Watches `notesRepositoryProvider` (rebuilds on repo changes)
- **Caching**: None - always queries fresh from database
- **Used by**: FolderFilterChips component

## Update Flow

1. **Realtime Updates** (FolderRealtimeService)
   - Receives PostgreSQL change events
   - Debounces for 300ms
   - Calls `folderHierarchyProvider.notifier.loadFolders()`
   - `rootFoldersProvider` automatically rebuilds

2. **Pull-to-Refresh** (NotesListScreen)
   - User pulls down
   - Calls `folderHierarchyProvider.notifier.loadFolders()`
   - `rootFoldersProvider` automatically rebuilds

3. **Sync Completion** (SyncService)
   - Sync completes successfully
   - Calls `folderHierarchyProvider.notifier.loadFolders()`
   - `rootFoldersProvider` automatically rebuilds

## Guarantees

### Atomicity
- `loadFolders()` replaces entire folder list atomically
- No partial updates or race conditions
- State transitions are clean: loading → loaded/error

### Consistency
- `rootFoldersProvider` watches `folderHierarchyProvider`
- Both providers always show the same folder data
- No stale caches or conflicting state

### Purity
- `rootFoldersProvider` is a pure function of its dependencies
- Always queries fresh data from database
- No internal caching or memoization

### Reactivity
- Chips use `ref.watch(rootFoldersProvider)`
- Automatic rebuilds on any folder changes
- No manual refresh needed

## Best Practices

1. **Always use `loadFolders()`** to refresh folder data
2. **Never cache folder data** outside of providers
3. **Use `ref.watch`** for reactive UI components
4. **Debounce rapid updates** to prevent thrashing
5. **Keep providers pure** - no side effects in provider bodies

## Testing Checklist

✅ Chips reflect current folder set without hot restart
✅ No duplicate folder queries on refresh
✅ Folder picker and chips stay in sync
✅ Realtime updates apply within ~1 second
✅ No UI freezes during folder operations
