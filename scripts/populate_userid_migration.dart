#!/usr/bin/env dart

import 'dart:io';

import 'package:args/args.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/migrations/migration_25_security_userid_population.dart';
import 'package:duru_notes/data/migrations/migration_33_pending_ops_userid.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const bool _envStatus = bool.fromEnvironment(
  'POPULATE_USERID_STATUS',
  defaultValue: false,
);
const bool _envValidate = bool.fromEnvironment(
  'POPULATE_USERID_VALIDATE',
  defaultValue: false,
);
const String _envUserId = String.fromEnvironment(
  'POPULATE_USERID_VALUE',
  defaultValue: '',
);
const bool _envForce = bool.fromEnvironment(
  'POPULATE_USERID_FORCE',
  defaultValue: false,
);
const String _envDatabase = String.fromEnvironment(
  'POPULATE_USERID_DATABASE',
  defaultValue: '',
);

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();

  final parser = ArgParser()
    ..addOption(
      'user-id',
      abbr: 'u',
      help: 'Assign this userId to data that is currently missing ownership.',
    )
    ..addFlag(
      'status',
      abbr: 's',
      help: 'Show current userId population status.',
      negatable: false,
    )
    ..addFlag(
      'validate',
      abbr: 'v',
      help: 'Verify that all required tables have userId populated.',
      negatable: false,
    )
    ..addFlag(
      'force',
      abbr: 'f',
      help: 'Apply changes (disables dry-run when used with --user-id).',
      negatable: false,
    )
    ..addOption(
      'database',
      abbr: 'd',
      help: 'Path to the SQLite database (defaults to ./duru.db).',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Display usage information.',
      negatable: false,
    );

  late final ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (error) {
    _printUsage(parser, error: error.toString());
    exit(64);
  }

  final bool statusRequested = args.arguments.isEmpty
      ? _envStatus
      : (args['status'] as bool);
  final bool validateRequested = args.arguments.isEmpty
      ? _envValidate
      : (args['validate'] as bool);
  final String? userIdArgument = args.arguments.isEmpty
      ? (_envUserId.isEmpty ? null : _envUserId)
      : (args['user-id'] as String?);
  final bool forceWrite = args.arguments.isEmpty
      ? _envForce
      : (args['force'] as bool);
  final String? databaseOverride = args.arguments.isEmpty
      ? (_envDatabase.isEmpty ? null : _envDatabase)
      : (args['database'] as String?);

  if ((args['help'] as bool) && args.arguments.isNotEmpty) {
    _printUsage(parser);
    exit(0);
  }

  final dbPath = _resolveDatabasePath(databaseOverride);
  if (!File(dbPath).existsSync()) {
    stderr.writeln('❌ Database not found: $dbPath');
    exit(66);
  }

  print('📁 Using database: $dbPath');
  print(
    'Resolved options → status:$statusRequested, validate:$validateRequested, userId:${userIdArgument ?? "<none>"}, force:$forceWrite',
  );

  _ensureSchemaVersion(dbPath);

  final db = AppDb.forTesting(
    NativeDatabase(File(dbPath), logStatements: false),
  );
  final guide = UserIdPopulationGuide(db);

  try {
    if (statusRequested) {
      await guide.printStatus();
      exit(0);
    }

    if (validateRequested) {
      final valid = await guide.validatePopulation();
      exit(valid ? 0 : 1);
    }

    if (userIdArgument != null && userIdArgument.isNotEmpty) {
      final isDryRun = !forceWrite;
      await guide.populateSingleUser(userId: userIdArgument, dryRun: isDryRun);
      exit(0);
    }

    _printUsage(
      parser,
      error: 'No action specified. Use --status, --validate, or --user-id.',
    );
    exit(64);
  } finally {
    await db.close();
  }
}

void _printUsage(ArgParser parser, {String? error}) {
  if (error != null) {
    stderr.writeln('Error: $error\n');
  }
  print('UserId Population Utility');
  print('-------------------------');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  dart run scripts/populate_userid_migration.dart --status');
  print(
    '  dart run scripts/populate_userid_migration.dart --user-id=abc --force',
  );
  print(
    '  dart run scripts/populate_userid_migration.dart --validate --database=/path/to/duru.db',
  );
}

