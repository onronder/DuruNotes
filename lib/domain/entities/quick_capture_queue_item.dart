class QuickCaptureQueueItem {
  QuickCaptureQueueItem({
    required this.id,
    required this.userId,
    required this.payload,
    required this.createdAt,
    this.platform,
    this.retryCount = 0,
    this.processed = false,
    this.updatedAt,
    this.processedAt,
  });

  final String id;
  final String userId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? processedAt;
  final String? platform;
  final int retryCount;
  final bool processed;

  QuickCaptureQueueItem copyWith({
    Map<String, dynamic>? payload,
    DateTime? updatedAt,
    DateTime? processedAt,
    String? platform,
    int? retryCount,
    bool? processed,
  }) {
    return QuickCaptureQueueItem(
      id: id,
      userId: userId,
      payload: payload ?? this.payload,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      processedAt: processedAt ?? this.processedAt,
      platform: platform ?? this.platform,
      retryCount: retryCount ?? this.retryCount,
      processed: processed ?? this.processed,
    );
  }
}
