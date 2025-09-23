#!/usr/bin/env dart

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:duru_notes/providers/pre_deployment_providers.dart';
import 'package:duru_notes/providers/sync_verification_providers.dart';
import 'package:duru_notes/tools/deployment_validation_test.dart';

/// Standalone script to run deployment validation
///
/// Usage: dart run scripts/run_deployment_validation.dart
Future<void> main(List<String> args) async {
  print('🚀 Duru Notes - Pre-Deployment Validation Script');
  print('=' * 60);
  print('Starting comprehensive validation of Phase 3 deployment readiness...');
  print('');

  try {
    // Create provider container
    final container = ProviderContainer();

    // Initialize providers (this would normally be done by Flutter app initialization)
    print('📋 Initializing validation systems...');

    // Run the comprehensive validation
    final results = await runDeploymentValidationTest(container);

    // Print summary
    final summary = results['summary'] as Map<String, dynamic>? ?? {};
    print('\n🎯 VALIDATION SUMMARY');
    print('=' * 60);
    print('Overall Status: ${summary['overall_health_status'] ?? 'UNKNOWN'}');
    print('Deployment Ready: ${summary['deployment_readiness'] ?? false}');
    print('Health Score: ${((summary['health_score'] ?? 0.0) * 100).toStringAsFixed(1)}%');
    print('Critical Issues: ${summary['total_critical_issues'] ?? 0}');
    print('');

    // Print next steps
    final nextSteps = summary['next_steps'] as List<dynamic>? ?? [];
    if (nextSteps.isNotEmpty) {
      print('📋 NEXT STEPS:');
      for (int i = 0; i < nextSteps.length; i++) {
        print('${i + 1}. ${nextSteps[i]}');
      }
    }

    print('\n📄 Detailed report saved to: docs/deployment_baseline_report.json');

    // Set exit code based on results
    final isHealthy = summary['overall_health_status'] == 'HEALTHY';
    exit(isHealthy ? 0 : 1);

  } catch (error, stackTrace) {
    print('❌ Validation failed with error:');
    print('Error: $error');
    print('Stack trace: $stackTrace');
    exit(2);
  }
}