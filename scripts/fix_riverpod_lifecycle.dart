#!/usr/bin/env dart
// ignore_for_file: avoid_print

// Automated Riverpod Provider Lifecycle Fix Script
//
// This script helps fix common Riverpod provider lifecycle issues:
// 1. Add .autoDispose to providers that need it
// 2. Identify ref.read in build methods
// 3. Find resources needing cleanup
//
// Usage:
//   dart run scripts/fix_riverpod_lifecycle.dart --dry-run
//   dart run scripts/fix_riverpod_lifecycle.dart --apply
//   dart run scripts/fix_riverpod_lifecycle.dart --category=feature-providers

import 'dart:io';

void main(List<String> arguments) {
  final dryRun =
      arguments.contains('--dry-run') || !arguments.contains('--apply');
  final category = arguments
      .firstWhere(
        (arg) => arg.startsWith('--category='),
        orElse: () => '--category=all',
      )
      .split('=')[1];

  print('╔════════════════════════════════════════════════════════════════╗');
  print('║  Riverpod Provider Lifecycle Fix Script                       ║');
  print('╚════════════════════════════════════════════════════════════════╝\n');
  print('Mode: ${dryRun ? '🔍 DRY RUN (no changes)' : '⚠️  APPLY FIXES'}');
  print('Category: $category\n');

  final fixer = RiverpodLifecycleFixer(dryRun: dryRun);

  switch (category) {
    case 'feature-providers':
      fixer.fixFeatureProviders();
      break;
    case 'ui-refread':
      fixer.findRefReadInBuild();
      break;
    case 'service-cleanup':
      fixer.findResourceLeaks();
      break;
    case 'all':
      fixer.fixFeatureProviders();
      fixer.findRefReadInBuild();
      fixer.findResourceLeaks();
      break;
    default:
      print('Unknown category: $category');
      print(
        'Valid categories: feature-providers, ui-refread, service-cleanup, all',
      );
      exit(1);
  }

  fixer.printSummary();
}

class RiverpodLifecycleFixer {
  final bool dryRun;
  int providersFixed = 0;
  int refReadIssues = 0;
  int resourceLeaks = 0;
  final List<String> fixes = [];
  final List<String> warnings = [];

  RiverpodLifecycleFixer({required this.dryRun});

  void fixFeatureProviders() {
    print('\n📦 Scanning feature provider files...\n');

    final featureProviderDirs = [
      'lib/features/notes/providers',
      'lib/features/tasks/providers',
      'lib/features/folders/providers',
      'lib/features/search/providers',
      'lib/features/templates/providers',
      'lib/features/sync/providers',
      'lib/features/auth/providers',
      'lib/features/settings/providers',
    ];

    for (final dir in featureProviderDirs) {
      final directory = Directory(dir);
      if (!directory.existsSync()) continue;

      final files = directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      for (final file in files) {
        _fixProvidersInFile(file);
      }
    }
  }

  void _fixProvidersInFile(File file) {
    final content = file.readAsStringSync();
    final lines = content.split('\n');
    var modified = false;
    final newLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      var newLine = line;

      // Fix FutureProvider without autoDispose
      if (line.contains('FutureProvider<') &&
          !line.contains('autoDispose') &&
          !line.contains('//') && // Not commented
          !_isGlobalProvider(lines, i)) {
        newLine = line.replaceFirst(
          'FutureProvider<',
          'FutureProvider.autoDispose<',
        );
        if (newLine != line) {
          modified = true;
          providersFixed++;
          fixes.add(
            '${file.path}:${i + 1} - Added autoDispose to FutureProvider',
          );
        }
      }

      // Fix FutureProvider.family without autoDispose
      if (line.contains('FutureProvider.family<') &&
          !line.contains('autoDispose') &&
          !line.contains('//')) {
        newLine = line.replaceFirst(
          'FutureProvider.family<',
          'FutureProvider.autoDispose.family<',
        );
        if (newLine != line) {
          modified = true;
          providersFixed++;
          fixes.add(
            '${file.path}:${i + 1} - Added autoDispose to FutureProvider.family',
          );
        }
      }

      // Fix StreamProvider without autoDispose
      if (line.contains('StreamProvider<') &&
          !line.contains('autoDispose') &&
          !line.contains('//') &&
          !_isGlobalProvider(lines, i)) {
        newLine = line.replaceFirst(
          'StreamProvider<',
          'StreamProvider.autoDispose<',
        );
        if (newLine != line) {
          modified = true;
          providersFixed++;
          fixes.add(
            '${file.path}:${i + 1} - Added autoDispose to StreamProvider',
          );
        }
      }

      // Fix StreamProvider.family without autoDispose
      if (line.contains('StreamProvider.family<') &&
          !line.contains('autoDispose') &&
          !line.contains('//')) {
        newLine = line.replaceFirst(
          'StreamProvider.family<',
          'StreamProvider.autoDispose.family<',
        );
        if (newLine != line) {
          modified = true;
          providersFixed++;
          fixes.add(
            '${file.path}:${i + 1} - Added autoDispose to StreamProvider.family',
          );
        }
      }

      // Fix StateProvider without autoDispose
      if (line.contains('StateProvider<') &&
          !line.contains('autoDispose') &&
          !line.contains('//') &&
          !_isGlobalProvider(lines, i) &&
          _isUIStateProvider(lines, i)) {
        newLine = line.replaceFirst(
          'StateProvider<',
          'StateProvider.autoDispose<',
        );
        if (newLine != line) {
          modified = true;
          providersFixed++;
          fixes.add(
            '${file.path}:${i + 1} - Added autoDispose to StateProvider',
          );
        }
      }

      newLines.add(newLine);
    }

