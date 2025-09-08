import 'package:flutter/material.dart';

/// Types of smart folders available in the app
enum SmartFolderType {
  recent,
  favorites,
  archived,
  shared,
  tagged,
  dateRange,
  contentType,
  custom;

  String get displayName {
    switch (this) {
      case SmartFolderType.recent:
        return 'Recently Modified';
      case SmartFolderType.favorites:
        return 'Favorites';
      case SmartFolderType.archived:
        return 'Archived';
      case SmartFolderType.shared:
        return 'Shared with Me';
      case SmartFolderType.tagged:
        return 'By Tags';
      case SmartFolderType.dateRange:
        return 'By Date Range';
      case SmartFolderType.contentType:
        return 'By Content Type';
      case SmartFolderType.custom:
        return 'Custom Rule';
    }
  }

  IconData get icon {
    switch (this) {
      case SmartFolderType.recent:
        return Icons.history;
      case SmartFolderType.favorites:
        return Icons.star;
      case SmartFolderType.archived:
        return Icons.archive;
      case SmartFolderType.shared:
        return Icons.people;
      case SmartFolderType.tagged:
        return Icons.label;
      case SmartFolderType.dateRange:
        return Icons.date_range;
      case SmartFolderType.contentType:
        return Icons.category;
      case SmartFolderType.custom:
        return Icons.rule;
    }
  }

  Color get color {
    switch (this) {
      case SmartFolderType.recent:
        return Colors.blue;
      case SmartFolderType.favorites:
        return Colors.amber;
      case SmartFolderType.archived:
        return Colors.grey;
      case SmartFolderType.shared:
        return Colors.green;
      case SmartFolderType.tagged:
        return Colors.purple;
      case SmartFolderType.dateRange:
        return Colors.orange;
      case SmartFolderType.contentType:
        return Colors.teal;
      case SmartFolderType.custom:
        return Colors.indigo;
    }
  }
}

/// Rule operators for smart folder conditions
enum RuleOperator {
  equals,
  notEquals,
  contains,
  notContains,
  startsWith,
  endsWith,
  greaterThan,
  lessThan,
  between,
  inList,
  notInList,
  isEmpty,
  isNotEmpty;

  String get displayName {
    switch (this) {
      case RuleOperator.equals:
        return 'equals';
      case RuleOperator.notEquals:
        return 'not equals';
      case RuleOperator.contains:
        return 'contains';
      case RuleOperator.notContains:
        return 'does not contain';
      case RuleOperator.startsWith:
        return 'starts with';
      case RuleOperator.endsWith:
        return 'ends with';
      case RuleOperator.greaterThan:
        return 'greater than';
      case RuleOperator.lessThan:
        return 'less than';
      case RuleOperator.between:
        return 'between';
      case RuleOperator.inList:
        return 'in list';
      case RuleOperator.notInList:
        return 'not in list';
      case RuleOperator.isEmpty:
        return 'is empty';
      case RuleOperator.isNotEmpty:
        return 'is not empty';
    }
  }
}

/// Fields that can be used in smart folder rules
enum RuleField {
  title,
  content,
  tags,
  createdDate,
  modifiedDate,
  attachmentCount,
  wordCount,
  hasImages,
  hasLinks,
  hasCode,
  hasTasks,
  isEncrypted,
  isFavorite,
  isArchived;

  String get displayName {
    switch (this) {
      case RuleField.title:
        return 'Title';
      case RuleField.content:
        return 'Content';
      case RuleField.tags:
        return 'Tags';
      case RuleField.createdDate:
        return 'Created Date';
      case RuleField.modifiedDate:
        return 'Modified Date';
      case RuleField.attachmentCount:
        return 'Attachment Count';
      case RuleField.wordCount:
        return 'Word Count';
      case RuleField.hasImages:
        return 'Has Images';
      case RuleField.hasLinks:
        return 'Has Links';
      case RuleField.hasCode:
        return 'Has Code Blocks';
      case RuleField.hasTasks:
        return 'Has Tasks';
      case RuleField.isEncrypted:
        return 'Is Encrypted';
      case RuleField.isFavorite:
        return 'Is Favorite';
      case RuleField.isArchived:
        return 'Is Archived';
    }
  }

  Type get valueType {
    switch (this) {
      case RuleField.title:
      case RuleField.content:
      case RuleField.tags:
        return String;
      case RuleField.createdDate:
      case RuleField.modifiedDate:
        return DateTime;
      case RuleField.attachmentCount:
      case RuleField.wordCount:
        return int;
      case RuleField.hasImages:
      case RuleField.hasLinks:
      case RuleField.hasCode:
      case RuleField.hasTasks:
      case RuleField.isEncrypted:
      case RuleField.isFavorite:
      case RuleField.isArchived:
        return bool;
    }
  }

  List<RuleOperator> get availableOperators {
    switch (valueType) {
      case String:
        return [
          RuleOperator.equals,
          RuleOperator.notEquals,
          RuleOperator.contains,
          RuleOperator.notContains,
          RuleOperator.startsWith,
          RuleOperator.endsWith,
          RuleOperator.isEmpty,
          RuleOperator.isNotEmpty,
        ];
      case DateTime:
        return [
          RuleOperator.equals,
          RuleOperator.notEquals,
          RuleOperator.greaterThan,
          RuleOperator.lessThan,
          RuleOperator.between,
        ];
      case int:
        return [
          RuleOperator.equals,
          RuleOperator.notEquals,
          RuleOperator.greaterThan,
          RuleOperator.lessThan,
          RuleOperator.between,
        ];
      case bool:
        return [
          RuleOperator.equals,
          RuleOperator.notEquals,
        ];
      default:
        return [RuleOperator.equals];
    }
  }
}

