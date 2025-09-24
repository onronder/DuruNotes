class Attachment {
  final String id;
  final String noteId;
  final String fileName;
  final String mimeType;
  final int size;
  final String? url;
  final String? localPath;
  final DateTime uploadedAt;

  const Attachment({
    required this.id,
    required this.noteId,
    required this.fileName,
    required this.mimeType,
    required this.size,
    this.url,
    this.localPath,
    required this.uploadedAt,
  });

  Attachment copyWith({
    String? id,
    String? noteId,
    String? fileName,
    String? mimeType,
    int? size,
    String? url,
    String? localPath,
    DateTime? uploadedAt,
  }) {
    return Attachment(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Attachment &&
        other.id == id &&
        other.noteId == noteId &&
        other.fileName == fileName &&
        other.mimeType == mimeType &&
        other.size == size;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        noteId.hashCode ^
        fileName.hashCode ^
        mimeType.hashCode ^
        size.hashCode;
  }

  @override
  String toString() {
    return 'Attachment(id: $id, fileName: $fileName, size: $size, mimeType: $mimeType)';
  }
}