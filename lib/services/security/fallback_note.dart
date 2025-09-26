/// Fallback note data when decryption fails
class FallbackNote {
  final String id;
  final String fallbackTitle;
  final String fallbackBody;
  final DateTime createdAt;
  final bool isRecoverable;
  final String? rawData;

  FallbackNote({
    required this.id,
    required this.fallbackTitle,
    required this.fallbackBody,
    required this.createdAt,
    required this.isRecoverable,
    this.rawData,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fallbackTitle': fallbackTitle,
    'fallbackBody': fallbackBody,
    'createdAt': createdAt.toIso8601String(),
    'isRecoverable': isRecoverable,
    'rawData': rawData,
  };

  factory FallbackNote.fromJson(Map<String, dynamic> json) => FallbackNote(
    id: json['id'] as String,
    fallbackTitle: json['fallbackTitle'] as String,
    fallbackBody: json['fallbackBody'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isRecoverable: json['isRecoverable'] as bool,
    rawData: json['rawData'] as String?,
  );
}