/// A single rule condition for a smart folder
class SmartFolderRule { // For 'between' operator

  const SmartFolderRule({
    required this.id,
    required this.field,
    required this.operator,
    this.value,
    this.secondValue,
  });

  factory SmartFolderRule.fromJson(Map<String, dynamic> json) {
    return SmartFolderRule(
      id: json['id'] as String,
      field: RuleField.values.byName(json['field'] as String),
      operator: RuleOperator.values.byName(json['operator'] as String),
      value: json['value'],
      secondValue: json['secondValue'],
    );
  }
  final String id;
  final RuleField field;
  final RuleOperator operator;
  final dynamic value;
  final dynamic secondValue;

  Map<String, dynamic> toJson() => {
    'id': id,
    'field': field.name,
    'operator': operator.name,
    'value': value,
    'secondValue': secondValue,
  };

  SmartFolderRule copyWith({
    String? id,
    RuleField? field,
    RuleOperator? operator,
    dynamic value,
    dynamic secondValue,
  }) {
    return SmartFolderRule(
      id: id ?? this.id,
      field: field ?? this.field,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      secondValue: secondValue ?? this.secondValue,
    );
  }
}

/// Smart folder configuration
class SmartFolderConfig {

  const SmartFolderConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.rules,
    this.combineWithAnd = true,
    this.customIcon,
    this.customColor,
    this.maxResults = 100,
    this.autoRefresh = true,
    this.refreshInterval,
  });

  factory SmartFolderConfig.fromJson(Map<String, dynamic> json) {
    return SmartFolderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: SmartFolderType.values.byName(json['type'] as String),
      rules: (json['rules'] as List)
          .map((r) => SmartFolderRule.fromJson(r as Map<String, dynamic>))
          .toList(),
      combineWithAnd: json['combineWithAnd'] as bool? ?? true,
      customIcon: json['customIcon'] != null
          ? IconData(json['customIcon'] as int, fontFamily: 'MaterialIcons')
          : null,
      customColor: json['customColor'] != null
          ? Color(json['customColor'] as int)
          : null,
      maxResults: json['maxResults'] as int? ?? 100,
      autoRefresh: json['autoRefresh'] as bool? ?? true,
      refreshInterval: json['refreshInterval'] != null
          ? Duration(seconds: json['refreshInterval'] as int)
          : null,
    );
  }
  final String id;
  final String name;
  final SmartFolderType type;
  final List<SmartFolderRule> rules;
  final bool combineWithAnd; // true = AND, false = OR
  final IconData? customIcon;
  final Color? customColor;
  final int maxResults;
  final bool autoRefresh;
  final Duration? refreshInterval;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'rules': rules.map((r) => r.toJson()).toList(),
    'combineWithAnd': combineWithAnd,
    'customIcon': customIcon?.codePoint,
    'customColor': customColor?.value,
    'maxResults': maxResults,
    'autoRefresh': autoRefresh,
    'refreshInterval': refreshInterval?.inSeconds,
  };

  SmartFolderConfig copyWith({
    String? id,
    String? name,
    SmartFolderType? type,
    List<SmartFolderRule>? rules,
    bool? combineWithAnd,
    IconData? customIcon,
    Color? customColor,
    int? maxResults,
    bool? autoRefresh,
    Duration? refreshInterval,
  }) {
    return SmartFolderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rules: rules ?? this.rules,
      combineWithAnd: combineWithAnd ?? this.combineWithAnd,
      customIcon: customIcon ?? this.customIcon,
      customColor: customColor ?? this.customColor,
      maxResults: maxResults ?? this.maxResults,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }
}

/// Predefined smart folder templates
class SmartFolderTemplates {
  static final recentlyModified = SmartFolderConfig(
    id: 'template_recent',
    name: 'Recently Modified',
    type: SmartFolderType.recent,
    rules: [
      SmartFolderRule(
        id: '1',
        field: RuleField.modifiedDate,
        operator: RuleOperator.greaterThan,
        value: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ],
  );

  static const favorites = SmartFolderConfig(
    id: 'template_favorites',
    name: 'Favorites',
    type: SmartFolderType.favorites,
    rules: [
      SmartFolderRule(
        id: '1',
        field: RuleField.isFavorite,
        operator: RuleOperator.equals,
        value: true,
      ),
    ],
  );

  static const withImages = SmartFolderConfig(
    id: 'template_images',
    name: 'Notes with Images',
    type: SmartFolderType.contentType,
    rules: [
      SmartFolderRule(
        id: '1',
        field: RuleField.hasImages,
        operator: RuleOperator.equals,
        value: true,
      ),
    ],
  );

  static const withTasks = SmartFolderConfig(
    id: 'template_tasks',
    name: 'Task Lists',
    type: SmartFolderType.contentType,
    rules: [
      SmartFolderRule(
        id: '1',
        field: RuleField.hasTasks,
        operator: RuleOperator.equals,
        value: true,
      ),
    ],
  );

  static const longNotes = SmartFolderConfig(
    id: 'template_long',
    name: 'Long Notes',
    type: SmartFolderType.contentType,
    rules: [
      SmartFolderRule(
        id: '1',
        field: RuleField.wordCount,
        operator: RuleOperator.greaterThan,
        value: 500,
      ),
    ],
  );

  static final List<SmartFolderConfig> all = [
    recentlyModified,
    favorites,
    withImages,
    withTasks,
    longNotes,
  ];
}
