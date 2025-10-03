/// Pure domain entity for SavedSearch
/// This is infrastructure-agnostic and contains only business logic
class SavedSearch {
  final String id;
  final String name;
  final String query;
  final SearchFilters? filters;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final int usageCount;
  final int displayOrder;

  const SavedSearch({
    required this.id,
    required this.name,
    required this.query,
    this.filters,
    required this.isPinned,
    required this.createdAt,
    this.lastUsedAt,
    required this.usageCount,
    required this.displayOrder,
  });

  SavedSearch copyWith({
    String? id,
    String? name,
    String? query,
    SearchFilters? filters,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? usageCount,
    int? displayOrder,
  }) {
    return SavedSearch(
      id: id ?? this.id,
      name: name ?? this.name,
      query: query ?? this.query,
      filters: filters ?? this.filters,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      usageCount: usageCount ?? this.usageCount,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}

/// Domain entity for search filters
class SearchFilters {
  final List<String>? tags;
  final String? folderId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? isPinned;
  final bool? hasAttachments;
  final String? noteType;

  const SearchFilters({
    this.tags,
    this.folderId,
    this.startDate,
    this.endDate,
    this.isPinned,
    this.hasAttachments,
    this.noteType,
  });

  SearchFilters copyWith({
    List<String>? tags,
    String? folderId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isPinned,
    bool? hasAttachments,
    String? noteType,
  }) {
    return SearchFilters(
      tags: tags ?? this.tags,
      folderId: folderId ?? this.folderId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isPinned: isPinned ?? this.isPinned,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      noteType: noteType ?? this.noteType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (tags != null) 'tags': tags,
      if (folderId != null) 'folderId': folderId,
      if (startDate != null) 'startDate': startDate?.toIso8601String(),
      if (endDate != null) 'endDate': endDate?.toIso8601String(),
      if (isPinned != null) 'isPinned': isPinned,
      if (hasAttachments != null) 'hasAttachments': hasAttachments,
      if (noteType != null) 'noteType': noteType,
    };
  }

  factory SearchFilters.fromJson(Map<String, dynamic> json) {
    return SearchFilters(
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List<dynamic>) : null,
      folderId: json['folderId'] as String?,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      isPinned: json['isPinned'] as bool?,
      hasAttachments: json['hasAttachments'] as bool?,
      noteType: json['noteType'] as String?,
    );
  }
}