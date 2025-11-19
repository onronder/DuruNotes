# Sync Error Handling Standard

**Created:** 2025-11-18
**Status:** Documentation (Current State)
**Priority:** P3 (Minor improvements suggested)

---

## Overview

This document describes the standardized error handling pattern used across all synchronization methods in `unified_sync_service.dart`. The error handling is already quite consistent across all sync operations (`_syncFolders`, `_syncNotes`, `_syncTasks`, `_syncReminders`).

---

## Standard Error Handling Pattern

All sync methods follow this consistent four-step error handling pattern:

### 1. Error Logging
```dart
_logger.error('{Entity} sync failed', error: error, stackTrace: stack);
```

**Purpose:** Log the error with full context for debugging
**Standard Fields:**
- Message: "{Entity} sync failed" (e.g., "Note sync failed", "Task sync failed")
- error: The caught exception object
- stackTrace: Full stack trace for debugging

### 2. Exception Tracking (Sentry)
```dart
_captureSyncException(
  operation: 'sync{Entity}',
  error: error,
  stackTrace: stack,
  data: {
    'pendingUploads': toUpload.length,
    'pendingDownloads': toDownload.length,
  },
);
```

**Purpose:** Capture exception in error tracking system (Sentry)
**Standard Fields:**
- operation: Identifies which sync method failed
- error: The exception object
- stackTrace: Stack trace
- data: Context-specific metadata (counts, IDs, etc.)

**Variation:** `_syncReminders()` includes more detailed metrics:
- 'syncedReminders': Total count processed
- 'conflictsResolved': Number of conflicts handled
- 'batchesProcessed': Batch processing context

### 3. Security Audit Trail
```dart
_auditSync(
  'sync{Entity}',
  granted: false,
  reason: 'error=${error.runtimeType}',
);
```

**Purpose:** Record sync failure in security audit log
**Standard Fields:**
- operation: Same as exception tracking
- granted: Always `false` for errors
- reason: Error type for audit trail

### 4. Return Failure Result
```dart
return SyncResult(
  success: false,
  errors: ['{Entity} sync failed: ${error.toString()}'],
);
```

**Purpose:** Return standardized failure result to caller
**Standard Fields:**
- success: Always `false`
- errors: List containing user-facing error message
- Optional: Context-specific data (sync counts, conflicts, etc.)

---

## Current Implementation Status

### ✅ Fully Standardized:
- `_syncFolders()` (line 527-546)
- `_syncNotes()` (line 647-667)
- `_syncTasks()` (line 732-752)
- `_syncReminders()` (line 1017-1042) ⭐ **Enhanced with metrics**

### Pattern Consistency:
| Method | Logger | Sentry | Audit | Result | Context Data |
|--------|--------|--------|-------|--------|--------------|
| _syncFolders | ✅ | ✅ | ✅ | ✅ | toUpload/toDownload counts |
| _syncNotes | ✅ | ✅ | ✅ | ✅ | toUpload/toDownload counts |
| _syncTasks | ✅ | ✅ | ✅ | ✅ | toUpload/toDownload counts |
| _syncReminders | ✅ | ✅ | ✅ | ✅ | **Detailed metrics** |

---

## Suggested Minor Improvements

### 1. Enhanced Context Data (Low Priority)

**Current State:** Most sync methods provide basic counts
```dart
data: {
  'pendingUploads': toUpload.length,
  'pendingDownloads': toDownload.length,
},
```

**Suggestion:** Add operation duration for performance debugging
```dart
data: {
  'pendingUploads': toUpload.length,
  'pendingDownloads': toDownload.length,
  'syncDuration': syncDuration.inMilliseconds,
  'itemsProcessed': itemsProcessed,
},
```

**Benefit:** Helps identify performance-related failures

---

### 2. Standardize Metrics Across All Sync Methods

**Current State:** Only `_syncReminders()` tracks detailed metrics

**Suggestion:** Apply similar metrics tracking to other sync methods:
- Create `NoteSync Metrics`, `TaskSyncMetrics`, `FolderSyncMetrics`
- Track success/failure rates
- Track batch processing performance
- Track conflict resolution outcomes

**Benefit:** Consistent observability across all sync operations

---

### 3. User-Facing Error Messages

**Current State:** Generic error messages
```dart
errors: ['Note sync failed: ${error.toString()}'],
```

**Suggestion:** Provide actionable error messages
```dart
errors: [
  switch (error.runtimeType) {
    NetworkException => 'Sync failed: No internet connection. Will retry automatically.',
    AuthException => 'Sync failed: Session expired. Please sign in again.',
    _ => 'Note sync failed: ${error.toString()}',
  },
],
```

**Benefit:** Better user experience with actionable guidance

---

### 4. Error Recovery Hints

**Current State:** No recovery guidance in error data

**Suggestion:** Add recovery hints for common errors
```dart
data: {
  'pendingUploads': toUpload.length,
  'pendingDownloads': toDownload.length,
  'recoveryHint': _getRecoveryHint(error),
  'retryable': _isRetryable(error),
},
```

**Benefit:** Enables smarter retry logic and user guidance

---

## Error Classification

### Retryable Errors (Should auto-retry)
- Network timeouts
- Server errors (5xx)
- Rate limiting (429)
- Temporary database locks

### Non-Retryable Errors (Fail immediately)
- Authentication errors (401, 403)
- Validation errors (400)
- Schema mismatches
- Permanent data corruption

### Current State:
No explicit error classification. All errors handled the same way.

---

## Testing Recommendations

### Unit Tests for Error Handling

```dart
group('Sync Error Handling Standards', () {
  test('syncFolders handles network errors correctly', () async {
    // Arrange: Mock network failure
    when(mockApi.fetchFolders()).thenThrow(NetworkException());

    // Act
    final result = await syncService.syncAll();

    // Assert: Verify standard error pattern
    expect(result.success, false);
    expect(result.errors, isNotEmpty);
    verify(mockLogger.error(any, error: any, stackTrace: any)).called(1);
    verify(mockSentry.captureException(any)).called(1);
    verify(mockAudit.logFailure(any)).called(1);
  });

  test('all sync methods follow same error pattern', () async {
    // Test that syncFolders, syncNotes, syncTasks, syncReminders
    // all handle errors consistently
  });
});
```

---

## Implementation Priority

| Improvement | Priority | Effort | Impact |
|-------------|----------|--------|--------|
| Enhanced context data | P3 | Low | Medium |
| Standardize metrics | P3 | Medium | High |
| Better error messages | P2 | Low | High |
| Error recovery hints | P3 | Medium | Medium |
| Error classification | P2 | Medium | High |

---

## Conclusion

**Current State:** Error handling is already well-standardized across all sync methods. The four-step pattern (log → capture → audit → return) is consistently applied.

**Recommendation:** No urgent changes required. The suggested improvements are minor enhancements that can be implemented incrementally as part of future work.

**Highlight:** `_syncReminders()` serves as a good example with enhanced metrics tracking. Consider applying similar detailed metrics to other sync methods for better observability.

---

## Related Documentation

- **SYNC_ANALYSIS_REPORT.md** - Original sync compatibility analysis
- **reminder_sync_metrics.dart** - Metrics implementation for reminders
- **task_sync_metrics.dart** - Existing task metrics
- **sync_performance_metrics.dart** - General sync performance tracking

---

## Change Log

- **2025-11-18:** Initial documentation of standardized error handling pattern
- **2025-11-18:** Added reminder metrics tracking as reference implementation
