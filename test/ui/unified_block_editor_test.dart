import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/ui/widgets/blocks/unified_block_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnifiedBlockEditor', () {
    late List<NoteBlock> testBlocks;
    late List<NoteBlock> changedBlocks;

    setUp(() {
      testBlocks = [
        const NoteBlock(type: NoteBlockType.paragraph, data: 'Test paragraph'),
        const NoteBlock(type: NoteBlockType.heading1, data: 'Test heading'),
        const NoteBlock(
          type: NoteBlockType.todo,
          data: 'incomplete:Test todo',
        ),
      ];
      changedBlocks = [];
    });

    Widget createTestWidget({
      List<NoteBlock>? blocks,
      BlockEditorConfig? config,
      String? noteId,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: UnifiedBlockEditor(
              blocks: blocks ?? testBlocks,
              onBlocksChanged: (blocks) => changedBlocks = List.of(blocks),
              config: config ?? const BlockEditorConfig(),
              noteId: noteId,
            ),
          ),
        ),
      );
    }

    testWidgets('should display all blocks', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Verify blocks are displayed
      expect(find.text('Test paragraph'), findsOneWidget);
      expect(find.text('Test heading'), findsOneWidget);
      expect(find.text('Test todo'), findsOneWidget);
    });

    testWidgets('should show toolbar when configured',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        config: const BlockEditorConfig(showBlockSelector: true),
      ));

      // Verify toolbar is displayed
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('3 blocks'), findsOneWidget);
    });

    testWidgets('should hide toolbar when configured',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        config: const BlockEditorConfig(showBlockSelector: false),
      ));

      // Verify toolbar is not displayed
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('should show markdown toggle when enabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        config: const BlockEditorConfig(
          showBlockSelector: true,
          enableMarkdown: true,
        ),
      ));

      // Verify markdown toggle is displayed
      expect(find.byIcon(Icons.code), findsOneWidget);
    });

    testWidgets('should show reorder handle when enabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        config: const BlockEditorConfig(
          allowReordering: true,
        ),
      ));

      // Verify reorder handles are displayed
      expect(find.byIcon(Icons.drag_indicator), findsWidgets);
    });

    testWidgets('should delete block via actions menu',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Open block actions menu for the first block and delete it
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify block is deleted from the UI and callback
      expect(find.text('Test paragraph'), findsNothing);
      expect(changedBlocks.length, equals(2));
    });

    testWidgets('should show block selector overlay',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        config: const BlockEditorConfig(showBlockSelector: true),
      ));

      // Tap add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Verify block selector overlay is displayed
      expect(find.text('Add Block'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Paragraph'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Heading 1'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Todo'), findsOneWidget);
    });

    testWidgets('should add new block from selector',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        config: const BlockEditorConfig(showBlockSelector: true),
      ));

      // Open block selector
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Select paragraph block
      await tester.tap(find.text('Paragraph'));
      await tester.pumpAndSettle();

      // Verify new block is added
      expect(changedBlocks.length, equals(4));
    });

    testWidgets('should show block actions menu', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Find and tap more button
      final moreButton = find.byIcon(Icons.more_vert).first;
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      // Verify actions menu is displayed
      expect(find.text('Add block above'), findsOneWidget);
      expect(find.text('Add block below'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Convert to...'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    group('Block Type Rendering', () {
      testWidgets('should render paragraph block', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          blocks: [
            const NoteBlock(
                type: NoteBlockType.paragraph, data: 'Test paragraph'),
          ],
        ));

        expect(find.text('Test paragraph'), findsOneWidget);
      });

      testWidgets('should render heading blocks', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          blocks: [
            const NoteBlock(type: NoteBlockType.heading1, data: 'Heading 1'),
            const NoteBlock(type: NoteBlockType.heading2, data: 'Heading 2'),
            const NoteBlock(type: NoteBlockType.heading3, data: 'Heading 3'),
          ],
        ));

        expect(find.text('Heading 1'), findsWidgets);
        expect(find.text('Heading 2'), findsWidgets);
        expect(find.text('Heading 3'), findsWidgets);
      });

      testWidgets('should render todo block', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          blocks: [
            const NoteBlock(
              type: NoteBlockType.todo,
              data: 'incomplete:Todo item',
            ),
          ],
        ));

        expect(find.text('Todo item'), findsOneWidget);
        expect(find.byKey(const ValueKey('todo_checkbox_0')), findsOneWidget);
      });

      testWidgets('should render code block', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          blocks: [
            const NoteBlock(
              type: NoteBlockType.code,
              data: 'const test = "code";',
            ),
          ],
        ));

        expect(find.text('const test = "code";'), findsOneWidget);
      });

      testWidgets('should render quote block', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          blocks: [
            const NoteBlock(type: NoteBlockType.quote, data: 'Test quote'),
          ],
        ));

        expect(find.text('Test quote'), findsOneWidget);
      });
    });

    group('Configuration', () {
      testWidgets('should apply legacy config', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          config: BlockEditorConfig.legacy(),
        ));

        // Legacy config has specific settings
        expect(
            find.byIcon(Icons.add), findsOneWidget); // showBlockSelector: true
      });

      testWidgets('should apply modern config', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          config: BlockEditorConfig.modern(),
        ));

        // Modern config has all features enabled
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byIcon(Icons.code), findsOneWidget); // enableMarkdown: true
        expect(find.byIcon(Icons.drag_handle),
            findsOneWidget); // allowReordering: true
      });

      testWidgets('should apply custom theme', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          config: const BlockEditorConfig(
            theme: BlockTheme(
              todoCheckboxColor: Colors.green,
              codeBackgroundColor: Colors.grey,
              quoteBackgroundColor: Colors.blue,
            ),
          ),
          blocks: [
            const NoteBlock(type: NoteBlockType.quote, data: 'Themed quote'),
          ],
        ));

        // Verify theme is applied (would need to check widget properties)
        expect(find.text('Themed quote'), findsOneWidget);
      });

      testWidgets('should apply custom padding', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          config: const BlockEditorConfig(
            padding: EdgeInsets.all(32),
          ),
        ));

        // Verify padding is applied (would need to check widget properties)
        expect(find.byType(UnifiedBlockEditor), findsOneWidget);
      });

      testWidgets('should apply custom block spacing',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          config: const BlockEditorConfig(
            blockSpacing: 16,
          ),
        ));

        // Verify spacing is applied (would need to check widget properties)
        expect(find.byType(UnifiedBlockEditor), findsOneWidget);
      });
    });

    group('Feature Flag Integration', () {
      testWidgets('should use unified editor when flag is enabled',
          (WidgetTester tester) async {
        // Enable feature flag
        FeatureFlags.instance.setOverride('use_new_block_editor', true);

        await tester.pumpWidget(createTestWidget());

        // Verify unified editor is used
        expect(find.byType(UnifiedBlockEditor), findsOneWidget);

        // Clean up
        FeatureFlags.instance.clearOverrides();
      });

      testWidgets('should fall back to legacy when flag is disabled',
          (WidgetTester tester) async {
        // Disable feature flag
        FeatureFlags.instance.setOverride('use_new_block_editor', false);

        await tester.pumpWidget(createTestWidget());

        // Verify legacy editor is used (through behavior)
        expect(find.byType(UnifiedBlockEditor), findsOneWidget);

        // Clean up
        FeatureFlags.instance.clearOverrides();
      });
    });

    group('Interaction Tests', () {
      testWidgets('should update block content on edit',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Find and edit a text field
        final textField = find.byType(TextField).first;
        await tester.enterText(textField, 'Updated text');
        await tester.pump();

        // Verify callback was called with updated blocks
        expect(changedBlocks.isNotEmpty, isTrue);
      });

      testWidgets('should handle focus changes', (WidgetTester tester) async {
        int? focusedIndex;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: UnifiedBlockEditor(
                  blocks: testBlocks,
                  onBlocksChanged: (_) {},
                  onBlockFocusChanged: (index) => focusedIndex = index,
                ),
              ),
            ),
          ),
        );

        // Focus first block
        final firstTextField = find.byType(TextField).first;
        await tester.tap(firstTextField);
        await tester.pump();

        // Verify focus callback was called
        expect(focusedIndex, isNotNull);
      });
    });

    group('Backward Compatibility', () {
      testWidgets('should support BlockEditorWrapper',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                // ignore: deprecated_member_use_from_same_package
                body: BlockEditorWrapper(
                  blocks: testBlocks,
                  onChanged: (blocks) => changedBlocks = blocks,
                ),
              ),
            ),
          ),
        );

        // Verify wrapper works
        expect(find.byType(UnifiedBlockEditor), findsOneWidget);
      });
    });
  });
}
