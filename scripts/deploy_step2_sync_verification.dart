#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'package:duru_notes/data/local/app_db.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const bool _envJsonEnabled = bool.fromEnvironment(
  'PENDING_OPS_JSON',
  defaultValue: false,
);
const String _envJsonOutput = String.fromEnvironment(
  'PENDING_OPS_JSON_PATH',
  defaultValue: '',
);
const String _envDatabaseOverride = String.fromEnvironment(
  'PENDING_OPS_DATABASE',
  defaultValue: '',
);

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();

  final parser = ArgParser()
    ..addOption(
      'database',
      abbr: 'd',
      help: 'Path to the SQLite database (defaults to ./duru.db).',
    )
    ..addFlag(
      'json',
      help: 'Output report as JSON (in addition to console output).',
      negatable: false,
    )
    ..addOption(
      'json-output',
      help: 'File path to save the JSON report (requires --json).',
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

  final bool jsonRequested = args.arguments.isEmpty
      ? _envJsonEnabled
      : (args['json'] as bool);
  final String? jsonOutputPath = args.arguments.isEmpty
      ? (_envJsonOutput.isEmpty ? null : _envJsonOutput)
      : (args['json-output'] as String?);
  final String? databaseOverride = args.arguments.isEmpty
      ? (_envDatabaseOverride.isEmpty ? null : _envDatabaseOverride)
      : (args['database'] as String?);

  // Debug: show final configuration used by the script.
  print(
    'Resolved options → json:$jsonRequested, output:${jsonOutputPath ?? "<none>"}, database:${databaseOverride ?? "<default>"}',
  );

  if ((args['help'] as bool) && args.arguments.isNotEmpty) {
    _printUsage(parser);
    exit(0);
  }

  final dbPath = _resolveDatabasePath(databaseOverride);
  if (!File(dbPath).existsSync()) {
    stderr.writeln('❌ Database not found: $dbPath');
    exit(66);
  }

  print('🔍 Running Step 2 sync verification checks');
  print('📁 Database: $dbPath');
  print('');

  _ensureSchemaVersion(dbPath);

  final db = AppDb.forTesting(
    NativeDatabase(File(dbPath), logStatements: false),
  );

  bool isHealthy = true;
  try {
    final report = await _runPendingOpsAudit(db);
    _printReport(report);

    if (jsonRequested) {
      final jsonPayload = jsonEncode(report.toJson());
      if (jsonOutputPath != null && jsonOutputPath.isNotEmpty) {
        final file = File(jsonOutputPath);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonPayload);
        print('📝 JSON report saved to $jsonOutputPath');
      } else {
        print('');
        print(jsonPayload);
      }
    }

    isHealthy = report.isHealthy;
  } finally {
    await db.close();
  }

  exit(isHealthy ? 0 : 1);
}

