import 'dart:async';

import 'package:duru_notes/core/events/mutation_event_bus.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Legacy type alias for backward compatibility
typedef NotesRepository = NotesCoreRepository;

/// Represents a page of notes with pagination state
///
/// POST-ENCRYPTION: Now uses domain.Note with decrypted content
class NotesPage {
  const NotesPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
    this.isLoading = false,
  });
  final List<domain.Note> items; // Changed from LocalNote to domain.Note
  final bool hasMore;
  final DateTime? nextCursor;
  final bool isLoading;

  NotesPage copyWith({
    List<domain.Note>? items, // Changed from LocalNote to domain.Note
    bool? hasMore,
    DateTime? nextCursor,
    bool? isLoading,
  }) {
    return NotesPage(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotesPage &&
        other.items.length == items.length &&
        other.hasMore == hasMore &&
        other.nextCursor == nextCursor &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return items.hashCode ^
        hasMore.hashCode ^
        nextCursor.hashCode ^
        isLoading.hashCode;
  }
}

/// StateNotifier for managing paginated notes
class NotesPaginationNotifier extends StateNotifier<AsyncValue<NotesPage>> {
  NotesPaginationNotifier(
    this._ref,
    this._repo, {
    MutationEventBus? mutationBus,
  }) : super(
         const AsyncValue.data(
           NotesPage(items: [], hasMore: true, nextCursor: null),
         ),
       ) {
    _mutationSubscription = mutationBus?.stream
        .where((event) => event.entity == MutationEntity.note)
        .listen(_handleMutationEvent);
  }

  /// PRODUCTION FIX: Empty constructor for unauthenticated state
  /// Returns a notifier with empty, non-loading state
  factory NotesPaginationNotifier.empty(Ref ref) {
    return _EmptyNotesPaginationNotifier(ref);
  }

  final Ref _ref;
  final NotesRepository? _repo;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;
  bool _mutationRefreshScheduled = false;
  StreamSubscription<MutationEvent>? _mutationSubscription;

  AppLogger get logger => _ref.read(loggerProvider);
  AnalyticsService get analytics => _ref.read(analyticsProvider);

  void _handleMutationEvent(MutationEvent event) {
    if (!mounted) {
      return;
    }

    // Avoid redundant refreshes when multiple events for the same trace fire.
    final traceId = event.traceId;
    if (traceId != null && traceId == _lastRefreshTraceId) {
      logger.debug(
        'Pagination: Skipping refresh for already processed trace',
        data: {'traceId': traceId},
      );
      return;
    }

    logger.debug(
      'Pagination: Mutation event received, scheduling refresh',
      data: {
        'entityId': event.entityId,
        'kind': event.kind.name,
        if (traceId != null) 'traceId': traceId,
      },
    );
    _scheduleAutoRefresh(traceId);
  }

  void _scheduleAutoRefresh(String? traceId) {
    if (_mutationRefreshScheduled) {
      return;
    }
    _mutationRefreshScheduled = true;
    Future<void>.microtask(() async {
      if (!mounted) {
        _mutationRefreshScheduled = false;
        return;
      }
      await _doRefresh();
      if (mounted) {
        _lastRefreshTraceId = traceId;
      }
      _mutationRefreshScheduled = false;
    });
  }

  String? _lastRefreshTraceId;

