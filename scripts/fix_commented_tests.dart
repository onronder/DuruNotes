import 'dart:io';

/// Script to systematically fix commented-out test files
void main() async {
  print('🔧 Test File Restoration Script');
  print('=' * 60);

  final testFiles = [
    // Minor fixes needed
    TestFile(
      path: 'test/features/templates/template_management_integration_test.dart',
      status: 'minor',
      fixes: [
        'Replace TemplateRepository with ITemplateRepository',
        'Update to use domain.Template entity',
        'Fix import paths',
      ],
    ),
    TestFile(
      path: 'test/features/notes/pagination_infinite_loop_regression_test.dart',
      status: 'minor',
      fixes: [
        'Update provider references',
        'Fix pagination logic',
      ],
    ),
    TestFile(
      path: 'test/services/metadata_preservation_test.dart',
      status: 'minor',
      fixes: [
        'Update to use domain.Note',
        'Fix metadata field access',
      ],
    ),

    // Major rewrites needed
    TestFile(
      path: 'test/repositories/notes_core_repository_test.dart',
      status: 'major',
      fixes: [
        'Complete rewrite for domain architecture',
        'Use INoteRepository interface',
        'Update all test data to domain models',
      ],
    ),
    TestFile(
      path: 'test/services/undo_redo_service_test.dart',
      status: 'major',
      fixes: [
        'Replace NotesRepository with domain interface',
        'Update folder operations',
        'Fix mock patterns',
      ],
    ),

    // Blocked by dependencies
    TestFile(
      path: 'test/step2_sync_verification_deployment_test.dart',
      status: 'blocked',
      fixes: [
        'Waiting for pre_deployment_providers.dart',
        'Waiting for PreDeploymentValidator',
      ],
    ),
  ];

  // Generate report
  print('\n📊 Test Files Analysis:');
  final groups = <String, List<TestFile>>{};
  for (final file in testFiles) {
    groups.putIfAbsent(file.status, () => []).add(file);
  }

  for (final entry in groups.entries) {
    print('\n${_getStatusEmoji(entry.key)} ${entry.key.toUpperCase()} (${entry.value.length} files)');
    for (final file in entry.value) {
      print('  - ${file.path.split('/').last}');
      for (final fix in file.fixes) {
        print('    • $fix');
      }
    }
  }

  // Attempt automatic fixes for minor issues
  print('\n🚀 Attempting automatic fixes for minor issues...\n');

  for (final testFile in testFiles.where((f) => f.status == 'minor')) {
    print('Processing: ${testFile.path}');

    final file = File(testFile.path);
    if (!file.existsSync()) {
      print('  ❌ File not found');
      continue;
    }

    try {
      var content = await file.readAsString();

      // Check if file is commented
      if (content.startsWith('/*')) {
        print('  📝 File is commented out, attempting to uncomment...');

        // Find the main comment block
        final commentPattern = RegExp(r'^/\*.*?\*/\n*', dotAll: true);
        content = content.replaceFirst(commentPattern, '');

        // Update imports
        content = _updateImports(content);

        // Save the file
        await file.writeAsString(content);
        print('  ✅ File uncommented and imports updated');

        // Test compilation
        final result = await Process.run('dart', ['analyze', testFile.path]);
        if (result.exitCode == 0) {
          print('  ✅ File compiles without errors!');
        } else {
          print('  ⚠️ File has compilation errors:');
          print(result.stdout.toString().split('\n').take(5).join('\n'));
        }
      } else {
        print('  ℹ️ File is not commented, skipping');
      }
    } catch (e) {
      print('  ❌ Error processing file: $e');
    }
  }

  print('\n✅ Script completed!');
  print('Next steps:');
  print('1. Review the automatically fixed files');
  print('2. Manually fix compilation errors');
  print('3. Run flutter test to verify');
}

String _getStatusEmoji(String status) {
  switch (status) {
    case 'minor':
      return '🔧';
    case 'major':
      return '🔄';
    case 'blocked':
      return '🚫';
    default:
      return '❓';
  }
}

String _updateImports(String content) {
  // Update common import patterns
  final replacements = {
    'import \'package:duru_notes/repository/notes_repository.dart\'':
        'import \'package:duru_notes/domain/repositories/i_notes_repository.dart\'',
    'import \'package:duru_notes/repository/folder_repository.dart\'':
        'import \'package:duru_notes/domain/repositories/i_folder_repository.dart\'',
    'import \'package:duru_notes/repository/template_repository.dart\'':
        'import \'package:duru_notes/domain/repositories/i_template_repository.dart\'',
    'NotesRepository': 'INoteRepository',
    'FolderRepository': 'IFolderRepository',
    'TemplateRepository': 'ITemplateRepository',
    'LocalNote': 'Note',
    'LocalFolder': 'Folder',
  };

  for (final entry in replacements.entries) {
    content = content.replaceAll(entry.key, entry.value);
  }

  return content;
}

class TestFile {
  final String path;
  final String status; // minor, major, blocked
  final List<String> fixes;

  TestFile({
    required this.path,
    required this.status,
    required this.fixes,
  });
}