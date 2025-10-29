#!/usr/bin/env dart

// Comprehensive Migration Analysis Tool
//
// Analyzes ALL migration files (applied and skipped)
// Categorizes by purpose, detects conflicts, builds merge plan
//
// Usage: dart scripts/analyze_all_migrations.dart

import 'dart:io';

void main() async {
  print('═══════════════════════════════════════════════════════════════');
  print('   COMPREHENSIVE MIGRATION ANALYSIS');
  print('   Analyzing 64 migration files for consolidation');
  print('═══════════════════════════════════════════════════════════════\n');

  try {
    // Step 1: Scan all migration files
    print('📊 Step 1: Scanning migration files...\n');
    final migrations = await scanMigrations();
    print('   Found ${migrations.length} total migrations\n');

    // Step 2: Categorize migrations
    print('📊 Step 2: Categorizing migrations by purpose...\n');
    final categories = categorizeMigrations(migrations);
    printCategories(categories);

    // Step 3: Detect conflicts
    print('\n🔍 Step 3: Detecting conflicts and duplicates...\n');
    final conflicts = detectConflicts(migrations);
    printConflicts(conflicts);

    // Step 4: Analyze skipped migrations
    print('\n📊 Step 4: Analyzing skipped migrations...\n');
    final skippedAnalysis = analyzeSkippedMigrations(
      migrations.where((m) => m.isSkipped).toList(),
    );
    printSkippedAnalysis(skippedAnalysis);

    // Step 5: Generate consolidation plan
    print('\n📝 Step 5: Generating consolidation plan...\n');
    final plan = generateConsolidationPlan(migrations, categories, conflicts);

    // Step 6: Save report
    final reportPath = 'docs/MIGRATION_CONSOLIDATION_ANALYSIS.md';
    await File(reportPath).writeAsString(plan);
    print('✅ Report saved to: $reportPath\n');

    // Step 7: Print summary
    printSummary(migrations, categories, conflicts);

  } catch (e, stackTrace) {
    print('❌ ERROR: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

class Migration {
  final String filename;
  final String timestamp;
  final String name;
  final bool isSkipped;
  final bool isApplied;
  final String content;
  final int lineCount;
  final List<String> tables;
  final List<String> operations;

  Migration({
    required this.filename,
    required this.timestamp,
    required this.name,
    required this.isSkipped,
    required this.isApplied,
    required this.content,
    required this.lineCount,
    required this.tables,
    required this.operations,
  });

  String get category {
    final lower = name.toLowerCase();
    if (lower.contains('phase') || lower.contains('migration')) {
      return 'PHASED_MIGRATION';
    }
    if (lower.contains('security') || lower.contains('rls') || lower.contains('policy')) {
      return 'SECURITY';
    }
    if (lower.contains('performance') || lower.contains('index') || lower.contains('optimize')) {
      return 'PERFORMANCE';
    }
    if (lower.contains('fix') || lower.contains('repair')) {
      return 'BUG_FIX';
    }
    if (lower.contains('notification') || lower.contains('cron')) {
      return 'NOTIFICATIONS';
    }
    if (lower.contains('schema') || lower.contains('table') || lower.contains('column')) {
      return 'SCHEMA_CHANGE';
    }
    if (lower.contains('encryption') || lower.contains('key')) {
      return 'ENCRYPTION';
    }
    if (lower.contains('folder') || lower.contains('template') || lower.contains('search')) {
      return 'FEATURE';
    }
    if (lower.contains('audit') || lower.contains('log')) {
      return 'AUDIT';
    }

    return 'OTHER';
  }

  bool get hasNamingIssue {
    // Proper format: YYYYMMDDHHMMSS_name.sql
    final timestampMatch = RegExp(r'^\d{14}').hasMatch(timestamp);
    return !timestampMatch;
  }
}

Future<List<Migration>> scanMigrations() async {
  final migrationsDir = Directory('supabase/migrations');
  if (!await migrationsDir.exists()) {
    throw Exception('Migrations directory not found');
  }

  final migrations = <Migration>[];

  await for (final entity in migrationsDir.list()) {
    if (entity is! File) {
      continue;
    }

    final filename = entity.uri.pathSegments.last;
    final isSqlFile = filename.endsWith('.sql');
    final isSkipFile = filename.endsWith('.skip');
    if (!isSqlFile && !isSkipFile) {
      continue;
    }

    final effectiveName = isSkipFile
        ? filename.substring(0, filename.length - '.skip'.length)
        : filename;

    final parts = effectiveName.split('_');
    if (parts.length < 2) {
      // Skip malformed filenames
      continue;
    }

    final timestamp = parts.first;
    final name = parts.sublist(1).join('_').replaceAll('.sql', '');

    final content = await entity.readAsString();
    final lines = content.split('\n');

    final tables = <String>{};
    final tableRegex = RegExp(
      r'(CREATE|ALTER|DROP)\s+TABLE\s+(?:IF\s+(?:NOT\s+)?EXISTS\s+)?(?:"?public"?\.)?"?(\w+)"?',
      caseSensitive: false,
    );
    for (final match in tableRegex.allMatches(content)) {
      final tableName = match.group(2);
      if (tableName != null) {
        tables.add(tableName);
      }
    }

    final operations = <String>{};
    if (RegExp(r'CREATE\s+TABLE', caseSensitive: false).hasMatch(content)) {
      operations.add('CREATE_TABLE');
    }
    if (RegExp(r'ALTER\s+TABLE', caseSensitive: false).hasMatch(content)) {
      operations.add('ALTER_TABLE');
    }
    if (RegExp(r'DROP\s+TABLE', caseSensitive: false).hasMatch(content)) {
      operations.add('DROP_TABLE');
    }
    if (RegExp(r'CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION', caseSensitive: false)
        .hasMatch(content)) {
      operations.add('CREATE_FUNCTION');
    }
    if (RegExp(r'CREATE\s+POLICY', caseSensitive: false).hasMatch(content)) {
      operations.add('CREATE_POLICY');
    }
    if (RegExp(r'CREATE\s+INDEX', caseSensitive: false).hasMatch(content)) {
      operations.add('CREATE_INDEX');
    }

    migrations.add(
      Migration(
        filename: filename,
        timestamp: timestamp,
        name: name,
        isSkipped: isSkipFile,
        isApplied: !isSkipFile,
        content: content,
        lineCount: lines.length,
        tables: tables.toList(),
        operations: operations.toList(),
      ),
    );

    print('   - $filename (${lines.length} lines, ${tables.length} tables)');
  }

  migrations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return migrations;
}

Map<String, List<Migration>> categorizeMigrations(List<Migration> migrations) {
  final categories = <String, List<Migration>>{};

  for (final migration in migrations) {
    final category = migration.category;
    categories.putIfAbsent(category, () => []).add(migration);
  }

  return categories;
}

void printCategories(Map<String, List<Migration>> categories) {
  for (final category in categories.keys) {
    final count = categories[category]!.length;
    final skipped = categories[category]!.where((m) => m.isSkipped).length;
    print('   [$category] $count migrations ($skipped skipped)');
  }
}

List<ConflictGroup> detectConflicts(List<Migration> migrations) {
  final conflicts = <ConflictGroup>[];

  // Detect duplicate timestamps
  final timestampGroups = <String, List<Migration>>{};
  for (final migration in migrations) {
    timestampGroups.putIfAbsent(migration.timestamp, () => []).add(migration);
  }

  for (final entry in timestampGroups.entries) {
    if (entry.value.length > 1) {
      conflicts.add(ConflictGroup(
        type: 'DUPLICATE_TIMESTAMP',
        migrations: entry.value,
        severity: 'HIGH',
        description: 'Multiple migrations with timestamp ${entry.key}',
      ));
    }
  }

  // Detect table conflicts (same table modified by multiple migrations)
  final tableGroups = <String, List<Migration>>{};
  for (final migration in migrations) {
    for (final table in migration.tables) {
      tableGroups.putIfAbsent(table, () => []).add(migration);
    }
  }

  for (final entry in tableGroups.entries) {
    if (entry.value.length > 3) {
      conflicts.add(ConflictGroup(
        type: 'TABLE_HOTSPOT',
        migrations: entry.value,
        severity: 'MEDIUM',
        description: 'Table "${entry.key}" modified by ${entry.value.length} migrations',
      ));
    }
  }

  // Detect naming issues
  final namingIssues = migrations.where((m) => m.hasNamingIssue).toList();
  if (namingIssues.isNotEmpty) {
    conflicts.add(ConflictGroup(
      type: 'NAMING_ISSUE',
      migrations: namingIssues,
      severity: 'HIGH',
      description: '${namingIssues.length} migrations with improper naming (missing HHMMSS)',
    ));
  }

  return conflicts;
}

void printConflicts(List<ConflictGroup> conflicts) {
  if (conflicts.isEmpty) {
    print('   ✓ No conflicts detected');
    return;
  }

  for (final conflict in conflicts) {
    print('   🔴 [${conflict.severity}] ${conflict.type}: ${conflict.description}');
    for (final migration in conflict.migrations.take(5)) {
      print('      - ${migration.filename}');
    }
    if (conflict.migrations.length > 5) {
      print('      ... and ${conflict.migrations.length - 5} more');
    }
  }
}

SkippedAnalysis analyzeSkippedMigrations(List<Migration> skipped) {
  final analysis = SkippedAnalysis();

  for (final migration in skipped) {
    // Analyze why it might be skipped
    String reason = 'Unknown';

    if (migration.name.contains('phase')) {
      reason = 'Part of phased deployment strategy';
    } else if (migration.hasNamingIssue) {
      reason = 'Naming issue (missing HHMMSS)';
    } else if (migration.lineCount > 500) {
      reason = 'Large migration (${migration.lineCount} lines) - needs review';
    } else if (migration.operations.contains('DROP_TABLE')) {
      reason = 'Contains DROP TABLE - destructive operation';
    } else {
      reason = 'Intentionally deferred';
    }

    analysis.items.add(SkippedItem(
      migration: migration,
      reason: reason,
    ));
  }

  return analysis;
}

void printSkippedAnalysis(SkippedAnalysis analysis) {
  final groupedByReason = <String, List<SkippedItem>>{};
  for (final item in analysis.items) {
    groupedByReason.putIfAbsent(item.reason, () => []).add(item);
  }

  for (final entry in groupedByReason.entries) {
    print('   📌 ${entry.key}: ${entry.value.length} migrations');
    for (final item in entry.value.take(3)) {
      print('      - ${item.migration.filename}');
    }
    if (entry.value.length > 3) {
      print('      ... and ${entry.value.length - 3} more');
    }
  }
}

String generateConsolidationPlan(
  List<Migration> migrations,
  Map<String, List<Migration>> categories,
  List<ConflictGroup> conflicts,
) {
  final buffer = StringBuffer();

  buffer.writeln('# Migration Consolidation Analysis');
  buffer.writeln();
  buffer.writeln('**Generated**: ${DateTime.now().toIso8601String()}');
  buffer.writeln('**Total Migrations**: ${migrations.length}');
  buffer.writeln('**Applied**: ${migrations.where((m) => m.isApplied).length}');
  buffer.writeln('**Skipped**: ${migrations.where((m) => m.isSkipped).length}');
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln();

  // Executive Summary
  buffer.writeln('## Executive Summary');
  buffer.writeln();
  buffer.writeln('| Metric | Count |');
  buffer.writeln('|--------|-------|');
  buffer.writeln('| Total Migrations | ${migrations.length} |');
  buffer.writeln('| Applied | ${migrations.where((m) => m.isApplied).length} |');
  buffer.writeln('| Skipped | ${migrations.where((m) => m.isSkipped).length} |');
  buffer.writeln('| Conflicts | ${conflicts.length} |');
  buffer.writeln('| Naming Issues | ${migrations.where((m) => m.hasNamingIssue).length} |');
  buffer.writeln();

  // Categories
  buffer.writeln('## Migration Categories');
  buffer.writeln();
  for (final category in categories.keys) {
    buffer.writeln('### $category (${categories[category]!.length} migrations)');
    buffer.writeln();
    for (final migration in categories[category]!) {
      final status = migration.isSkipped ? '⏸️ SKIPPED' : '✅ APPLIED';
      final naming = migration.hasNamingIssue ? '⚠️ NAMING ISSUE' : '';
      buffer.writeln('- `${migration.filename}` - $status $naming');
      buffer.writeln('  - Tables: ${migration.tables.join(", ")}');
      buffer.writeln('  - Operations: ${migration.operations.join(", ")}');
    }
    buffer.writeln();
  }

  // Conflicts
  buffer.writeln('## Conflicts Detected');
  buffer.writeln();
  if (conflicts.isEmpty) {
    buffer.writeln('✅ No conflicts detected');
  } else {
    for (final conflict in conflicts) {
      buffer.writeln('### ${conflict.type} (${conflict.severity})');
      buffer.writeln();
      buffer.writeln(conflict.description);
      buffer.writeln();
      buffer.writeln('**Affected Migrations:**');
      for (final migration in conflict.migrations) {
        buffer.writeln('- `${migration.filename}`');
      }
      buffer.writeln();
    }
  }

  // Recommendations
  buffer.writeln('## Recommendations');
  buffer.writeln();
  buffer.writeln('### Immediate Actions');
  buffer.writeln();
  buffer.writeln('1. **Fix Naming Issues** - ${migrations.where((m) => m.hasNamingIssue).length} migrations need HHMMSS timestamps');
  buffer.writeln('2. **Review Duplicates** - ${conflicts.where((c) => c.type == 'DUPLICATE_TIMESTAMP').length} duplicate timestamp conflicts');
  buffer.writeln('3. **Analyze Skipped** - ${migrations.where((m) => m.isSkipped).length} skipped migrations need review');
  buffer.writeln();

  return buffer.toString();
}

void printSummary(
  List<Migration> migrations,
  Map<String, List<Migration>> categories,
  List<ConflictGroup> conflicts,
) {
  print('═══════════════════════════════════════════════════════════════');
  print('   SUMMARY');
  print('═══════════════════════════════════════════════════════════════');
  print('');
  print('Total migrations:       ${migrations.length}');
  print('Applied:                ${migrations.where((m) => m.isApplied).length}');
  print('Skipped:                ${migrations.where((m) => m.isSkipped).length}');
  print('Categories:             ${categories.length}');
  print('Conflicts:              ${conflicts.length}');
  print('Naming issues:          ${migrations.where((m) => m.hasNamingIssue).length}');
  print('');
}

class ConflictGroup {
  final String type;
  final List<Migration> migrations;
  final String severity;
  final String description;

  ConflictGroup({
    required this.type,
    required this.migrations,
    required this.severity,
    required this.description,
  });
}

class SkippedAnalysis {
  final List<SkippedItem> items = [];
}

class SkippedItem {
  final Migration migration;
  final String reason;

  SkippedItem({
    required this.migration,
    required this.reason,
  });
}