  /// Load more notes (append to current list)
  Future<void> loadMore() async {
    if (!mounted) {
      logger.debug('Pagination: loadMore ignored because notifier disposed');
      return;
    }
    // PRODUCTION FIX: Guard against null repository (unauthenticated state)
    if (_repo == null) {
      logger.breadcrumb(
        'Pagination: Cannot load notes - no repository (user not authenticated)',
      );
      return;
    }

    if (_isLoadingMore) {
      logger.breadcrumb('Pagination: loadMore called while already loading');
      return;
    }

    final currentState = state.value;
    if (currentState == null || !currentState.hasMore) {
      logger.breadcrumb('Pagination: No more pages to load');
      return;
    }

    _isLoadingMore = true;

    try {
      // Set loading state
      state = AsyncValue.data(currentState.copyWith(isLoading: true));

      logger.breadcrumb(
        'Pagination: Loading next page',
        data: {
          'current_items': currentState.items.length,
          'cursor': currentState.nextCursor?.toIso8601String(),
        },
      );

      // Fetch next page
      final newNotes = await _repo.listAfter(currentState.nextCursor);
      if (!mounted) {
        _isLoadingMore = false;
        return;
      }

      logger.info(
        '📊 Pagination: Repository returned ${newNotes.length} notes',
        data: {'cursor': currentState.nextCursor?.toIso8601String() ?? 'null'},
      );

      // Merge with existing items and de-duplicate by note ID
      final mergedMap = <String, domain.Note>{};
      for (final note in currentState.items) {
        mergedMap[note.id] = note;
      }
      for (final note in newNotes) {
        mergedMap[note.id] = note;
      }

      // Sort notes with pinned items first, then by most recent update
      final mergedItems = mergedMap.values.toList()
        ..sort((a, b) {
          if (a.isPinned != b.isPinned) {
            return a.isPinned ? -1 : 1;
          }
          return b.updatedAt.compareTo(a.updatedAt);
        });

      final hasMore = newNotes.length == _pageSize;
      DateTime? nextCursor = currentState.nextCursor;
      if (mergedItems.isNotEmpty) {
        for (final note in mergedItems.reversed) {
          if (!note.isPinned) {
            nextCursor = note.updatedAt;
            break;
          }
        }
        nextCursor ??= mergedItems.last.updatedAt;
      }

      logger.info(
        '📊 Pagination: Updated state with ${mergedItems.length} total notes',
        data: {
          'new_notes': newNotes.length,
          'total': mergedItems.length,
          'has_more': hasMore,
        },
      );

      // Update state
      if (!mounted) {
        _isLoadingMore = false;
        return;
      }
      state = AsyncValue.data(
        NotesPage(items: mergedItems, hasMore: hasMore, nextCursor: nextCursor),
      );

      // Analytics
      analytics.event(
        AnalyticsEvents.notesPageLoaded,
        properties: {
          'page_size': newNotes.length,
          'total_items': mergedItems.length,
          'has_more': hasMore,
          'cursor_provided': currentState.nextCursor != null,
        },
      );

      logger.info(
        'Pagination: Page loaded successfully',
        data: {
          'new_notes_count': newNotes.length,
          'total_notes': mergedItems.length,
          'has_more': hasMore,
        },
      );
    } catch (error, stackTrace) {
      logger.error(
        'Pagination: Failed to load more notes',
        error: error,
        stackTrace: stackTrace,
      );

      // Revert loading state and set error
      state = AsyncValue.error(error, stackTrace);

      analytics.trackError(
        'Pagination load failed',
        context: 'NotesPaginationNotifier.loadMore',
        properties: {
          'current_items': currentState.items.length,
          'cursor': currentState.nextCursor?.toIso8601String(),
        },
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Refresh the entire list (reset pagination)
  Future<void> refresh() async {
    // For immediate refresh (e.g., after sync), call directly
    // The debouncing is moved inside _doRefresh for rapid user-triggered refreshes
    await _doRefresh();
  }

  Future<void> _doRefresh() async {
    _lastRefreshTraceId = null;
    if (!mounted) {
      logger.debug('Pagination: refresh ignored because notifier disposed');
      return;
    }
    logger.info('Pagination: Refreshing notes list');

    try {
      // Reset state
      state = const AsyncValue.data(
        NotesPage(items: [], hasMore: true, nextCursor: null, isLoading: true),
      );

      // Load first page
      await loadMore();

      analytics.event(
        AnalyticsEvents.notesRefreshed,
        properties: {'trigger': 'pull_to_refresh'},
      );
    } catch (error, stackTrace) {
      logger.error(
        'Pagination: Failed to refresh notes',
        error: error,
        stackTrace: stackTrace,
      );
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Check if near bottom of list and should load more
  void checkLoadMore(double scrollPosition, double maxScrollExtent) {
    const threshold = 400.0; // pixels from bottom
    final nearBottom = scrollPosition > (maxScrollExtent - threshold);

    if (nearBottom) {
      analytics.event(
        AnalyticsEvents.notesLoadMore,
        properties: {
          'scroll_position': scrollPosition,
          'max_extent': maxScrollExtent,
          'threshold': threshold,
        },
      );

      loadMore();
    }
  }

  /// Get the current page state (useful for UI)
  NotesPage? get currentPage => state.value;

  /// Check if currently loading more items
  bool get isLoadingMore => _isLoadingMore;

  @override
  void dispose() {
    _mutationSubscription?.cancel();
    _mutationRefreshScheduled = false;
    super.dispose();
  }
}

/// Extension to add pagination-specific analytics events
extension PaginationAnalytics on AnalyticsEvents {
  static const String notesPageLoaded = 'notes.page_loaded';
  static const String notesLoadMore = 'notes.load_more';
  static const String notesRefreshed = 'notes.refreshed';
}

/// PRODUCTION FIX: Empty pagination notifier for unauthenticated state
/// Returns empty state and no-ops all operations
class _EmptyNotesPaginationNotifier extends NotesPaginationNotifier {
  _EmptyNotesPaginationNotifier(Ref ref) : super(ref, null, mutationBus: null);

  @override
  Future<void> loadMore() async {
    // No-op when not authenticated
  }

  @override
  Future<void> refresh() async {
    // No-op when not authenticated
  }
}