    if (modified && !dryRun) {
      file.writeAsStringSync(newLines.join('\n'));
      print('✅ Fixed: ${file.path} ($providersFixed providers)');
    } else if (modified) {
      print('🔍 Would fix: ${file.path}');
    }
  }

  bool _isGlobalProvider(List<String> lines, int index) {
    // Look at provider name and comments to determine if it's global
    final providerLine = lines[index];

    // Check for global provider patterns
    final globalPatterns = [
      'appDbProvider',
      'supabaseClientProvider',
      'loggerProvider',
      'analyticsProvider',
      'cryptoBoxProvider',
      'keyManagerProvider',
      'authStateChangesProvider',
      'userIdProvider',
      'themeModeProvider',
      'localeProvider',
      'analyticsSettingsProvider',
      'Repository',
      'Service',
      'Client',
    ];

    for (final pattern in globalPatterns) {
      if (providerLine.contains(pattern)) {
        return true;
      }
    }

    // Check comments above
    if (index > 0) {
      final previousLine = lines[index - 1];
      if (previousLine.contains('global') ||
          previousLine.contains('singleton') ||
          previousLine.contains('keep alive') ||
          previousLine.contains('shared')) {
        return true;
      }
    }

    return false;
  }

  bool _isUIStateProvider(List<String> lines, int index) {
    // UI state providers should use autoDispose
    final providerLine = lines[index];

    final uiPatterns = [
      'filter',
      'search',
      'current',
      'selected',
      'visible',
      'editing',
      'loading',
      'Form',
      'Dialog',
      'Sheet',
    ];

    for (final pattern in uiPatterns) {
      if (providerLine.toLowerCase().contains(pattern.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  void findRefReadInBuild() {
    print('\n🔍 Scanning for ref.read in build methods...\n');

    final uiFiles = Directory('lib/ui')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    for (final file in uiFiles) {
      final content = file.readAsStringSync();
      final lines = content.split('\n');

      var inBuildMethod = false;
      var braceCount = 0;

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Detect start of build method
        if (line.contains('Widget build(') || line.contains('Widget build (')) {
          inBuildMethod = true;
          braceCount = 0;
        }

        if (inBuildMethod) {
          // Count braces to track scope
          braceCount += '{'.allMatches(line).length;
          braceCount -= '}'.allMatches(line).length;

          // Check for ref.read (but allow in callbacks)
          if (line.contains('ref.read(') && !_isInCallback(lines, i)) {
            refReadIssues++;
            warnings.add(
              '⚠️  ${file.path}:${i + 1} - ref.read() in build method\n'
              '    Should use ref.watch() instead\n'
              '    Line: ${line.trim()}',
            );
          }

          // Exit build method when braces balance
          if (braceCount == 0 && inBuildMethod) {
            inBuildMethod = false;
          }
        }
      }
    }

    if (warnings.isNotEmpty) {
      print(
        '\n⚠️  Found $refReadIssues instances of ref.read in build methods:\n',
      );
      for (final warning in warnings) {
        print(warning);
        print('');
      }
    } else {
      print('✅ No ref.read issues found in UI build methods');
    }
  }

  bool _isInCallback(List<String> lines, int index) {
    // Simple heuristic: if previous lines contain callback markers
    final context = lines
        .sublist(
          (index - 5).clamp(0, lines.length),
          (index + 1).clamp(0, lines.length),
        )
        .join('\n');

    return context.contains('onPressed') ||
        context.contains('onTap') ||
        context.contains('onChanged') ||
        context.contains('onSubmitted') ||
        context.contains('listener') ||
        context.contains('callback') ||
        context.contains('=>');
  }

  void findResourceLeaks() {
    print('\n🔧 Scanning for resource leaks...\n');

    final serviceFiles = Directory('lib/services')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    for (final file in serviceFiles) {
      final content = file.readAsStringSync();
      final hasStreamController = content.contains('StreamController');
      final hasTimer =
          content.contains('Timer(') || content.contains('Timer.periodic');
      final hasSubscription = content.contains('.listen(');
      final hasDispose =
          content.contains('dispose()') || content.contains('close()');

      if ((hasStreamController || hasTimer || hasSubscription) && !hasDispose) {
        resourceLeaks++;
        warnings.add(
          '🔴 ${file.path}\n'
          '   Has resources but missing dispose():\n'
          '   ${hasStreamController ? '   - StreamController ✗\n' : ''}'
          '   ${hasTimer ? '   - Timer ✗\n' : ''}'
          '   ${hasSubscription ? '   - Subscription ✗\n' : ''}',
        );
      }
    }

    if (resourceLeaks > 0) {
      print('\n🔴 Found $resourceLeaks files with potential resource leaks:\n');
      for (final warning in warnings.skip(refReadIssues)) {
        print(warning);
        print('');
      }
    } else {
      print('✅ No obvious resource leaks found');
    }
  }

  void printSummary() {
    print(
      '\n╔════════════════════════════════════════════════════════════════╗',
    );
    print('║  Summary                                                       ║');
    print(
      '╚════════════════════════════════════════════════════════════════╝\n',
    );

    print('Providers fixed: $providersFixed');
    print('ref.read issues found: $refReadIssues');
    print('Potential resource leaks: $resourceLeaks');

    if (dryRun) {
      print('\n💡 Run with --apply to apply fixes');
    } else {
      print('\n✅ Fixes applied!');
    }

    print('\n📊 Next steps:');
    print('  1. Review changes with: git diff');
    print('  2. Run tests: flutter test');
    print('  3. Check for compilation errors: flutter analyze');
    print('  4. Fix ref.read issues manually (cannot be automated)');
    print('  5. Add ref.onDispose to services with resources');
  }
}
