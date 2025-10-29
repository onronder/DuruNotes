/* COMMENTED OUT - 24 errors - uses old APIs
 * This script uses old models/APIs that no longer exist.
 * Needs rewrite to use new architecture.
 */

/*
#!/usr/bin/env dart
/// Production-grade CLI tool for running data encryption migration
///
/// Usage:
///   dart run scripts/run_encryption_migration.dart [options]
///
/// Options:
///   --dry-run              Run migration in dry-run mode (no changes made)
///   --skip-backup          Skip automatic database backup
///   --skip-validation      Skip pre/post migration validation
///   --batch-size <n>       Set batch size (default: 100)
///   --user-id <id>         User ID for encryption (required)
///   --verbose              Enable verbose logging
///   --help                 Show this help message
///
/// Examples:
///   # Dry run to see what would be migrated
///   dart run scripts/run_encryption_migration.dart --dry-run --user-id abc123
///
///   # Production migration with all safety features
///   dart run scripts/run_encryption_migration.dart --user-id abc123
///
///   # Fast migration with custom batch size
///   dart run scripts/run_encryption_migration.dart --user-id abc123 --batch-size 500

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/services/data_encryption_migration_service.dart';
import 'package:duru_notes/services/fts_service.dart';
import 'package:drift/native.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('dry-run',
        abbr: 'd',
        negatable: false,
        help: 'Run in dry-run mode (no changes made)')
    ..addFlag('skip-backup',
        negatable: false,
        help: 'Skip automatic database backup')
    ..addFlag('skip-validation',
        negatable: false,
        help: 'Skip pre/post migration validation')
    ..addOption('batch-size',
        abbr: 'b', defaultsTo: '100', help: 'Batch size for processing')
    ..addOption('user-id',
        abbr: 'u', mandatory: true, help: 'User ID for encryption (required)')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Enable verbose logging')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help message');

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _printUsage(parser);
      exit(0);
    }

    final dryRun = results['dry-run'] as bool;
    final skipBackup = results['skip-backup'] as bool;
    final skipValidation = results['skip-validation'] as bool;
    final batchSize = int.parse(results['batch-size'] as String);
    final userId = results['user-id'] as String;
    final verbose = results['verbose'] as bool;

    // Print configuration
    print('╔════════════════════════════════════════════════════════════════╗');
    print('║        Duru Notes - Data Encryption Migration Tool            ║');
    print('╚════════════════════════════════════════════════════════════════╝');
    print('');
    print('Configuration:');
    print('  Mode: ${dryRun ? 'DRY RUN (no changes)' : 'PRODUCTION (will modify data)'}');
    print('  User ID: $userId');
    print('  Batch Size: $batchSize');
    print('  Backup: ${skipBackup ? 'SKIP' : 'CREATE'}');
    print('  Validation: ${skipValidation ? 'SKIP' : 'RUN'}');
    print('  Logging: ${verbose ? 'VERBOSE' : 'NORMAL'}');
    print('');

    if (!dryRun) {
      print('⚠️  WARNING: This will modify your database!');
      print('');
      print('This migration will:');
      print('  1. Encrypt all plaintext notes and tasks');
      print('  2. Clear plaintext columns for security');
      print('  3. Rebuild FTS indexes');
      print('');
      print('Press Enter to continue, or Ctrl+C to cancel...');
      stdin.readLineSync();
      print('');
    }

    // Initialize app
    print('📦 Initializing application...');
    final logger = LoggerFactory.instance;

    // Create in-memory database for testing
    // TODO: In production, use actual database path
    final db = AppDb(NativeDatabase.memory());
    final crypto = await CryptoBox.create();
    final ftsService = FtsService(db: db);

    print('✓ Application initialized');
    print('');

    // Create migration service
    final migrationService = DataEncryptionMigrationService(
      db: db,
      crypto: crypto,
      ftsService: ftsService,
      batchSize: batchSize,
    );

    // Run migration
    print('🚀 Starting migration...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');

    String? lastPhase;
    final result = await migrationService.executeMigration(
      userId: userId,
      dryRun: dryRun,
      skipBackup: skipBackup,
      skipValidation: skipValidation,
      onProgress: (progress) {
        if (progress.phase != lastPhase) {
          print('');
          print('Phase: ${progress.phase.toUpperCase()}');
          lastPhase = progress.phase;
        }

        final bar = _createProgressBar(progress.progress, width: 40);
        final eta = progress.estimatedTimeRemaining != null
            ? ' ETA: ${_formatDuration(progress.estimatedTimeRemaining!)}'
            : '';

        stdout.write('\r  $bar ${progress.percentComplete}% '
            '(${progress.processed}/${progress.total})$eta');

        if (progress.processed == progress.total) {
          print(''); // New line after completion
          print('  ✓ Success: ${progress.successCount}, Failed: ${progress.failureCount}');
        }
      },
    );

    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');

    // Print results
    _printResults(result);

    // Clean up
    await db.close();

    // Exit with appropriate code
    exit(result.isSuccess ? 0 : 1);
  } on FormatException catch (e) {
    print('Error: ${e.message}');
    print('');
    _printUsage(parser);
    exit(1);
  } catch (e, stack) {
    print('Fatal error: $e');
    if (verbose) {
      print('Stack trace:');
      print(stack);
    }
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  print('Usage: dart run scripts/run_encryption_migration.dart [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  # Dry run');
  print('  dart run scripts/run_encryption_migration.dart --dry-run --user-id abc123');
  print('');
  print('  # Production migration');
  print('  dart run scripts/run_encryption_migration.dart --user-id abc123');
}

void _printResults(MigrationResult result) {
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║                     Migration Results                          ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('');
  print('Status: ${_getStatusEmoji(result.status)} ${result.status.toString().split('.').last.toUpperCase()}');
  print('Duration: ${_formatDuration(result.duration)}');
  print('');

  if (result.validationResult != null) {
    final val = result.validationResult!;
    print('Pre-Migration Validation:');
    print('  Can Proceed: ${val.canProceed ? '✓' : '✗'}');
    print('  Items to Migrate: ${val.itemsToMigrate}');
    if (val.warnings.isNotEmpty) {
      print('  Warnings: ${val.warnings.length}');
      for (final warning in val.warnings.take(3)) {
        print('    ⚠️  $warning');
      }
    }
    if (val.errors.isNotEmpty) {
      print('  Errors: ${val.errors.length}');
      for (final error in val.errors.take(3)) {
        print('    ❌ $error');
      }
    }
    print('');
  }

  if (result.backupPath != null) {
    print('Backup:');
    print('  Path: ${result.backupPath}');
    print('  ℹ️  Keep this backup until migration is verified');
    print('');
  }

  if (result.notesResult != null) {
    final notes = result.notesResult!;
    print('Notes Migration:');
    print('  Total: ${notes.totalCount}');
    print('  Successful: ${notes.successCount} (${(notes.successRate * 100).toStringAsFixed(1)}%)');
    print('  Failed: ${notes.failureCount}');
    if (notes.errors.isNotEmpty) {
      print('  First Errors:');
      for (final error in notes.errors.take(3)) {
        print('    ❌ $error');
      }
    }
    print('');
  }

  if (result.tasksResult != null) {
    final tasks = result.tasksResult!;
    print('Tasks Migration:');
    print('  Total: ${tasks.totalCount}');
    print('  Successful: ${tasks.successCount} (${(tasks.successRate * 100).toStringAsFixed(1)}%)');
    print('  Failed: ${tasks.failureCount}');
    if (tasks.errors.isNotEmpty) {
      print('  First Errors:');
      for (final error in tasks.errors.take(3)) {
        print('    ❌ $error');
      }
    }
    print('');
  }

  if (result.ftsResult != null) {
    final fts = result.ftsResult!;
    print('FTS Rebuild:');
    print('  Notes Reindexed: ${fts.notesReindexed}');
    print('  Failed: ${fts.notesFailed}');
    print('  Integrity Check: ${fts.integrityCheck ? '✓ PASS' : '✗ FAIL'}');
    if (fts.error != null) {
      print('  Error: ${fts.error}');
    }
    print('');
  }

  if (result.verificationResult != null) {
    final ver = result.verificationResult!;
    print('Post-Migration Verification:');
    print('  Success: ${ver.success ? '✓' : '✗'}');
    if (ver.warnings.isNotEmpty) {
      print('  Warnings: ${ver.warnings.length}');
      for (final warning in ver.warnings.take(3)) {
        print('    ⚠️  $warning');
      }
    }
    if (ver.errors.isNotEmpty) {
      print('  Errors: ${ver.errors.length}');
      for (final error in ver.errors.take(3)) {
        print('    ❌ $error');
      }
    }
    print('');
  }

  print('Summary:');
  print('  Total Migrated: ${result.totalSuccessful}');
  print('  Total Failed: ${result.totalFailures}');
  print('');

  if (result.isSuccess) {
    print('✅ Migration completed successfully!');
    if (result.dryRun) {
      print('ℹ️  This was a dry run. No changes were made.');
      print('   Run without --dry-run to execute the migration.');
    }
  } else {
    print('❌ Migration failed!');
    if (result.fatalError != null) {
      print('   Fatal error: ${result.fatalError}');
    }
    if (result.backupPath != null) {
      print('   Restore from backup: ${result.backupPath}');
    }
  }
}

String _createProgressBar(double progress, {int width = 40}) {
  final completed = (progress * width).round();
  final remaining = width - completed;
  return '[${'█' * completed}${'░' * remaining}]';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m ${seconds}s';
  } else if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  } else {
    return '${seconds}s';
  }
}

String _getStatusEmoji(MigrationStatus status) {
  switch (status) {
    case MigrationStatus.success:
    case MigrationStatus.dryRunComplete:
      return '✅';
    case MigrationStatus.validationFailed:
    case MigrationStatus.verificationFailed:
      return '⚠️';
    case MigrationStatus.failed:
      return '❌';
    case MigrationStatus.inProgress:
      return '⏳';
  }
}

*/
