import 'package:duru_notes/domain/entities/inbox_item.dart';

/// Domain repository interface for managing inbox items
/// Inbox items are unprocessed content from various sources (email, quick capture, etc.)
/// that need to be processed into notes
abstract class IInboxRepository {
  /// Get a specific inbox item by ID
  Future<InboxItem?> getById(String id);

  /// Get all unprocessed inbox items
  Future<List<InboxItem>> getUnprocessed();

  /// Get inbox items by source type (email, quick_capture, etc.)
  Future<List<InboxItem>> getBySourceType(String sourceType);

  /// Get inbox items within a date range
  Future<List<InboxItem>> getByDateRange(DateTime start, DateTime end);

  /// Create a new inbox item
  Future<InboxItem> create(InboxItem item);

  /// Update an existing inbox item
  Future<InboxItem> update(InboxItem item);

  /// Mark an inbox item as processed
  Future<void> markAsProcessed(String id, {String? noteId});

  /// Delete a specific inbox item
  Future<void> delete(String id);

  /// Delete all processed items older than specified days
  Future<void> deleteProcessed({int? olderThanDays});

  /// Get count of unprocessed items
  Future<int> getUnprocessedCount();

  /// Watch unprocessed items for changes
  Stream<List<InboxItem>> watchUnprocessed();

  /// Watch unprocessed item count
  Stream<int> watchUnprocessedCount();

  /// Process an inbox item and convert it to a note
  Future<void> processItem(String id, String noteId);

  /// Get statistics by source type
  Future<Map<String, int>> getStatsBySourceType();

  /// Clean up old items
  Future<void> cleanupOldItems({required int daysToKeep});
}