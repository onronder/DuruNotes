import 'package:flutter_test/flutter_test.dart';

/// Asserts that a provider failure was triggered by environment guards such as
/// missing Supabase initialization or deferred security bootstrap.
void expectInfrastructureGuard(
  Object error, {
  String reason =
      'Should fail due to infrastructure guard (Supabase/security), not null unwrap',
}) {
  expect(
    error.toString(),
    anyOf([
      contains('Supabase'),
      contains('Security services must be initialized'),
      contains('SecurityInitialization'),
      contains('initialize'),
    ]),
    reason: reason,
  );
}