String _resolveDatabasePath(String? override) {
  if (override != null && override.isNotEmpty) {
    return override;
  }
  final cwd = Directory.current.path;
  final defaultPath = p.join(cwd, 'duru.db');
  if (File(defaultPath).existsSync()) {
    return defaultPath;
  }
  final fallback = p.join(cwd, 'build', 'duru.db');
  return fallback;
}

void _ensureSchemaVersion(String dbPath) {
  final raw = sqlite.sqlite3.open(dbPath);
  try {
    final versionResult = raw.select('PRAGMA user_version');
    final currentVersion = versionResult.first.columnAt(0) as int? ?? 0;
    if (currentVersion == 0) {
      raw.execute('PRAGMA user_version = 33');
    }
  } finally {
    raw.dispose();
  }
}

class UserIdPopulationGuide {
  UserIdPopulationGuide(this.db);

  final AppDb db;

  Future<void> printStatus() async {
    final stats = await _collectStats();

    print('');
    print('📊 UserId Population Status');
    print('---------------------------');
    print(
      'Folders            : ${stats.foldersWithUserId}/${stats.totalFolders} populated',
    );
    print(
      'Templates          : ${stats.userTemplatesWithUserId}/${stats.totalTemplates - stats.systemTemplates} user templates populated',
    );
    print('System templates   : ${stats.systemTemplates} (always no userId)');
    print(
      'Pending ops        : ${stats.pendingOpsPopulated}/${stats.totalPendingOps} populated',
    );
    if (stats.pendingOpsMismatched > 0) {
      print(
        '⚠️  Pending ops with mismatched ownership: ${stats.pendingOpsMismatched}',
      );
    }
    if (stats.pendingOpsOrphans > 0) {
      print(
        '⚠️  Pending ops referencing unknown entities: ${stats.pendingOpsOrphans}',
      );
    }
    print('');
  }

  Future<bool> validatePopulation() async {
    final stats = await _collectStats();
    final foldersOk = stats.foldersWithoutUserId == 0;
    final templatesOk = stats.userTemplatesWithoutUserId == 0;
    final pendingOpsOk =
        stats.pendingOpsMissingUserId == 0 && stats.pendingOpsMismatched == 0;

    if (foldersOk && templatesOk && pendingOpsOk) {
      print('✅ All required tables have userId populated.');
      return true;
    }

    print('❌ Validation failed:');
    if (!foldersOk) {
      print('   - ${stats.foldersWithoutUserId} folders without userId');
    }
    if (!templatesOk) {
      print(
        '   - ${stats.userTemplatesWithoutUserId} user templates without userId',
      );
    }
    if (!pendingOpsOk) {
      print('   - ${stats.pendingOpsMissingUserId} pending ops missing userId');
      if (stats.pendingOpsMismatched > 0) {
        print(
          '   - ${stats.pendingOpsMismatched} pending ops have mismatched user ownership',
        );
      }
    }
    return false;
  }

  Future<void> populateSingleUser({
    required String userId,
    required bool dryRun,
  }) async {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }

    print('');
    print('👤 Target user    : $userId');
    print(
      '🔧 Mode           : ${dryRun ? "DRY-RUN (no changes)" : "APPLY CHANGES"}',
    );
    print('');

    final statsBefore = await _collectStats();

    if (dryRun) {
      print('Dry-run only. No changes will be applied.');
      print('');
      _printDeltaSummary(before: statsBefore, after: statsBefore);
      return;
    }

    await db.transaction(() async {
      await Migration25SecurityUserIdPopulation.populateUserIdForSingleUser(
        db,
        userId,
      );
      await _populatePendingOpsUserId(userId);
    });

