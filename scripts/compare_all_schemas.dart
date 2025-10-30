#!/usr/bin/env dart
// Comprehensive Schema Comparison Tool
//
// Compares ALL local Drift tables with ALL remote Supabase tables
// Identifies every mismatch for systematic remediation
//
// Usage: dart scripts/compare_all_schemas.dart

import 'dart:io';

void main() async {
  print('═══════════════════════════════════════════════════════════════');
  print('   COMPREHENSIVE SCHEMA COMPARISON TOOL');
  print('   Local Drift Tables vs Remote Supabase Tables');
  print('═══════════════════════════════════════════════════════════════\n');

  try {
    // Step 1: Extract local table definitions
    print('📊 Step 1: Extracting LOCAL table definitions from Drift...\n');
    final localTables = await extractLocalTables();
    print('   Found ${localTables.length} local tables\n');

    // Step 2: Extract remote table definitions
    print('📊 Step 2: Extracting REMOTE table definitions from Supabase...\n');
    final remoteTables = await extractRemoteTables();
    print('   Found ${remoteTables.length} remote tables\n');

    // Step 3: Compare schemas
    print('🔍 Step 3: Comparing schemas...\n');
    final comparison = compareSchemas(localTables, remoteTables);

    // Step 4: Generate report
    print('📝 Step 4: Generating comprehensive report...\n');
    final report = generateReport(comparison);

    // Step 5: Save report
    final reportPath = 'docs/COMPREHENSIVE_SCHEMA_COMPARISON_REPORT.md';
    await File(reportPath).writeAsString(report);
    print('✅ Report saved to: $reportPath\n');

    // Step 6: Print summary
    printSummary(comparison);

    // Step 7: Exit with appropriate code
    if (comparison.criticalIssues > 0) {
      print('\n❌ CRITICAL ISSUES FOUND - Deployment blocked');
      exit(1);
    } else if (comparison.warnings > 0) {
      print('\n⚠️  Warnings found - Review recommended');
      exit(0);
    } else {
      print('\n✅ All schemas aligned');
      exit(0);
    }
  } catch (e, stackTrace) {
    print('❌ ERROR: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

// Extract local table definitions from app_db.dart
Future<Map<String, LocalTableDef>> extractLocalTables() async {
  final appDbPath = 'lib/data/local/app_db.dart';
  final file = File(appDbPath);

  if (!await file.exists()) {
    throw Exception('app_db.dart not found at $appDbPath');
  }

  final content = await file.readAsString();
  final tables = <String, LocalTableDef>{};

  // Parse table classes
  final classRegex = RegExp(r'class\s+(\w+)\s+extends\s+Table\s*\{');
  final matches = classRegex.allMatches(content);

  for (final match in matches) {
    final tableName = match.group(1)!;
    final tableContent = _extractTableContent(content, match.start);
    final columns = _parseColumns(tableContent);

    tables[tableName] = LocalTableDef(
      name: tableName,
      columns: columns,
      rawContent: tableContent,
    );

    print('   - Found local table: $tableName (${columns.length} columns)');
  }

  return tables;
}

// Extract table content from class definition
String _extractTableContent(String content, int startPos) {
  var braceCount = 0;
  var started = false;
  var endPos = startPos;

  for (var i = startPos; i < content.length; i++) {
    if (content[i] == '{') {
      braceCount++;
      started = true;
    } else if (content[i] == '}') {
      braceCount--;
      if (started && braceCount == 0) {
        endPos = i + 1;
        break;
      }
    }
  }

  return content.substring(startPos, endPos);
}

// Parse column definitions from table class
List<ColumnDef> _parseColumns(String tableContent) {
  final columns = <ColumnDef>[];

  // Match column definitions like: TextColumn get userId => text().nullable()();
  final columnRegex = RegExp(
    r'(\w+Column)\s+get\s+(\w+)\s+=>\s+(\w+)\(\)(.*?)\(\);',
    multiLine: true,
  );

  final matches = columnRegex.allMatches(tableContent);

  for (final match in matches) {
    final columnName = match.group(2)!; // e.g., userId
    final baseType = match.group(3)!; // e.g., text
    final modifiers = match.group(4)!; // e.g., .nullable()

    final isNullable = modifiers.contains('.nullable()');
    final isPrimaryKey =
        tableContent.contains('primaryKey => {$columnName}') ||
        tableContent.contains('primaryKey => {$columnName,');

    columns.add(
      ColumnDef(
        name: columnName,
        type: _mapDriftTypeToSql(baseType),
        isNullable: isNullable,
        isPrimaryKey: isPrimaryKey,
        rawDefinition: match.group(0)!,
      ),
    );
  }

  return columns;
}

// Map Drift column types to SQL types
String _mapDriftTypeToSql(String driftType) {
  switch (driftType) {
    case 'text':
      return 'TEXT';
    case 'integer':
      return 'INTEGER';
    case 'boolean':
    case 'bool':
      return 'BOOLEAN';
    case 'dateTime':
      return 'TIMESTAMPTZ';
    case 'blob':
      return 'BYTEA';
    case 'real':
      return 'REAL';
    default:
      return driftType.toUpperCase();
  }
}

// Extract remote table definitions from Supabase
Future<Map<String, RemoteTableDef>> extractRemoteTables() async {
  print('   Running: supabase db dump...');

  // Get remote schema dump
  final result = await Process.run('supabase', [
    'db',
    'dump',
    '--data-only=false',
  ], runInShell: true);

  if (result.exitCode != 0) {
    throw Exception('Failed to dump remote schema: ${result.stderr}');
  }

  final schemaDump = result.stdout as String;
  final tables = <String, RemoteTableDef>{};

  // Parse CREATE TABLE statements
  final tableRegex = RegExp(
    r'CREATE TABLE.*?"public"\."(\w+)"\s*\((.*?)\);',
    multiLine: true,
    dotAll: true,
  );

  final matches = tableRegex.allMatches(schemaDump);

  for (final match in matches) {
    final tableName = match.group(1)!;
    final columnsContent = match.group(2)!;
    final columns = _parseRemoteColumns(columnsContent);

    tables[tableName] = RemoteTableDef(
      name: tableName,
      columns: columns,
      rawContent: match.group(0)!,
    );

    print('   - Found remote table: $tableName (${columns.length} columns)');
  }

  return tables;
}

// Parse column definitions from CREATE TABLE statement
List<ColumnDef> _parseRemoteColumns(String columnsContent) {
  final columns = <ColumnDef>[];
  final lines = columnsContent.split(',');

  for (final line in lines) {
    final trimmed = line.trim();

    // Skip constraints
    if (trimmed.startsWith('PRIMARY KEY') ||
        trimmed.startsWith('FOREIGN KEY') ||
        trimmed.startsWith('CONSTRAINT') ||
        trimmed.startsWith('UNIQUE')) {
      continue;
    }

    // Parse column: "column_name" type [NOT NULL] [DEFAULT ...]
    final columnMatch = RegExp(r'"(\w+)"\s+"?(\w+)"?(.*)').firstMatch(trimmed);
    if (columnMatch != null) {
      final name = columnMatch.group(1)!;
      final type = columnMatch.group(2)!.toUpperCase();
      final rest = columnMatch.group(3)!;

      final isNullable = !rest.contains('NOT NULL');
      final isPrimaryKey = rest.contains('PRIMARY KEY');

      columns.add(
        ColumnDef(
          name: name,
          type: type,
          isNullable: isNullable,
          isPrimaryKey: isPrimaryKey,
          rawDefinition: trimmed,
        ),
      );
    }
  }

  return columns;
}

// Convert Dart class name to SQL table name (PascalCase to snake_case)
String toSnakeCase(String className) {
  // Remove "Local" prefix if present
  var name = className;
  if (name.startsWith('Local')) {
    name = name.substring(5); // Remove "Local"
  }

  // Convert PascalCase to snake_case
  return name
      .replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(1)!.toLowerCase()}',
      )
      .substring(1); // Remove leading underscore
}

// Compare local and remote schemas
SchemaComparison compareSchemas(
  Map<String, LocalTableDef> local,
  Map<String, RemoteTableDef> remote,
) {
  final comparison = SchemaComparison();

  // Create mapping from local class names to SQL table names
  final localToSqlMap = <String, String>{};
  final sqlToLocalMap = <String, String>{};

  for (final className in local.keys) {
    final sqlName = toSnakeCase(className);
    localToSqlMap[className] = sqlName;
    sqlToLocalMap[sqlName] = className;
  }

  for (final className in local.keys) {
    final sqlName = localToSqlMap[className]!;
    if (!remote.containsKey(sqlName)) {
      comparison.localOnly.add('$className (SQL: $sqlName)');
    }
  }

  // Find tables only in remote
  for (final tableName in remote.keys) {
    if (!sqlToLocalMap.containsKey(tableName)) {
      comparison.remoteOnly.add(tableName);
    }
  }

  // Compare common tables
  for (final className in local.keys) {
    final sqlName = localToSqlMap[className]!;
    if (remote.containsKey(sqlName)) {
      final localTable = local[className]!;
      final remoteTable = remote[sqlName]!;

      final tableMismatch = compareTable(
        '$className -> $sqlName',
        localTable,
        remoteTable,
      );
      if (tableMismatch.hasMismatches) {
        comparison.mismatches.add(tableMismatch);
      }
    }
  }

  return comparison;
}

// Compare a single table between local and remote
TableMismatch compareTable(
  String tableName,
  LocalTableDef local,
  RemoteTableDef remote,
) {
  final mismatch = TableMismatch(tableName: tableName);

  // Build column maps
  final localCols = {for (var c in local.columns) c.name: c};
  final remoteCols = {for (var c in remote.columns) c.name: c};

  // Find columns only in local
  for (final colName in localCols.keys) {
    if (!remoteCols.containsKey(colName)) {
      mismatch.localOnlyColumns.add(colName);
    }
  }

  // Find columns only in remote
  for (final colName in remoteCols.keys) {
    if (!localCols.containsKey(colName)) {
      mismatch.remoteOnlyColumns.add(colName);
    }
  }

  // Compare common columns
  for (final colName in localCols.keys) {
    if (remoteCols.containsKey(colName)) {
      final localCol = localCols[colName]!;
      final remoteCol = remoteCols[colName]!;

      final colMismatch = compareColumn(colName, localCol, remoteCol);
      if (colMismatch != null) {
        mismatch.columnMismatches.add(colMismatch);
      }
    }
  }

  return mismatch;
}

// Compare a single column
ColumnMismatch? compareColumn(String name, ColumnDef local, ColumnDef remote) {
  final issues = <String>[];

  // Type mismatch
  if (local.type != remote.type) {
    // Allow some compatible type mismatches
    final compatible = _areTypesCompatible(local.type, remote.type);
    if (!compatible) {
      issues.add('Type: local=${local.type}, remote=${remote.type}');
    }
  }

  // Nullability mismatch (CRITICAL for sync)
  if (local.isNullable != remote.isNullable) {
    final severity = 'CRITICAL';
    issues.add(
      '$severity - Nullability: local=${local.isNullable ? 'NULL' : 'NOT NULL'}, remote=${remote.isNullable ? 'NULL' : 'NOT NULL'}',
    );
  }

  // Primary key mismatch
  if (local.isPrimaryKey != remote.isPrimaryKey) {
    issues.add(
      'Primary Key: local=${local.isPrimaryKey}, remote=${remote.isPrimaryKey}',
    );
  }

  if (issues.isEmpty) return null;

  return ColumnMismatch(
    columnName: name,
    issues: issues,
    localDef: local,
    remoteDef: remote,
  );
}

// Check if types are compatible (e.g., TEXT vs UUID)
bool _areTypesCompatible(String type1, String type2) {
  final compatibleSets = [
    {'TEXT', 'UUID'},
    {'INTEGER', 'INT', 'BIGINT'},
    {'TIMESTAMPTZ', 'TIMESTAMP'},
    {'BYTEA', 'BLOB'},
  ];

  for (final set in compatibleSets) {
    if (set.contains(type1) && set.contains(type2)) {
      return true;
    }
  }

  return type1 == type2;
}

// Generate comprehensive markdown report
String generateReport(SchemaComparison comparison) {
  final buffer = StringBuffer();

  buffer.writeln('# Comprehensive Schema Comparison Report');
  buffer.writeln();
  buffer.writeln('**Generated**: ${DateTime.now().toIso8601String()}');
  buffer.writeln('**Tool**: scripts/compare_all_schemas.dart');
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln();

  // Executive Summary
  buffer.writeln('## Executive Summary');
  buffer.writeln();
  buffer.writeln('| Metric | Count |');
  buffer.writeln('|--------|-------|');
  buffer.writeln(
    '| Tables with mismatches | ${comparison.mismatches.length} |',
  );
  buffer.writeln('| Tables only in LOCAL | ${comparison.localOnly.length} |');
  buffer.writeln('| Tables only in REMOTE | ${comparison.remoteOnly.length} |');
  buffer.writeln('| Critical issues | ${comparison.criticalIssues} |');
  buffer.writeln('| Warnings | ${comparison.warnings} |');
  buffer.writeln();

  // Status
  if (comparison.criticalIssues > 0) {
    buffer.writeln('**Status**: 🔴 CRITICAL - Deployment blocked');
  } else if (comparison.warnings > 0) {
    buffer.writeln('**Status**: 🟡 WARNING - Review recommended');
  } else {
    buffer.writeln('**Status**: ✅ All schemas aligned');
  }
  buffer.writeln();
  buffer.writeln('---');
  buffer.writeln();

  // Tables only in local
  if (comparison.localOnly.isNotEmpty) {
    buffer.writeln('## Tables Only in LOCAL (Not Synced to Remote)');
    buffer.writeln();
    buffer.writeln(
      'These tables exist locally but NOT in the remote Supabase database:',
    );
    buffer.writeln();
    for (final table in comparison.localOnly) {
      buffer.writeln('- `$table` - ⚠️ Will not sync to cloud');
    }
    buffer.writeln();
  }

  // Tables only in remote
  if (comparison.remoteOnly.isNotEmpty) {
    buffer.writeln('## Tables Only in REMOTE (Not in Local App)');
    buffer.writeln();
    buffer.writeln(
      'These tables exist in Supabase but NOT in the local Drift schema:',
    );
    buffer.writeln();
    for (final table in comparison.remoteOnly) {
      buffer.writeln('- `$table` - ℹ️ App cannot access this data');
    }
    buffer.writeln();
  }

  // Mismatches
  if (comparison.mismatches.isNotEmpty) {
    buffer.writeln('## Schema Mismatches (Tables Exist in Both)');
    buffer.writeln();

    for (final mismatch in comparison.mismatches) {
      buffer.writeln('### Table: `${mismatch.tableName}`');
      buffer.writeln();

      // Columns only in local
      if (mismatch.localOnlyColumns.isNotEmpty) {
        buffer.writeln('**Columns only in LOCAL:**');
        for (final col in mismatch.localOnlyColumns) {
          buffer.writeln('- `$col` - Will not sync to remote');
        }
        buffer.writeln();
      }

      // Columns only in remote
      if (mismatch.remoteOnlyColumns.isNotEmpty) {
        buffer.writeln('**Columns only in REMOTE:**');
        for (final col in mismatch.remoteOnlyColumns) {
          buffer.writeln('- `$col` - App cannot access this data');
        }
        buffer.writeln();
      }

      // Column mismatches
      if (mismatch.columnMismatches.isNotEmpty) {
        buffer.writeln('**Column Definition Mismatches:**');
        buffer.writeln();
        buffer.writeln('| Column | Issues |');
        buffer.writeln('|--------|--------|');
        for (final colMismatch in mismatch.columnMismatches) {
          buffer.writeln(
            '| `${colMismatch.columnName}` | ${colMismatch.issues.join(', ')} |',
          );
        }
        buffer.writeln();
      }

      buffer.writeln('---');
      buffer.writeln();
    }
  }

  return buffer.toString();
}

// Print summary to console
void printSummary(SchemaComparison comparison) {
  print('═══════════════════════════════════════════════════════════════');
  print('   SUMMARY');
  print('═══════════════════════════════════════════════════════════════');
  print('');
  print('Tables with mismatches:     ${comparison.mismatches.length}');
  print('Tables only in LOCAL:       ${comparison.localOnly.length}');
  print('Tables only in REMOTE:      ${comparison.remoteOnly.length}');
  print('Critical issues:            ${comparison.criticalIssues}');
  print('Warnings:                   ${comparison.warnings}');
  print('');
}

// Data classes

class LocalTableDef {
  final String name;
  final List<ColumnDef> columns;
  final String rawContent;

  LocalTableDef({
    required this.name,
    required this.columns,
    required this.rawContent,
  });
}

class RemoteTableDef {
  final String name;
  final List<ColumnDef> columns;
  final String rawContent;

  RemoteTableDef({
    required this.name,
    required this.columns,
    required this.rawContent,
  });
}

class ColumnDef {
  final String name;
  final String type;
  final bool isNullable;
  final bool isPrimaryKey;
  final String rawDefinition;

  ColumnDef({
    required this.name,
    required this.type,
    required this.isNullable,
    required this.isPrimaryKey,
    required this.rawDefinition,
  });
}

class SchemaComparison {
  final List<String> localOnly = [];
  final List<String> remoteOnly = [];
  final List<TableMismatch> mismatches = [];

  int get criticalIssues {
    var count = 0;
    for (final mismatch in mismatches) {
      for (final colMismatch in mismatch.columnMismatches) {
        if (colMismatch.issues.any((i) => i.contains('CRITICAL'))) {
          count++;
        }
      }
    }
    return count;
  }

  int get warnings {
    return localOnly.length +
        remoteOnly.length +
        mismatches.length -
        criticalIssues;
  }
}

class TableMismatch {
  final String tableName;
  final List<String> localOnlyColumns = [];
  final List<String> remoteOnlyColumns = [];
  final List<ColumnMismatch> columnMismatches = [];

  TableMismatch({required this.tableName});

  bool get hasMismatches =>
      localOnlyColumns.isNotEmpty ||
      remoteOnlyColumns.isNotEmpty ||
      columnMismatches.isNotEmpty;
}

class ColumnMismatch {
  final String columnName;
  final List<String> issues;
  final ColumnDef localDef;
  final ColumnDef remoteDef;

  ColumnMismatch({
    required this.columnName,
    required this.issues,
    required this.localDef,
    required this.remoteDef,
  });
}
