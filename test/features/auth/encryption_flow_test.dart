import 'package:duru_notes/app/app.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/features/auth/providers/encryption_state_providers.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/ui/dialogs/encryption_setup_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/security_test_setup.dart';

void main() {
  group('EncryptionStateNotifier', () {
    test('detects not-setup state', () async {
      final mocks = await SecurityTestSetup.setupMockEncryption(
        encryptionEnabled: true,
        isSetup: false,
      );
      final notifier = EncryptionStateNotifier(mocks.encryptionSyncService);
      await notifier.refresh();
      expect(notifier.state.status, EncryptionStatus.notSetup);
      SecurityTestSetup.teardownEncryption();
    });

    test('detects locked state', () async {
      final mocks = await SecurityTestSetup.setupMockEncryption(
        encryptionEnabled: true,
        isSetup: false,
      );
      await mocks.encryptionSyncService.setupEncryption('correct');
      await mocks.encryptionSyncService.clearLocalKeys();

      final notifier = EncryptionStateNotifier(mocks.encryptionSyncService);
      await notifier.refresh();
      expect(notifier.state.status, EncryptionStatus.locked);
      SecurityTestSetup.teardownEncryption();
    });

    test('unlocks with correct password', () async {
      final mocks = await SecurityTestSetup.setupMockEncryption(
        encryptionEnabled: true,
        isSetup: false,
      );
      await mocks.encryptionSyncService.setupEncryption('correct');
      await mocks.encryptionSyncService.clearLocalKeys();

      final notifier = EncryptionStateNotifier(mocks.encryptionSyncService);
      final ok = await notifier.unlockEncryption('correct');
      expect(ok, isTrue);
      expect(notifier.state.status, EncryptionStatus.unlocked);
      SecurityTestSetup.teardownEncryption();
    });

    test('rejects wrong password', () async {
      final mocks = await SecurityTestSetup.setupMockEncryption(
        encryptionEnabled: true,
        isSetup: false,
      );
      await mocks.encryptionSyncService.setupEncryption('correct');
      await mocks.encryptionSyncService.clearLocalKeys();

      final notifier = EncryptionStateNotifier(mocks.encryptionSyncService);
      final ok = await notifier.unlockEncryption('wrong');
      expect(ok, isFalse);
      expect(notifier.state.status, EncryptionStatus.locked);
      SecurityTestSetup.teardownEncryption();
    });
  });

  group('EncryptionSetupDialog', () {
    Future<void> openSetupDialog(
      WidgetTester tester, {
      bool allowCancel = true,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: SecurityTestSetup.createProviderOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showEncryptionSetupDialog(
                    context,
                    allowCancel: allowCancel,
                  );
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('enforces relaxed password policy', (tester) async {
      await tester.setupEncryption(isSetup: false);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openSetupDialog(tester);

      final setupButton =
          find.widgetWithText(FilledButton, 'Setup');
      expect(setupButton, findsOneWidget);
      expect(
        tester.widget<FilledButton>(setupButton).onPressed,
        isNull,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Encryption Password'),
        'Secure!Pass',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'Mismatch!',
      );
      await tester.pump();
      expect(
        tester.widget<FilledButton>(setupButton).onPressed,
        isNull,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'Secure!Pass',
      );
      await tester.pump();
      expect(
        tester.widget<FilledButton>(setupButton).onPressed,
        isNotNull,
      );

      tester.cleanupEncryption();
    });

    testWidgets('hides cancel button when allowCancel=false', (tester) async {
      await tester.setupEncryption(isSetup: false);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await openSetupDialog(tester, allowCancel: false);

      expect(find.text('Cancel'), findsNothing);

      tester.cleanupEncryption();
    });
  });

  group('NewUserEncryptionSetupGate', () {
    testWidgets('completes provisioning after valid submission', (tester) async {
      final mocks = await SecurityTestSetup.setupMockEncryption(
        encryptionEnabled: true,
        isSetup: false,
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      var completed = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...SecurityTestSetup.createProviderOverrides(mocks: mocks),
            loggerProvider.overrideWithValue(const NoOpLogger()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NewUserEncryptionSetupGate(
              onSetupComplete: () => completed = true,
              onSetupCancelled: () async {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Encryption Password'),
        'Secure!Pass',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'Secure!Pass',
      );
      await tester.pump();

      await tester.tap(find.text('Setup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(completed, isTrue);
      SecurityTestSetup.teardownEncryption();
    });
  });
}
