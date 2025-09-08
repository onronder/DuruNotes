#!/usr/bin/env dart
/// Test runner script for encryption and indexing verification tests
/// 
/// This script runs comprehensive tests to verify that:
/// 1. ImportService properly calls NotesRepository.createOrUpdate
/// 2. ImportService properly calls NoteIndexer.indexNote  
/// 3. Notes are encrypted when stored in the database
/// 4. Notes are properly indexed for search functionality
/// 
/// Usage:
///   dart test/run_encryption_indexing_tests.dart
///   
/// Or run individual test files:
///   flutter test test/services/import_encryption_indexing_test.dart
///   flutter test integration_test/import_encryption_indexing_test.dart

import 'dart:io';

void main(List<String> args) async {
  print('🔐 Running Encryption & Indexing Verification Tests');
  print('=' * 60);
  
  final testResults = <String, bool>{};
  
  // Run unit tests
  print('\n📋 Running Unit Tests...');
  final unitTestResult = await runProcess([
    'flutter', 'test', 
    'test/services/import_encryption_indexing_test.dart',
    '--reporter=expanded'
  ]);
  testResults['Unit Tests'] = unitTestResult;
  
  // Run integration tests
  print('\n🔗 Running Integration Tests...');
  final integrationTestResult = await runProcess([
    'flutter', 'test', 
    'integration_test/import_encryption_indexing_test.dart',
    '--reporter=expanded'
  ]);
  testResults['Integration Tests'] = integrationTestResult;
  
  // Print summary
  print('\n📊 Test Results Summary');
  print('=' * 60);
  
  var allPassed = true;
  for (final entry in testResults.entries) {
    final status = entry.value ? '✅ PASSED' : '❌ FAILED';
    print('${entry.key}: $status');
    if (!entry.value) allPassed = false;
  }
  
  print('\n${'=' * 60}');
  if (allPassed) {
    print('🎉 All encryption and indexing tests PASSED!');
    print('✅ ImportService properly integrates with NotesRepository and NoteIndexer');
    print('✅ Notes are encrypted when stored');
    print('✅ Notes are properly indexed for search');
    exit(0);
  } else {
    print('💥 Some tests FAILED!');
    print('❌ Check the test output above for details');
    exit(1);
  }
}

Future<bool> runProcess(List<String> command) async {
  print('Running: ${command.join(' ')}');
  
  final process = await Process.start(
    command.first,
    command.skip(1).toList(),
    mode: ProcessStartMode.inheritStdio,
  );
  
  final exitCode = await process.exitCode;
  final success = exitCode == 0;
  
  if (success) {
    print('✅ Command completed successfully');
  } else {
    print('❌ Command failed with exit code: $exitCode');
  }
  
  return success;
}
