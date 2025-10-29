import 'package:duru_notes/domain/entities/quick_capture_queue_item.dart';
import 'package:duru_notes/domain/entities/quick_capture_widget_cache.dart';

abstract class IQuickCaptureRepository {
  Future<QuickCaptureQueueItem> enqueueCapture({
    required String userId,
    required Map<String, dynamic> payload,
    String? platform,
  });

  Future<List<QuickCaptureQueueItem>> getPendingCaptures({
    required String userId,
    int limit,
  });

  Future<void> markCaptureProcessed({
    required String id,
    bool processed,
    DateTime? processedAt,
  });

  Future<void> incrementRetryCount(String id);

  Future<void> deleteCapture(String id);

  Future<void> clearProcessedCaptures({
    required String userId,
    DateTime? olderThan,
  });

  Future<QuickCaptureWidgetCache?> getWidgetCache(String userId);

  Future<void> upsertWidgetCache(QuickCaptureWidgetCache cache);
}
