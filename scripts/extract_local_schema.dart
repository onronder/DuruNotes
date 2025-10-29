import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:duru_notes/data/local/app_db.dart';

/// Script to extract complete local database schema for comparison
/// Run with: flutter run scripts/extract_local_schema.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Extracting local database schema...');

  final db = AppDb();
  final schema = <String, dynamic>{
    'extraction_timestamp': DateTime.now().toIso8601String(),
    'schema_version': 14, // From app_db.dart
    'tables': <String, dynamic>{},
    'indexes': <Map<String, dynamic>>[],
  };

  try {
    // Get all tables
    final tables = await db.customSelect('''
      SELECT name, sql FROM sqlite_master
      WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != '__EFMigrationsHistory'
      ORDER BY name
    ''').get();

    print('Found ${tables.length} tables');

    // Get detailed info for each table
    for (final table in tables) {
      final tableName = table.read<String>('name');
      print('Processing table: $tableName');

      // Get column information
      final columns = await db.customSelect(
        'PRAGMA table_info("$tableName")'
      ).get();

      // Get foreign keys
      final foreignKeys = await db.customSelect(
        'PRAGMA foreign_key_list("$tableName")'
      ).get();

      // Get indexes for this table
      final tableIndexes = await db.customSelect(
        'PRAGMA index_list("$tableName")'
      ).get();

      final columnsList = <Map<String, dynamic>>[];
      for (final col in columns) {
        columnsList.add({
          'cid': col.read<int>('cid'),
          'name': col.read<String>('name'),
          'type': col.read<String>('type'),
          'notnull': col.read<int>('notnull') == 1,
          'dflt_value': col.read<dynamic>('dflt_value'),
          'pk': col.read<int>('pk') == 1,
        });
      }

      final fkList = <Map<String, dynamic>>[];
      for (final fk in foreignKeys) {
        fkList.add({
          'id': fk.read<int>('id'),
          'seq': fk.read<int>('seq'),
          'table': fk.read<String>('table'),
          'from': fk.read<String>('from'),
          'to': fk.read<String>('to'),
          'on_update': fk.read<String>('on_update'),
          'on_delete': fk.read<String>('on_delete'),
        });
      }

      final indexList = <Map<String, dynamic>>[];
      for (final idx in tableIndexes) {
        final indexName = idx.read<String>('name');

        // Get index columns
        final indexInfo = await db.customSelect(
          'PRAGMA index_info("$indexName")'
        ).get();

        final indexColumns = <String>[];
        for (final info in indexInfo) {
          indexColumns.add(info.read<String>('name'));
        }

        indexList.add({
          'name': indexName,
          'unique': idx.read<int>('unique') == 1,
          'columns': indexColumns,
          'partial': idx.read<int>('partial') == 1,
        });
      }

      schema['tables'][tableName] = {
        'sql': table.read<String>('sql'),
        'columns': columnsList,
        'foreign_keys': fkList,
        'indexes': indexList,
      };
    }

    // Get all standalone indexes
    final allIndexes = await db.customSelect('''
      SELECT name, tbl_name, sql FROM sqlite_master
      WHERE type='index' AND sql IS NOT NULL
      ORDER BY tbl_name, name
    ''').get();

    for (final idx in allIndexes) {
      schema['indexes'].add({
        'name': idx.read<String>('name'),
        'table': idx.read<String>('tbl_name'),
        'sql': idx.read<String?>('sql'),
      });
    }

    // Write to file
    final outputFile = File('local_schema_export.json');
    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(schema),
    );

    print('\nSchema exported successfully to local_schema_export.json');
    print('Tables found: ${schema['tables'].keys.join(', ')}');
    print('\nSummary:');
    print('- Total tables: ${schema['tables'].length}');
    print('- Total indexes: ${schema['indexes'].length}');

    // Count total columns
    var totalColumns = 0;
    var totalForeignKeys = 0;
    for (final table in (schema['tables'] as Map).values) {
      totalColumns += (table['columns'] as List).length;
      totalForeignKeys += (table['foreign_keys'] as List).length;
    }
    print('- Total columns: $totalColumns');
    print('- Total foreign keys: $totalForeignKeys');

  } catch (e, stack) {
    print('Error extracting schema: $e');
    print('Stack trace: $stack');
  } finally {
    await db.close();
  }
}