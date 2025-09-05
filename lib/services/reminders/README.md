# Reminder Services

This directory contains the modular reminder system for the Duru Notes app. The services are designed using the Single Responsibility Principle, making them easier to test, maintain, and extend.

## Architecture Overview

```
ReminderCoordinator (Facade)
├── GeofenceReminderService (Location-based)
├── RecurringReminderService (Time-based & Recurring)
└── SnoozeReminderService (Snooze functionality)
```

## Services

### 1. ReminderCoordinator

**File:** `reminder_coordinator.dart`

**Purpose:** Acts as a facade and coordinator for all reminder functionality. Provides a unified interface while delegating to specialized services.

**Key Features:**
- Unified API for reminder management
- Service composition and coordination
- Backward compatibility with existing code
- Permission management across all reminder types

**Usage:**
```dart
final coordinator = ref.read(reminderCoordinatorProvider);

// Create time-based reminder
final reminderId = await coordinator.createTimeReminder(
  noteId: 'note123',
  title: 'Meeting Reminder',
  body: 'Team standup in conference room',
  remindAtUtc: DateTime.now().add(Duration(hours: 1)),
  recurrence: RecurrencePattern.daily,
);

// Create location-based reminder
final locationId = await coordinator.createLocationReminder(
  noteId: 'note456',
  title: 'Grocery Shopping',
  body: 'Buy milk and bread',
  latitude: 37.7749,
  longitude: -122.4194,
  radius: 100.0,
  locationName: 'Whole Foods',
);
```

### 2. GeofenceReminderService

**File:** `geofence_reminder_service.dart`

**Purpose:** Manages location-based reminders using geofencing technology.

**Key Features:**
- Geofence setup and monitoring
- Location permission management
- GPS accuracy configuration
- Location-based notification triggering

**Configuration:**
- **Interval:** 5 seconds (geofence checking frequency)
- **Accuracy:** 100 meters (GPS accuracy requirement)
- **Loitering Delay:** 60 seconds (time before enter/exit triggers)

**Usage:**
```dart
final geofenceService = coordinator.geofenceService;

// Check location permissions
final hasPermission = await geofenceService.hasLocationPermissions();

// Create location reminder
final reminderId = await geofenceService.createLocationReminder(
  noteId: 'note123',
  title: 'Arrived at Office',
  body: 'Check daily tasks',
  latitude: 37.7749,
  longitude: -122.4194,
  radius: 50.0,
);
```

### 3. RecurringReminderService

**File:** `recurring_reminder_service.dart`

**Purpose:** Handles time-based reminders with support for complex recurring patterns.

**Key Features:**
- Multiple recurrence patterns (daily, weekly, monthly, yearly)
- Custom intervals (every N days/weeks/months/years)
- End date support for limited recurrence
- Edge case handling (leap years, month boundaries)
- Smart date adjustment for invalid dates

**Recurrence Patterns:**
```dart
enum RecurrencePattern {
  none,     // One-time reminder
  daily,    // Every N days
  weekly,   // Every N weeks
  monthly,  // Every N months (same day)
  yearly,   // Every N years (same date)
}
```

**Usage:**
```dart
final recurringService = coordinator.recurringService;

// Create weekly recurring reminder
final reminderId = await recurringService.createTimeReminder(
  noteId: 'note123',
  title: 'Weekly Team Meeting',
  body: 'Prepare status update',
  remindAtUtc: DateTime.now().add(Duration(days: 1)),
  recurrence: RecurrencePattern.weekly,
  recurrenceInterval: 1,
  recurrenceEndDate: DateTime.now().add(Duration(days: 365)),
);

// Get preview of upcoming occurrences
final upcoming = recurringService.getUpcomingOccurrences(
  DateTime.now(),
  RecurrencePattern.monthly,
  1,
  count: 5,
);
```

**Edge Case Handling:**
- **Feb 29 in non-leap years:** Adjusts to Feb 28
- **Month-end dates:** Adjusts to last day of target month
- **Invalid future dates:** Automatically corrects to valid dates

### 4. SnoozeReminderService

**File:** `snooze_reminder_service.dart`

**Purpose:** Provides sophisticated snooze functionality with smart scheduling.

**Key Features:**
- Multiple snooze durations
- Smart "tomorrow morning" calculation
- Snooze limit enforcement (max 5 times)
- Automatic snooze expiration handling
- Notification action handling

