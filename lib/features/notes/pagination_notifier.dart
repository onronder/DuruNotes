import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Global instances
final AppLogger logger = LoggerFactory.instance;
final AnalyticsService analytics = AnalyticsFactory.instance;

/// Represents a page of notes with pagination state
class NotesPage {
  const NotesPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
    this.isLoading = false,
  });
  final List<LocalNote> items;
  final bool hasMore;
  final DateTime? nextCursor;
  final bool isLoading;

  NotesPage copyWith({
    List<LocalNote>? items,
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
  NotesPaginationNotifier(this._repo)
    : super(
        const AsyncValue.data(
          NotesPage(items: [], hasMore: true, nextCursor: null),
        ),
      );

  final NotesRepository _repo;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;

  /// Load more notes (append to current list)
  Future<void> loadMore() async {
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

      // Merge with existing items
      final mergedItems = [...currentState.items, ...newNotes];
      final hasMore = newNotes.length == _pageSize;
      final nextCursor = newNotes.isNotEmpty
          ? newNotes.last.updatedAt
          : currentState.nextCursor;

      // Update state
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
}

/// Extension to add pagination-specific analytics events
extension PaginationAnalytics on AnalyticsEvents {
  static const String notesPageLoaded = 'notes.page_loaded';
  static const String notesLoadMore = 'notes.load_more';
  static const String notesRefreshed = 'notes.refreshed';
}