void _printUsage(ArgParser parser, {String? error}) {
  if (error != null) {
    stderr.writeln('Error: $error\n');
  }
  print('Step 2 Sync Verification Utility');
  print('--------------------------------');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  dart run scripts/deploy_step2_sync_verification.dart');
  print(
    '  dart run scripts/deploy_step2_sync_verification.dart --json --json-output=reports/step2.json',
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
  return p.join(cwd, 'build', 'duru.db');
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

Future<_PendingOpsReport> _runPendingOpsAudit(AppDb db) async {
  final columnCheck = await db
      .customSelect("SELECT name FROM pragma_table_info('pending_ops')")
      .get();
  final hasUserIdColumn = columnCheck.any(
    (row) =>
        (row.readNullable<String>('name') ?? '').toLowerCase() == 'user_id',
  );

  if (!hasUserIdColumn) {
    return _PendingOpsReport(
      hasUserIdColumn: false,
      total: 0,
      missingUserId: 0,
      mismatchedOwnership: 0,
      orphaned: 0,
    );
  }

  final totals = await db.customSelect('''
    SELECT
      COUNT(*) AS total,
      SUM(CASE WHEN user_id IS NULL OR user_id = '' THEN 1 ELSE 0 END) AS missing
    FROM pending_ops
    ''').getSingle();

  final mismatched = await db.customSelect('''
    SELECT COUNT(*) AS mismatched
    FROM pending_ops p
    LEFT JOIN (
      SELECT id, user_id FROM local_notes
      UNION ALL
      SELECT id, user_id FROM local_folders
      UNION ALL
      SELECT id, user_id FROM attachments
      UNION ALL
      SELECT id, user_id FROM local_templates
      UNION ALL
      SELECT id, user_id FROM saved_searches
    ) entity_owner
      ON entity_owner.id = p.entity_id
    WHERE entity_owner.user_id IS NOT NULL
      AND entity_owner.user_id <> p.user_id
  ''').getSingle();

  final mismatchedCount = mismatched.readNullable<int>('mismatched') ?? 0;

  final orphaned = await db.customSelect('''
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

  final missingDetails = await db.customSelect('''
    SELECT id, kind, entity_id, created_at
    FROM pending_ops
    WHERE user_id IS NULL OR user_id = ''
    ORDER BY created_at ASC
    LIMIT 5
    ''').get();

  final mismatchedDetails = await db.customSelect('''
    SELECT
      p.id,
      p.kind,
      p.entity_id,
      p.user_id AS queue_user_id,
      entity_owner.user_id AS entity_user_id
    FROM pending_ops p
    LEFT JOIN (
      SELECT id, user_id FROM local_notes
      UNION ALL
      SELECT id, user_id FROM local_folders
      UNION ALL
      SELECT id, user_id FROM attachments
      UNION ALL
      SELECT id, user_id FROM local_templates
      UNION ALL
      SELECT id, user_id FROM saved_searches
    ) entity_owner
      ON entity_owner.id = p.entity_id
    WHERE entity_owner.user_id IS NOT NULL
      AND entity_owner.user_id <> p.user_id
    ORDER BY p.created_at ASC
    LIMIT 5
    ''').get();

  final orphanDetails = await db.customSelect('''
    SELECT id, kind, entity_id, created_at
    FROM pending_ops p
    WHERE NOT EXISTS (SELECT 1 FROM local_notes WHERE id = p.entity_id)
      AND NOT EXISTS (SELECT 1 FROM local_folders WHERE id = p.entity_id)
      AND NOT EXISTS (SELECT 1 FROM attachments WHERE id = p.entity_id)
      AND NOT EXISTS (SELECT 1 FROM local_templates WHERE id = p.entity_id)
      AND NOT EXISTS (SELECT 1 FROM saved_searches WHERE id = p.entity_id)
    ORDER BY created_at ASC
    LIMIT 5
    ''').get();

  return _PendingOpsReport(
    hasUserIdColumn: true,
    total: totals.readNullable<int>('total') ?? 0,
    missingUserId: totals.readNullable<int>('missing') ?? 0,
    mismatchedOwnership: mismatchedCount,
    orphaned: orphaned.readNullable<int>('orphaned') ?? 0,
    missingExamples: missingDetails
        .map(
          (row) => _PendingOpSample(
            id: row.readNullable<int>('id') ?? -1,
            kind: row.readNullable<String>('kind') ?? '',
            entityId: row.readNullable<String>('entity_id') ?? '',
            createdAt: row.readNullable<String>('created_at') ?? '',
          ),
        )
        .toList(),
    mismatchedExamples: mismatchedDetails
        .map(
          (row) => _PendingOpMismatchSample(
            id: row.readNullable<int>('id') ?? -1,
            kind: row.readNullable<String>('kind') ?? '',
            entityId: row.readNullable<String>('entity_id') ?? '',
            queueUserId: row.readNullable<String>('queue_user_id') ?? '',
            entityUserId: row.readNullable<String>('entity_user_id') ?? '',
          ),
        )
        .toList(),
    orphanExamples: orphanDetails
        .map(
          (row) => _PendingOpSample(
            id: row.readNullable<int>('id') ?? -1,
            kind: row.readNullable<String>('kind') ?? '',
            entityId: row.readNullable<String>('entity_id') ?? '',
            createdAt: row.readNullable<String>('created_at') ?? '',
          ),
        )
        .toList(),
  );
}

void _printReport(_PendingOpsReport report) {
  print('Pending Ops Audit');
  print('-----------------');
  if (!report.hasUserIdColumn) {
    print('❌ pending_ops.user_id column is missing. Migration 33 did not run.');
    return;
  }
  print('Total operations     : ${report.total}');
  print('Missing userId       : ${report.missingUserId}');
  print('Mismatched ownership : ${report.mismatchedOwnership}');
  print('Orphaned operations  : ${report.orphaned}');

  if (report.missingExamples.isNotEmpty) {
    print('');
    print('Examples missing userId:');
    for (final sample in report.missingExamples) {
      print(
        '  - #${sample.id} ${sample.kind} entity=${sample.entityId} at ${sample.createdAt}',
      );
    }
  }

  if (report.mismatchedExamples.isNotEmpty) {
    print('');
    print('Examples with mismatched ownership:');
    for (final sample in report.mismatchedExamples) {
      print(
        '  - #${sample.id} ${sample.kind} entity=${sample.entityId} queueUser=${sample.queueUserId} entityUser=${sample.entityUserId}',
      );
    }
  }

  if (report.orphanExamples.isNotEmpty) {
    print('');
    print('Orphaned operations (no matching entity):');
    for (final sample in report.orphanExamples) {
      print(
        '  - #${sample.id} ${sample.kind} entity=${sample.entityId} at ${sample.createdAt}',
      );
    }
  }

  print('');
  if (report.isHealthy) {
    print('✅ Pending operations queue is healthy.');
  } else {
    print('❌ Pending operations queue requires attention.');
  }
}

class _PendingOpsReport {
  _PendingOpsReport({
    required this.hasUserIdColumn,
    required this.total,
    required this.missingUserId,
    required this.mismatchedOwnership,
    required this.orphaned,
    this.missingExamples = const [],
    this.mismatchedExamples = const [],
    this.orphanExamples = const [],
  });

  final bool hasUserIdColumn;
  final int total;
  final int missingUserId;
  final int mismatchedOwnership;
  final int orphaned;
  final List<_PendingOpSample> missingExamples;
  final List<_PendingOpMismatchSample> mismatchedExamples;
  final List<_PendingOpSample> orphanExamples;

  bool get isHealthy =>
      hasUserIdColumn &&
      missingUserId == 0 &&
      mismatchedOwnership == 0 &&
      orphaned == 0;

  Map<String, dynamic> toJson() => {
    'hasUserIdColumn': hasUserIdColumn,
    'total': total,
    'missingUserId': missingUserId,
    'mismatchedOwnership': mismatchedOwnership,
    'orphaned': orphaned,
    'missingExamples': missingExamples.map((e) => e.toJson()).toList(),
    'mismatchedExamples': mismatchedExamples.map((e) => e.toJson()).toList(),
    'orphanExamples': orphanExamples.map((e) => e.toJson()).toList(),
    'isHealthy': isHealthy,
  };
}

class _PendingOpSample {
  _PendingOpSample({
    required this.id,
    required this.kind,
    required this.entityId,
    required this.createdAt,
  });

  final int id;
  final String kind;
  final String entityId;
  final String createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'entityId': entityId,
    'createdAt': createdAt,
  };
}

class _PendingOpMismatchSample {
  _PendingOpMismatchSample({
    required this.id,
    required this.kind,
    required this.entityId,
    required this.queueUserId,
    required this.entityUserId,
  });

  final int id;
  final String kind;
  final String entityId;
  final String queueUserId;
  final String entityUserId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'entityId': entityId,
    'queueUserId': queueUserId,
    'entityUserId': entityUserId,
  };
}