**Snooze Durations:**
```dart
enum SnoozeDuration {
  fiveMinutes,    // +5 minutes
  tenMinutes,     // +10 minutes
  fifteenMinutes, // +15 minutes
  thirtyMinutes,  // +30 minutes
  oneHour,        // +1 hour
  twoHours,       // +2 hours
  tomorrow,       // Smart morning time
}
```

**Smart Tomorrow Logic:**
- Late night (10 PM - 6 AM): Schedule for 9 AM
- Morning (6 AM - 12 PM): Schedule for 2 PM
- Afternoon/Evening: Schedule for 9 AM next day

**Usage:**
```dart
final snoozeService = coordinator.snoozeService;

// Snooze reminder for 15 minutes
final success = await snoozeService.snoozeReminder(
  reminderId,
  SnoozeDuration.fifteenMinutes,
);

// Handle notification actions
await snoozeService.handleSnoozeAction('snooze_5', payload);

// Clear snooze manually
await snoozeService.clearSnooze(reminderId);
```

## Database Integration

All services integrate with the `AppDb` database layer:

```dart
// Reminder database operations
await db.createReminder(reminderData);
await db.getReminderById(reminderId);
await db.updateReminder(reminderId, updates);
await db.deleteReminderById(reminderId);

// Specialized queries
await db.getTimeRemindersToTrigger(before: DateTime.now());
await db.getSnoozedRemindersToReschedule(now: DateTime.now());
await db.getRemindersForNote(noteId);
```

## Notification System

The services integrate with Flutter Local Notifications:

### Notification Channels
- **Main Channel:** `notes_reminders` - Time-based reminders
- **Location Channel:** `location_reminders` - Location-based reminders

### Notification Actions
```dart
// Time-based reminder actions
['snooze_5', 'snooze_15', 'complete']

// Location-based reminder actions
['complete']
```

## Error Handling

All services implement comprehensive error handling:

```dart
try {
  final result = await service.createReminder(...);
  return result;
} catch (e, stack) {
  logger.error('Failed to create reminder', error: e, stackTrace: stack);
  analytics.event('reminder.create_error', properties: {
    'error': e.toString(),
  });
  return null;
}
```

## Analytics Integration

Services provide detailed analytics for monitoring and optimization:

```dart
// Reminder creation tracking
analytics.event(AnalyticsEvents.reminderSet, properties: {
  'type': 'location',
  'has_recurrence': false,
  'radius_meters': 100,
});

// Snooze behavior tracking
analytics.event('reminder.snoozed', properties: {
  'duration': 'fifteenMinutes',
  'snooze_count': 2,
});
```

## Testing

Each service has comprehensive unit tests:

- **GeofenceReminderService:** Location permission flows, geofence setup, notification triggering
- **RecurringReminderService:** Recurrence calculations, edge cases, date handling
- **SnoozeReminderService:** Snooze logic, time calculations, limit enforcement

Run tests:
```bash
flutter test test/services/reminders/
```

## Performance Considerations

### Memory Management
- Services dispose of resources properly
- Geofence service stops monitoring on disposal
- Text controllers are disposed in widgets

### Background Processing
- Efficient polling intervals for geofencing
- Minimal database queries for due reminder checks
- Smart caching of reminder data

### Battery Optimization
- Configurable geofence accuracy vs battery trade-offs
- Intelligent background task scheduling
- Respect system notification settings

## Migration Guide

### From AdvancedReminderService

```dart
// Old way
final service = ref.read(advancedReminderServiceProvider);

// New way (recommended)
final coordinator = ref.read(reminderCoordinatorProvider);

// Direct service access (when needed)
final geofenceService = coordinator.geofenceService;
```

### Backward Compatibility

The `ReminderCoordinator` maintains the same public API as the original `AdvancedReminderService`, ensuring no breaking changes for existing code.

## Future Enhancements

### Potential Features
1. **Voice-activated reminders**
2. **AI-powered reminder suggestions**
3. **Cross-device reminder synchronization**
4. **Advanced geofence shapes (polygons)**
5. **Weather-based reminder adjustments**

### Extension Points
The modular architecture makes it easy to add new reminder types:

```dart
abstract class ReminderService {
  Future<int?> createReminder(...);
  Future<void> processReminders();
  Future<void> dispose();
}

class WeatherReminderService implements ReminderService {
  // Implementation for weather-based reminders
}
```

## Support

For questions or issues related to the reminder services:

1. Check the unit tests for usage examples
2. Review the `REFACTORING_GUIDE.md` for architecture details
3. Consult the individual service documentation
4. Use the analytics data to monitor service performance
