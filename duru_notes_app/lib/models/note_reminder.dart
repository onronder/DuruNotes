import '../data/local/app_db.dart' show ReminderType, RecurrencePattern;

/// Model representing a note reminder
class NoteReminder {
  final int id;
  final String noteId;
  final String title;
  final String? body;
  final ReminderType type;
  final DateTime scheduledTime;
  final DateTime? remindAt;
  final bool isCompleted;
  final bool isSnoozed;
  final DateTime? snoozeUntil;
  final bool isActive;
  final RecurrencePattern? recurrencePattern;
  final int? recurrenceInterval;
  final DateTime? recurrenceEndDate;
  final double? latitude;
  final double? longitude;
  final double? radius;
  final String? locationName;
  final String? notificationTitle;
  final String? notificationBody;
  final String? timeZone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteReminder({
    required this.id,
    required this.noteId,
    required this.title,
    this.body,
    required this.type,
    required this.scheduledTime,
    this.remindAt,
    this.isCompleted = false,
    this.isSnoozed = false,
    this.snoozeUntil,
    this.isActive = true,
    this.recurrencePattern,
    this.recurrenceInterval,
    this.recurrenceEndDate,
    this.latitude,
    this.longitude,
    this.radius,
    this.locationName,
    this.notificationTitle,
    this.notificationBody,
    this.timeZone,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy with updated fields
  NoteReminder copyWith({
    int? id,
    String? noteId,
    String? title,
    String? body,
    ReminderType? type,
    DateTime? scheduledTime,
    DateTime? remindAt,
    bool? isCompleted,
    bool? isSnoozed,
    DateTime? snoozeUntil,
    bool? isActive,
    RecurrencePattern? recurrencePattern,
    int? recurrenceInterval,
    DateTime? recurrenceEndDate,
    double? latitude,
    double? longitude,
    double? radius,
    String? locationName,
    String? notificationTitle,
    String? notificationBody,
    String? timeZone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteReminder(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      remindAt: remindAt ?? this.remindAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      snoozeUntil: snoozeUntil ?? this.snoozeUntil,
      isActive: isActive ?? this.isActive,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      locationName: locationName ?? this.locationName,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
      timeZone: timeZone ?? this.timeZone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this reminder is location-based
  bool get isLocationBased => latitude != null && longitude != null;

  /// Check if this reminder is recurring
  bool get isRecurring => recurrencePattern != null && recurrencePattern != RecurrencePattern.none;

  /// Get snoozed until time (alias for snoozeUntil for backward compatibility)
  DateTime? get snoozedUntil => snoozeUntil;

  /// Get the display text for the reminder type
  String get typeDisplayText {
    switch (type) {
      case ReminderType.time:
        return 'Time-based';
      case ReminderType.location:
        return 'Location-based';
      case ReminderType.recurring:
        return 'Recurring';
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'title': title,
      'body': body,
      'type': type.name,
      'scheduledTime': scheduledTime.toIso8601String(),
      'remindAt': remindAt?.toIso8601String(),
      'isCompleted': isCompleted,
      'isSnoozed': isSnoozed,
      'snoozeUntil': snoozeUntil?.toIso8601String(),
      'isActive': isActive,
      'recurrencePattern': recurrencePattern?.name,
      'recurrenceInterval': recurrenceInterval,
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'locationName': locationName,
      'notificationTitle': notificationTitle,
      'notificationBody': notificationBody,
      'timeZone': timeZone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory NoteReminder.fromJson(Map<String, dynamic> json) {
    return NoteReminder(
      id: json['id'] as int,
      noteId: json['noteId'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      type: ReminderType.values.firstWhere((e) => e.name == json['type']),
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      remindAt: json['remindAt'] != null ? DateTime.parse(json['remindAt'] as String) : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
      isSnoozed: json['isSnoozed'] as bool? ?? false,
      snoozeUntil: json['snoozeUntil'] != null ? DateTime.parse(json['snoozeUntil'] as String) : null,
      isActive: json['isActive'] as bool? ?? true,
      recurrencePattern: json['recurrencePattern'] != null 
          ? RecurrencePattern.values.firstWhere((e) => e.name == json['recurrencePattern'])
          : null,
      recurrenceInterval: json['recurrenceInterval'] as int?,
      recurrenceEndDate: json['recurrenceEndDate'] != null ? DateTime.parse(json['recurrenceEndDate'] as String) : null,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      radius: json['radius'] as double?,
      locationName: json['locationName'] as String?,
      notificationTitle: json['notificationTitle'] as String?,
      notificationBody: json['notificationBody'] as String?,
      timeZone: json['timeZone'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
