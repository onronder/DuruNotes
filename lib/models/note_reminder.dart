import 'package:duru_notes/data/local/app_db.dart' show RecurrencePattern, ReminderType;

/// Domain model representing a note reminder with all its properties.
class NoteReminder {

  const NoteReminder({
    required this.id,
    required this.noteId,
    required this.title,
    required this.type, required this.scheduledTime, required this.createdAt, required this.updatedAt, this.body,
    this.remindAt,
    this.isCompleted = false,
    this.isSnoozed = false,
    this.snoozedUntil,
    this.isActive = true,
    this.recurrencePattern = RecurrencePattern.none,
    this.recurrenceInterval = 1,
    this.recurrenceEndDate,
    this.latitude,
    this.longitude,
    this.radius,
    this.locationName,
    this.notificationTitle,
    this.notificationBody,
    this.timeZone,
  });
  final int id;
  final String noteId;
  final String title;
  final String? body;
  final ReminderType type;
  final DateTime scheduledTime;
  final DateTime? remindAt;
  final bool isCompleted;
  final bool isSnoozed;
  final DateTime? snoozedUntil;
  final bool isActive;
  final RecurrencePattern recurrencePattern;
  final int recurrenceInterval;
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
    DateTime? snoozedUntil,
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
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteReminder &&
        other.id == id &&
        other.noteId == noteId &&
        other.title == title &&
        other.body == body &&
        other.type == type &&
        other.scheduledTime == scheduledTime &&
        other.remindAt == remindAt &&
        other.isCompleted == isCompleted &&
        other.isSnoozed == isSnoozed &&
        other.snoozedUntil == snoozedUntil &&
        other.isActive == isActive &&
        other.recurrencePattern == recurrencePattern &&
        other.recurrenceInterval == recurrenceInterval &&
        other.recurrenceEndDate == recurrenceEndDate &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.radius == radius &&
        other.locationName == locationName &&
        other.notificationTitle == notificationTitle &&
        other.notificationBody == notificationBody &&
        other.timeZone == timeZone &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        noteId,
        title,
        body,
        type,
        scheduledTime,
        remindAt,
        isCompleted,
        isSnoozed,
        snoozedUntil,
        isActive,
        recurrencePattern,
        recurrenceInterval,
        recurrenceEndDate,
        latitude,
        longitude,
        radius,
        locationName,
        notificationTitle,
        notificationBody,
        timeZone,
        createdAt,
        updatedAt,
      ]);
}
