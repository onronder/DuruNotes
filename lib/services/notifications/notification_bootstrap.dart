import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Ensures [FlutterLocalNotificationsPlugin] is ready before scheduling.
///
/// Multiple call sites across the app construct their own plugin instances,
/// so this helper centralises initialization tasks (timezone data, platform
/// settings, and channel bootstrap) to avoid subtle races where `zonedSchedule`
/// is invoked before `initialize` runs.
class NotificationBootstrap {
  NotificationBootstrap._();

  static bool _timezoneInitialized = false;
  static bool _localLocationResolved = false;
  static Completer<void>? _initializing;
  static final Set<FlutterLocalNotificationsPlugin> _initializedPlugins =
      <FlutterLocalNotificationsPlugin>{};

  /// Idempotent initialization for the provided [plugin].
  static Future<void> ensureInitialized(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    if (_initializedPlugins.contains(plugin)) return;

    // Serialise concurrent initialization attempts.
    if (_initializing != null) {
      await _initializing!.future;
      _initializedPlugins.add(plugin);
      return;
    }

    final completer = Completer<void>();
    _initializing = completer;

    try {
      await _ensureTimezoneReady();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await plugin.initialize(initializationSettings);
      _initializedPlugins.add(plugin);
      completer.complete();
    } catch (error, stack) {
      completer.completeError(error, stack);
      rethrow;
    } finally {
      _initializing = null;
    }
  }

  static Future<void> _ensureTimezoneReady() async {
    if (!_timezoneInitialized) {
      tzdata.initializeTimeZones();
      _timezoneInitialized = true;
    }

    if (_localLocationResolved) return;

    try {
      final resolvedTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(resolvedTimezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } finally {
      _localLocationResolved = true;
    }
  }
}
