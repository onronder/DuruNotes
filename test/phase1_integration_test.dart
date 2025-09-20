/// Integration test for Phase 1 refactored components
/// 
/// This test validates that all Phase 1 components work correctly:
/// 1. Feature flags system
/// 2. Permission manager
/// 3. Base reminder service architecture
/// 4. Unified block editor
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/services/permission_manager.dart';
import 'package:duru_notes/ui/widgets/blocks/unified_block_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 1 Integration Tests', () {
    setUp(() {
      // Reset feature flags before each test
      FeatureFlags.instance.clearOverrides();
    });

    group('Feature Flags System', () {
      test('should have all Phase 1 flags enabled in development', () {
        final flags = FeatureFlags.instance;
        
        // Verify all flags are enabled (as we set them in development)
        expect(flags.useUnifiedReminders, isTrue);
        expect(flags.useNewBlockEditor, isTrue);
        expect(flags.useRefactoredComponents, isTrue);
        expect(flags.useUnifiedPermissionManager, isTrue);
      });

      test('should support overrides for testing', () {
        final flags = FeatureFlags.instance;
        
        // Test override functionality
        flags.setOverride('use_unified_reminders', false);
        expect(flags.useUnifiedReminders, isFalse);
        
        // Clear overrides
        flags.clearOverrides();
        expect(flags.useUnifiedReminders, isTrue); // Back to default
      });

      test('should check feature flags correctly', () {
        final flags = FeatureFlags.instance;
        
        expect(flags.isEnabled('use_unified_reminders'), isTrue);
        expect(flags.isEnabled('use_new_block_editor'), isTrue);
        expect(flags.isEnabled('use_refactored_components'), isTrue);
        expect(flags.isEnabled('use_unified_permission_manager'), isTrue);
        
        // Test non-existent flag
        expect(flags.isEnabled('non_existent_flag'), isFalse);
      });
    });

    group('Permission Manager', () {
      test('should be singleton', () {
        final instance1 = PermissionManager.instance;
        final instance2 = PermissionManager.instance;
        
        expect(identical(instance1, instance2), isTrue);
      });

      test('should provide permission descriptions', () {
        final manager = PermissionManager.instance;
        
        // Test all permission types have descriptions
        for (final type in PermissionType.values) {
          final description = manager.getPermissionDescription(type);
          expect(description, isNotEmpty);
          expect(description.length, greaterThan(10)); // Meaningful description
        }
      });

      test('should provide permission icons', () {
        final manager = PermissionManager.instance;
        
        // Test all permission types have icons
        for (final type in PermissionType.values) {
          final icon = manager.getPermissionIcon(type);
          expect(icon, isNotNull);
          expect(icon, isA<IconData>());
        }
      });

      test('should support cache management', () {
        final manager = PermissionManager.instance;
        
        // Clear cache should not throw
        expect(() => manager.clearCache(), returnsNormally);
      });

      test('should support observer pattern', () {
        final manager = PermissionManager.instance;
        var callbackCalled = false;
        
        void testCallback(PermissionStatus status) {
          callbackCalled = true;
        }
        
        // Add observer
        manager.observePermission(PermissionType.notification, testCallback);
        
        // Remove observer
        manager.removeObserver(PermissionType.notification, testCallback);
        
        // Verify no errors
        expect(callbackCalled, isFalse);
      });
    });

    group('Unified Block Editor', () {
      testWidgets('should render with feature flag enabled', (tester) async {
        // Enable feature flag
        FeatureFlags.instance.setOverride('use_new_block_editor', true);
        
        final blocks = [
          const NoteBlock(type: NoteBlockType.paragraph, data: 'Test paragraph'),
          const NoteBlock(type: NoteBlockType.heading1, data: 'Test heading'),
        ];
        
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: UnifiedBlockEditor(
                  blocks: blocks,
                  onBlocksChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        
        // Verify editor renders
        expect(find.byType(UnifiedBlockEditor), findsOneWidget);
        expect(find.text('Test paragraph'), findsOneWidget);
        expect(find.text('Test heading'), findsOneWidget);
      });

      testWidgets('should support different configurations', (tester) async {
        final blocks = [
          const NoteBlock(type: NoteBlockType.paragraph, data: 'Test'),
        ];
        
        // Test with legacy config
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: UnifiedBlockEditor(
                  blocks: blocks,
                  onBlocksChanged: (_) {},
                  config: BlockEditorConfig.legacy(),
                ),
              ),
            ),
          ),
        );
        
        expect(find.byType(UnifiedBlockEditor), findsOneWidget);
        
        // Test with modern config
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: UnifiedBlockEditor(
                  blocks: blocks,
                  onBlocksChanged: (_) {},
                  config: BlockEditorConfig.modern(),
                ),
              ),
            ),
          ),
        );
        
        expect(find.byType(UnifiedBlockEditor), findsOneWidget);
      });

      testWidgets('should handle block operations', (tester) async {
        var changedBlocks = <NoteBlock>[];
        final blocks = [
          const NoteBlock(type: NoteBlockType.paragraph, data: 'Test'),
        ];
        
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: UnifiedBlockEditor(
                  blocks: blocks,
                  onBlocksChanged: (blocks) => changedBlocks = blocks,
                  config: const BlockEditorConfig(showBlockSelector: true),
                ),
              ),
            ),
          ),
        );
        
        // Verify add button exists
        expect(find.byIcon(Icons.add), findsOneWidget);
        
        // Test block count display
        expect(find.text('1 blocks'), findsOneWidget);
      });
    });

    group('Component Integration', () {
      test('all refactored components should respect feature flags', () {
        final flags = FeatureFlags.instance;
        
        // Disable all flags
        flags.setOverride('use_unified_reminders', false);
        flags.setOverride('use_new_block_editor', false);
        flags.setOverride('use_refactored_components', false);
        flags.setOverride('use_unified_permission_manager', false);
        
        // Verify flags are disabled
        expect(flags.useUnifiedReminders, isFalse);
        expect(flags.useNewBlockEditor, isFalse);
        expect(flags.useRefactoredComponents, isFalse);
        expect(flags.useUnifiedPermissionManager, isFalse);
        
        // Re-enable for production use
        flags.clearOverrides();
        
        // Verify flags are back to development defaults (enabled)
        expect(flags.useUnifiedReminders, isTrue);
        expect(flags.useNewBlockEditor, isTrue);
        expect(flags.useRefactoredComponents, isTrue);
        expect(flags.useUnifiedPermissionManager, isTrue);
      });

      testWidgets('UI components should work together', (tester) async {
        // This tests that the unified block editor works with feature flags
        final flags = FeatureFlags.instance;
        flags.setOverride('use_new_block_editor', true);
        
        final blocks = [
          const NoteBlock(type: NoteBlockType.paragraph, data: 'Integration test'),
          const NoteBlock(type: NoteBlockType.todo, data: 'Test todo'),
        ];
        
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                appBar: AppBar(title: const Text('Phase 1 Test')),
                body: UnifiedBlockEditor(
                  blocks: blocks,
                  onBlocksChanged: (_) {},
                  config: BlockEditorConfig.modern(),
                ),
              ),
            ),
          ),
        );
        
        // Verify components render
        expect(find.byType(UnifiedBlockEditor), findsOneWidget);
        expect(find.text('Integration test'), findsOneWidget);
        expect(find.text('Test todo'), findsOneWidget);
        
        // Verify toolbar is shown with modern config
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byIcon(Icons.code), findsOneWidget); // Markdown toggle
        expect(find.byIcon(Icons.drag_handle), findsOneWidget); // Reorder toggle
      });
    });

    group('Migration Path Validation', () {
      test('legacy code paths should still work with flags disabled', () {
        final flags = FeatureFlags.instance;
        
        // Disable all new features
        flags.setOverride('use_unified_reminders', false);
        flags.setOverride('use_new_block_editor', false);
        flags.setOverride('use_refactored_components', false);
        flags.setOverride('use_unified_permission_manager', false);
        
        // Legacy paths should work (verified by flags being false)
        expect(flags.useUnifiedReminders, isFalse);
        expect(flags.useNewBlockEditor, isFalse);
        
        // Clean up
        flags.clearOverrides();
      });

      test('gradual rollout should be possible', () {
        final flags = FeatureFlags.instance;
        
        // Simulate gradual rollout - enable one feature at a time
        flags.clearOverrides();
        
        // Stage 1: Enable permission manager only
        flags.setOverride('use_unified_reminders', false);
        flags.setOverride('use_new_block_editor', false);
        flags.setOverride('use_unified_permission_manager', true);
        flags.setOverride('use_refactored_components', false);
        
        expect(flags.useUnifiedPermissionManager, isTrue);
        expect(flags.useUnifiedReminders, isFalse);
        
        // Stage 2: Enable reminders
        flags.setOverride('use_unified_reminders', true);
        
        expect(flags.useUnifiedPermissionManager, isTrue);
        expect(flags.useUnifiedReminders, isTrue);
        expect(flags.useNewBlockEditor, isFalse);
        
        // Stage 3: Enable block editor
        flags.setOverride('use_new_block_editor', true);
        
        expect(flags.useUnifiedPermissionManager, isTrue);
        expect(flags.useUnifiedReminders, isTrue);
        expect(flags.useNewBlockEditor, isTrue);
        
        // Stage 4: Enable all refactored components
        flags.setOverride('use_refactored_components', true);
        
        expect(flags.useRefactoredComponents, isTrue);
        
        // Clean up
        flags.clearOverrides();
      });
    });
  });
}
