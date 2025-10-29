import 'package:drift/native.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/infrastructure/repositories/quick_capture_repository.dart';
import 'package:duru_notes/domain/entities/quick_capture_widget_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/security_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickCaptureRepository', () {
    late AppDb db;
    late QuickCaptureRepository repository;

    setUp(() async {
      await SecurityTestSetup.setupMockEncryption();
      db = AppDb.forTesting(NativeDatabase.memory());
      repository = QuickCaptureRepository(
        db: db,
        crypto: SecurityTestSetup.createTestCryptoBox(),
      );
    });

    tearDown(() async {
      await db.close();
      SecurityTestSetup.teardownEncryption();
    });

    test(
      'enqueueCapture stores encrypted payload and retrieves pending captures',
      () async {
        final payload = {
          'text': 'Hello quick capture',
          'tags': ['inbox'],
        };

        await repository.enqueueCapture(
          userId: 'user-1',
          payload: payload,
          platform: 'android',
        );

        final pending = await repository.getPendingCaptures(
          userId: 'user-1',
          limit: 10,
        );

        expect(pending, hasLength(1));
        final item = pending.single;
        expect(item.payload['text'], equals('Hello quick capture'));
        expect(item.platform, equals('android'));
        expect(item.retryCount, equals(0));
        expect(item.processed, isFalse);
      },
    );

    test('markCaptureProcessed removes entry from pending results', () async {
      final entry = await repository.enqueueCapture(
        userId: 'user-2',
        payload: {'text': 'Process me'},
      );

      await repository.markCaptureProcessed(
        id: entry.id,
        processed: true,
        processedAt: DateTime.now().toUtc(),
      );

      final pending = await repository.getPendingCaptures(
        userId: 'user-2',
        limit: 10,
      );
      expect(pending, isEmpty);
    });

    test(
      'clearProcessedCaptures removes processed rows older than cutoff',
      () async {
        final now = DateTime.now().toUtc();
        final entry = await repository.enqueueCapture(
          userId: 'user-3',
          payload: {'text': 'Old capture'},
        );

        await repository.markCaptureProcessed(
          id: entry.id,
          processed: true,
          processedAt: now.subtract(const Duration(days: 10)),
        );

        await repository.clearProcessedCaptures(
          userId: 'user-3',
          olderThan: now.subtract(const Duration(days: 5)),
        );

        final remaining = await db.select(db.quickCaptureQueueEntries).get();
        expect(remaining, isEmpty);
      },
    );

    test('upsertWidgetCache persists encrypted payload', () async {
      final cache = QuickCaptureWidgetCache(
        userId: 'user-4',
        payload: {
          'recentCaptures': [
            {'id': 'n1', 'title': 'Title', 'snippet': 'Snippet'},
          ],
        },
        updatedAt: DateTime.now().toUtc(),
      );

      await repository.upsertWidgetCache(cache);

      final stored = await repository.getWidgetCache('user-4');
      expect(stored, isNotNull);
      expect(stored!.payload['recentCaptures'], isNotEmpty);
    });
  });
}
