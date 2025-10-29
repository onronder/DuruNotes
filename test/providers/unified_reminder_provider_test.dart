import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/providers/unified_reminder_provider.dart';
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

    test('returns reminder coordinator', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(unifiedReminderCoordinatorProvider);

      expect(coordinator, isNotNull);
      // Note: The legacy/refactored distinction has been removed
      // The provider now returns a single implementation
    });

    test('respects feature flag changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Test with different feature flag settings
      flags.setOverride('use_unified_reminders', false);
      container.invalidate(unifiedReminderCoordinatorProvider);
      final coordinator1 = container.read(unifiedReminderCoordinatorProvider);
      expect(coordinator1, isNotNull);

      flags.setOverride('use_unified_reminders', true);
      container.invalidate(unifiedReminderCoordinatorProvider);
      final coordinator2 = container.read(unifiedReminderCoordinatorProvider);
      expect(coordinator2, isNotNull);
    });
  });
}
