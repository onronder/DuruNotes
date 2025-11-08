import 'package:duru_notes/core/bootstrap/app_bootstrap.dart';
import 'package:duru_notes/core/config/environment_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/main.dart';
import 'package:duru_notes/services/analytics/analytics_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const runIntegration = bool.fromEnvironment('RUN_INTEGRATION_TESTS');
  if (!runIntegration) {
    return;
  }

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bootstrap smoke scenarios', () {
    testWidgets('surfaces diagnostics when Supabase client is missing', (
      WidgetTester tester,
    ) async {
      final result = await _buildBootstrapResult(
        requireSupabase: true,
        provideSupabaseClient: false,
      );

      await tester.pumpWidget(
        BootstrapShell(
          result: result,
          navigatorKey: GlobalKey<NavigatorState>(),
          onRetry: () {},
          appBuilder: (_) => const _StubSignedOutShell(),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Supabase credentials were provided but the client failed to initialize.',
        ),
        findsOneWidget,
      );
      expect(find.text('Bootstrap timings'), findsOneWidget);
      expect(find.textContaining('environment:'), findsOneWidget);
      expect(find.textContaining('supabase:'), findsOneWidget);
    });

    testWidgets('renders stub shell when bootstrap succeeds', (
      WidgetTester tester,
    ) async {
      final result = await _buildBootstrapResult(
        requireSupabase: true,
        provideSupabaseClient: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BootstrapHost(
            bootstrapOverride: _FakeBootstrap(result),
            appBuilder: (_) => const _StubSignedOutShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Signed-out shell ready'), findsOneWidget);
      expect(find.text('Bootstrap timings'), findsNothing);
    });
  });
}

Future<BootstrapResult> _buildBootstrapResult({
  required bool requireSupabase,
  required bool provideSupabaseClient,
}) async {
  var environment = EnvironmentConfig.fallback(
    environment: Environment.development,
    debugMode: true,
  );

  if (requireSupabase) {
    environment = environment.copyWith(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'public-anon-key',
    );
  }

  LoggerFactory.initialize(minLevel: LogLevel.debug);
  AnalyticsFactory.reset();
  AnalyticsFactory.configure(
    config: environment,
    logger: LoggerFactory.instance,
  );
  final analytics = await AnalyticsFactory.initialize();

  final supabaseClient =
      provideSupabaseClient && environment.supabaseUrl.isNotEmpty
      ? SupabaseClient(environment.supabaseUrl, environment.supabaseAnonKey)
      : null;

  return BootstrapResult(
    environment: environment,
    logger: LoggerFactory.instance,
    analytics: analytics,
    supabaseClient: supabaseClient,
    firebaseApp: null,
    sentryEnabled: false,
    failures: const [],
    adaptyEnabled: false,
    warnings: const [],
    environmentSource: 'test',
    stageDurations: const {
      BootstrapStage.environment: Duration(milliseconds: 35),
      BootstrapStage.supabase: Duration(milliseconds: 120),
      BootstrapStage.analytics: Duration(milliseconds: 20),
    },
  );
}

class _FakeBootstrap extends AppBootstrap {
  _FakeBootstrap(this._result);
  final BootstrapResult _result;

  @override
  Future<BootstrapResult> initialize() async {
    return _result;
  }
}

class _StubSignedOutShell extends StatelessWidget {
  const _StubSignedOutShell();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Signed-out shell ready')));
  }
}
