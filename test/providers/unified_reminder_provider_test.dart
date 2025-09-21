import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/providers/unified_reminder_provider.dart';
import 'package:duru_notes/services/reminders/reminder_coordinator.dart'
    as legacy;
import 'package:duru_notes/services/reminders/reminder_coordinator_refactored.dart'
    as refactored;
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('unifiedReminderCoordinatorProvider', () {
    late FeatureFlags flags;

    setUp(() {
      flags = FeatureFlags.instance;
      flags.clearOverrides();
    });

    tearDown(() {
      flags.clearOverrides();
    });

    test('returns refactored coordinator when flag enabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(unifiedReminderCoordinatorProvider);

      expect(coordinator, isA<refactored.ReminderCoordinator>());
    });

    test('returns legacy coordinator when flag disabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      flags.setOverride('use_unified_reminders', false);
      container.invalidate(unifiedReminderCoordinatorProvider);
      final coordinator = container.read(unifiedReminderCoordinatorProvider);

      expect(coordinator, isA<legacy.ReminderCoordinator>());
    });
  });
}
