class QuickCaptureWidgetCache {
  QuickCaptureWidgetCache({
    required this.userId,
    required this.payload,
    required this.updatedAt,
  });

  final String userId;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;
}