    final statsAfter = await _collectStats();
    _printDeltaSummary(before: statsBefore, after: statsAfter);
  }

  Future<void> _populatePendingOpsUserId(String userId) async {
    // Ensure the schema is up-to-date and the column exists.
    await Migration33PendingOpsUserId.run(db);

    // Align pending ops userId with owning entities when available.
    await db.customStatement('''
      UPDATE pending_ops
      SET user_id = (
        SELECT user_id FROM local_notes WHERE local_notes.id = pending_ops.entity_id
      )
      WHERE (kind LIKE 'upsert_note%' OR kind LIKE 'delete_note%')
        AND EXISTS (SELECT 1 FROM local_notes WHERE local_notes.id = pending_ops.entity_id)
      ''');

    await db.customStatement('''
      UPDATE pending_ops
      SET user_id = (
        SELECT user_id FROM local_folders WHERE local_folders.id = pending_ops.entity_id
      )
      WHERE (kind LIKE 'upsert_folder%' OR kind LIKE 'delete_folder%')
        AND EXISTS (SELECT 1 FROM local_folders WHERE local_folders.id = pending_ops.entity_id)
      ''');

    await db.customStatement('''
      UPDATE pending_ops
      SET user_id = (
        SELECT user_id FROM attachments WHERE attachments.id = pending_ops.entity_id
      )
      WHERE kind LIKE 'upsert_attachment%'
        AND EXISTS (SELECT 1 FROM attachments WHERE attachments.id = pending_ops.entity_id)
      ''');

    await db.customStatement('''
      UPDATE pending_ops
      SET user_id = (
        SELECT user_id FROM local_templates WHERE local_templates.id = pending_ops.entity_id
      )
      WHERE kind LIKE 'upsert_template%'
        AND EXISTS (SELECT 1 FROM local_templates WHERE local_templates.id = pending_ops.entity_id)
      ''');

    await db.customStatement('''
      UPDATE pending_ops
      SET user_id = (
        SELECT user_id FROM saved_searches WHERE saved_searches.id = pending_ops.entity_id
      )
      WHERE kind LIKE 'upsert_saved_search%'
        AND EXISTS (SELECT 1 FROM saved_searches WHERE saved_searches.id = pending_ops.entity_id)
      ''');

    // Fallback: Assign current userId where we still have blanks.
    await db.customStatement(
      '''
      UPDATE pending_ops
      SET user_id = ?
      WHERE user_id IS NULL OR user_id = ''
      ''',
      [userId],
    );
  }

  Future<_PopulationStats> _collectStats() async {
    final folderStats =
        await Migration25SecurityUserIdPopulation.getUserIdPopulationStats(db);

    final pendingStats = await db.customSelect('''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN user_id IS NULL OR user_id = '' THEN 1 ELSE 0 END) AS missing
      FROM pending_ops
      ''').getSingle();

    final mismatchedNotes = await db.customSelect('''
      SELECT COUNT(*) AS mismatched
      FROM pending_ops p
      JOIN local_notes n ON n.id = p.entity_id
      WHERE (p.kind LIKE 'upsert_note%' OR p.kind LIKE 'delete_note%')
        AND n.user_id IS NOT NULL
        AND n.user_id != p.user_id
      ''').getSingle();

    final mismatchedFolders = await db.customSelect('''
      SELECT COUNT(*) AS mismatched
      FROM pending_ops p
      JOIN local_folders f ON f.id = p.entity_id
      WHERE (p.kind LIKE 'upsert_folder%' OR p.kind LIKE 'delete_folder%')
        AND f.user_id IS NOT NULL
        AND f.user_id != p.user_id
      ''').getSingle();

    final mismatchedAttachments = await db.customSelect('''
      SELECT COUNT(*) AS mismatched
      FROM pending_ops p
      JOIN attachments a ON a.id = p.entity_id
      WHERE p.kind LIKE 'upsert_attachment%'
        AND a.user_id IS NOT NULL
        AND a.user_id != p.user_id
      ''').getSingle();

    final mismatchedTemplates = await db.customSelect('''
      SELECT COUNT(*) AS mismatched
      FROM pending_ops p
      JOIN local_templates t ON t.id = p.entity_id
      WHERE p.kind LIKE 'upsert_template%'
        AND t.user_id IS NOT NULL
        AND t.user_id != p.user_id
      ''').getSingle();

    final mismatchedSavedSearches = await db.customSelect('''
      SELECT COUNT(*) AS mismatched
      FROM pending_ops p
      JOIN saved_searches s ON s.id = p.entity_id
      WHERE p.kind LIKE 'upsert_saved_search%'
        AND s.user_id IS NOT NULL
        AND s.user_id != p.user_id
      ''').getSingle();

    final orphanOps = await db.customSelect('''
      SELECT COUNT(*) AS orphaned
      FROM pending_ops p
      LEFT JOIN local_notes n ON n.id = p.entity_id
      LEFT JOIN local_folders f ON f.id = p.entity_id
      LEFT JOIN attachments a ON a.id = p.entity_id
      LEFT JOIN local_templates t ON t.id = p.entity_id
      LEFT JOIN saved_searches s ON s.id = p.entity_id
      WHERE n.id IS NULL
        AND f.id IS NULL
        AND a.id IS NULL
        AND t.id IS NULL
        AND s.id IS NULL
      ''').getSingle();

    final totalPendingOps = pendingStats.readNullable<int>('total') ?? 0;
    final pendingMissing = pendingStats.readNullable<int>('missing') ?? 0;
    final pendingMismatched =
        (mismatchedNotes.readNullable<int>('mismatched') ?? 0) +
        (mismatchedFolders.readNullable<int>('mismatched') ?? 0) +
        (mismatchedAttachments.readNullable<int>('mismatched') ?? 0) +
        (mismatchedTemplates.readNullable<int>('mismatched') ?? 0) +
        (mismatchedSavedSearches.readNullable<int>('mismatched') ?? 0);
    final pendingOrphans = orphanOps.readNullable<int>('orphaned') ?? 0;

    return _PopulationStats(
      totalFolders: folderStats['totalFolders'] ?? 0,
      foldersWithUserId: folderStats['foldersWithUserId'] ?? 0,
      foldersWithoutUserId: folderStats['foldersWithoutUserId'] ?? 0,
      totalTemplates: folderStats['totalTemplates'] ?? 0,
      systemTemplates: folderStats['systemTemplates'] ?? 0,
      userTemplatesWithUserId: folderStats['userTemplatesWithUserId'] ?? 0,
      userTemplatesWithoutUserId:
          folderStats['userTemplatesWithoutUserId'] ?? 0,
      totalPendingOps: totalPendingOps,
      pendingOpsMissingUserId: pendingMissing,
      pendingOpsMismatched: pendingMismatched,
      pendingOpsOrphans: pendingOrphans,
    );
  }

  void _printDeltaSummary({
    required _PopulationStats before,
    required _PopulationStats after,
  }) {
    print('');
    print('📈 Population Summary');
    print('---------------------');
    print(
      'Folders            : ${before.foldersWithUserId} → ${after.foldersWithUserId} populated',
    );
    print(
      'User templates     : ${before.userTemplatesWithUserId} → ${after.userTemplatesWithUserId} populated',
    );
    print(
      'Pending ops        : ${before.pendingOpsPopulated} → ${after.pendingOpsPopulated} populated',
    );
    if (after.pendingOpsMismatched > 0) {
      print(
        '⚠️  Pending ops with mismatched ownership: ${after.pendingOpsMismatched}',
      );
    }
    if (after.pendingOpsOrphans > 0) {
      print(
        '⚠️  Pending ops referencing unknown entities: ${after.pendingOpsOrphans}',
      );
    }
    print('');
  }
}

class _PopulationStats {
  _PopulationStats({
    required this.totalFolders,
    required this.foldersWithUserId,
    required this.foldersWithoutUserId,
    required this.totalTemplates,
    required this.systemTemplates,
    required this.userTemplatesWithUserId,
    required this.userTemplatesWithoutUserId,
    required this.totalPendingOps,
    required this.pendingOpsMissingUserId,
    required this.pendingOpsMismatched,
    required this.pendingOpsOrphans,
  });

  final int totalFolders;
  final int foldersWithUserId;
  final int foldersWithoutUserId;

  final int totalTemplates;
  final int systemTemplates;
  final int userTemplatesWithUserId;
  final int userTemplatesWithoutUserId;

  final int totalPendingOps;
  final int pendingOpsMissingUserId;
  final int pendingOpsMismatched;
  final int pendingOpsOrphans;

  int get totalUserTemplates => totalTemplates - systemTemplates;
  int get pendingOpsPopulated => totalPendingOps - pendingOpsMissingUserId;
}
