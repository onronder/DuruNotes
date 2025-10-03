import 'dart:convert';
import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/domain/entities/inbox_item.dart' as domain;
import 'package:drift/drift.dart';

/// Mapper for converting between database and domain inbox item models
class InboxItemMapper {
  /// Convert database InboxItem to domain entity
  static domain.InboxItem toDomain(db.InboxItem dbItem) {
    return domain.InboxItem(
      id: dbItem.id,
      userId: dbItem.userId,
      sourceType: dbItem.sourceType,
      payload: jsonDecode(dbItem.payload) as Map<String, dynamic>,
      createdAt: dbItem.createdAt,
      isProcessed: dbItem.isProcessed,
      noteId: dbItem.noteId,
    );
  }

  /// Convert domain entity to database companion for inserts
  static db.InboxItemsCompanion toCompanion(domain.InboxItem item) {
    return db.InboxItemsCompanion(
      id: Value(item.id),
      userId: Value(item.userId),
      sourceType: Value(item.sourceType),
      payload: Value(jsonEncode(item.payload)),
      createdAt: Value(item.createdAt),
      isProcessed: Value(item.isProcessed),
      noteId: Value(item.noteId),
      processedAt: item.isProcessed && item.noteId != null
          ? Value(DateTime.now())
          : const Value<String?>.absent(),
    );
  }

  /// Convert domain InboxItem to database companion for updates
  static db.InboxItemsCompanion toUpdateCompanion(domain.InboxItem item) {
    return db.InboxItemsCompanion(
      sourceType: Value(item.sourceType),
      payload: Value(jsonEncode(item.payload)),
      isProcessed: Value(item.isProcessed),
      noteId: Value(item.noteId),
      processedAt: item.isProcessed && item.noteId != null
          ? Value(DateTime.now())
          : const Value<String?>.absent(),
    );
  }

  /// Convert list of database items to domain entities
  static List<domain.InboxItem> toDomainList(List<db.InboxItem> dbItems) {
    return dbItems.map(toDomain).toList();
  }

  /// Create domain entity from JSON (database/API response)
  static domain.InboxItem fromJson(Map<String, dynamic> json) {
    return domain.InboxItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sourceType: json['source_type'] as String,
      payload: json['payload_json'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
      isProcessed: json['is_processed'] as bool? ?? false,
      noteId: json['note_id'] as String?,
    );
  }

  /// Convert domain entity to JSON for database/API
  static Map<String, dynamic> toJson(domain.InboxItem item) {
    return {
      'id': item.id,
      'user_id': item.userId,
      'source_type': item.sourceType,
      'payload_json': item.payload,
      'created_at': item.createdAt.toIso8601String(),
      'is_processed': item.isProcessed,
      if (item.noteId != null) 'note_id': item.noteId,
    };
  }
}