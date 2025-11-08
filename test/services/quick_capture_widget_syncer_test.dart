import 'package:duru_notes/services/quick_capture_widget_syncer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('IosQuickCaptureWidgetSyncer', () {
    late MethodChannel channel;
    late List<MethodCall> calls;

    setUp(() {
      channel = const MethodChannel('test.quick_capture');
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('does nothing when platform check fails', () async {
      final syncer = IosQuickCaptureWidgetSyncer(
        channel: channel,
        platformCheck: () => false,
      );

      await syncer.sync(userId: 'user', payload: {'k': 'v'});
      await syncer.clear();

      expect(calls, isEmpty);
    });

    test('invokes syncWidgetCache with payload', () async {
      final syncer = IosQuickCaptureWidgetSyncer(
        channel: channel,
        platformCheck: () => true,
      );

      await syncer.sync(
        userId: 'user-123',
        payload: {'text': 'Hello'},
      );

      expect(calls.length, 1);
      final call = calls.single;
      expect(call.method, 'syncWidgetCache');
      expect(call.arguments, {
        'userId': 'user-123',
        'payload': {'text': 'Hello'},
      });
    });

    test('invokes clearWidgetCache when clearing', () async {
      final syncer = IosQuickCaptureWidgetSyncer(
        channel: channel,
        platformCheck: () => true,
      );

      await syncer.clear();

      expect(calls.length, 1);
      expect(calls.single.method, 'clearWidgetCache');
    });
  });
}
