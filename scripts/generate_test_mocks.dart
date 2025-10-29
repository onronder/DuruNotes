/// Script to generate Mockito mocks for critical tests
///
/// Run: dart run scripts/generate_test_mocks.dart
library;

import 'dart:io';

void main() async {
  print('🔧 Generating Mockito mocks for critical tests...\n');

  // List of test files that need mock generation
  final testFiles = [
    'test/critical/user_isolation_test.dart',
    'test/critical/user_id_validation_test.dart',
    'test/critical/encryption_integrity_test.dart',
    'test/critical/rls_enforcement_test.dart',
  ];

  print('📦 Running build_runner to generate mocks...');

  // Run build_runner
  final result = await Process.run(
    'flutter',
    ['pub', 'run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    runInShell: true,
  );

  if (result.exitCode == 0) {
    print('✅ Mocks generated successfully!\n');

    // List generated mock files
    print('📁 Generated mock files:');
    for (final testFile in testFiles) {
      final mockFile = testFile.replaceAll('.dart', '.mocks.dart');
      if (await File(mockFile).exists()) {
        print('  ✓ $mockFile');
      } else {
        print('  ⚠ $mockFile (not found - may not need mocks)');
      }
    }
  } else {
    print('❌ Failed to generate mocks');
    print('Error: ${result.stderr}');
    exit(1);
  }

  print('\n✨ Mock generation complete!');
  print('You can now run the tests with: ./scripts/run_critical_tests.sh');
}