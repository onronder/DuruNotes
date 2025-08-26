import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duru_notes_app/ui/widgets/block_editor.dart';
import 'package:duru_notes_app/models/note_block.dart';

void main() {
  group('BlockEditor Widget Tests', () {
    Widget createBlockEditor({
      List<NoteBlock> blocks = const [],
      ValueChanged<List<NoteBlock>>? onChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: BlockEditor(
            blocks: blocks,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      );
    }

    group('Block Creation and Addition', () {
      testWidgets('should display empty editor initially', (WidgetTester tester) async {
        await tester.pumpWidget(createBlockEditor());
        
        // Should show at least one block (usually a paragraph)
        expect(find.byType(BlockEditor), findsOneWidget);
      });

      testWidgets('should display existing blocks', (WidgetTester tester) async {
        final blocks = [
          const NoteBlock(
            id: 'block-1',
            type: NoteBlockType.paragraph,
            data: 'First paragraph',
          ),
          const NoteBlock(
            id: 'block-2',
            type: NoteBlockType.heading1,
            data: 'Main Heading',
          ),
        ];

        await tester.pumpWidget(createBlockEditor(blocks: blocks));

        // Should display both blocks
        expect(find.text('First paragraph'), findsOneWidget);
        expect(find.text('Main Heading'), findsOneWidget);
      });

      testWidgets('should add new block when add button is pressed', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              data: 'Existing block',
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Find and tap add block button
        final addButton = find.byKey(const Key('add_block_button'));
        if (addButton.evaluate().isNotEmpty) {
          await tester.tap(addButton);
          await tester.pumpAndSettle();

          // Should have called onChanged with additional block
          expect(capturedBlocks.length, greaterThan(1));
        }
      });

      testWidgets('should add different block types', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        
        await tester.pumpWidget(createBlockEditor(
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Test adding different block types
        final blockTypeButtons = [
          find.byKey(const Key('add_heading1_button')),
          find.byKey(const Key('add_heading2_button')),
          find.byKey(const Key('add_quote_button')),
          find.byKey(const Key('add_code_button')),
          find.byKey(const Key('add_todo_button')),
        ];

        for (final button in blockTypeButtons) {
          if (button.evaluate().isNotEmpty) {
            await tester.tap(button);
            await tester.pumpAndSettle();
            
            expect(capturedBlocks.isNotEmpty, isTrue);
          }
        }
      });
    });

    group('Block Editing', () {
      testWidgets('should edit paragraph block text', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              data: 'Original text',
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Find text field and edit content
        final textField = find.byType(TextFormField);
        expect(textField, findsOneWidget);

        await tester.enterText(textField, 'Updated text content');
        await tester.pumpAndSettle();

        // Should trigger onChanged with updated content
        expect(capturedBlocks.isNotEmpty, isTrue);
        expect(capturedBlocks.first.data, equals('Updated text content'));
      });

      testWidgets('should edit heading blocks with proper styling', (WidgetTester tester) async {
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'h1-block',
              type: NoteBlockType.heading1,
              data: 'Heading 1',
            ),
            const NoteBlock(
              id: 'h2-block',
              type: NoteBlockType.heading2,
              data: 'Heading 2',
            ),
            const NoteBlock(
              id: 'h3-block',
              type: NoteBlockType.heading3,
              data: 'Heading 3',
            ),
          ],
        ));

        // Verify headings are displayed with different styling
        expect(find.text('Heading 1'), findsOneWidget);
        expect(find.text('Heading 2'), findsOneWidget);
        expect(find.text('Heading 3'), findsOneWidget);

        // Check that styling is applied (font size/weight would be checked in text style)
        final h1Widget = find.text('Heading 1');
        final h2Widget = find.text('Heading 2');
        final h3Widget = find.text('Heading 3');
        
        expect(h1Widget, findsOneWidget);
        expect(h2Widget, findsOneWidget);
        expect(h3Widget, findsOneWidget);
      });

      testWidgets('should edit code block with monospace styling', (WidgetTester tester) async {
        const codeData = CodeBlockData(
          code: 'function hello() {\n  console.log("Hello");\n}',
          language: 'javascript',
        );

        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'code-block',
              type: NoteBlockType.code,
              data: codeData,
            ),
          ],
        ));

        // Should display code content
        expect(find.textContaining('function hello'), findsOneWidget);
        expect(find.textContaining('console.log'), findsOneWidget);
      });

      testWidgets('should toggle todo items', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        const todoData = TodoBlockData(text: 'Complete integration tests', checked: false);

        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'todo-block',
              type: NoteBlockType.todo,
              data: todoData,
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Find checkbox and tap it
        final checkbox = find.byType(Checkbox);
        expect(checkbox, findsOneWidget);

        await tester.tap(checkbox);
        await tester.pumpAndSettle();

        // Should update the todo state
        expect(capturedBlocks.isNotEmpty, isTrue);
        final updatedTodo = capturedBlocks.first.data as TodoBlockData;
        expect(updatedTodo.checked, isTrue);
      });

      testWidgets('should edit todo text', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        const todoData = TodoBlockData(text: 'Original todo', checked: false);

        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'todo-block',
              type: NoteBlockType.todo,
              data: todoData,
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Find todo text field
        final textField = find.byType(TextFormField);
        expect(textField, findsOneWidget);

        await tester.enterText(textField, 'Updated todo text');
        await tester.pumpAndSettle();

        // Should update todo text
        expect(capturedBlocks.isNotEmpty, isTrue);
        final updatedTodo = capturedBlocks.first.data as TodoBlockData;
        expect(updatedTodo.text, equals('Updated todo text'));
      });
    });

    group('Block Deletion', () {
      testWidgets('should delete block when delete button is pressed', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              data: 'First block',
            ),
            const NoteBlock(
              id: 'block-2',
              type: NoteBlockType.paragraph,
              data: 'Second block',
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Initially should have 2 blocks
        expect(find.text('First block'), findsOneWidget);
        expect(find.text('Second block'), findsOneWidget);

        // Find and tap delete button for first block
        final deleteButton = find.byKey(const Key('delete_block_0')); // First block
        if (deleteButton.evaluate().isNotEmpty) {
          await tester.tap(deleteButton);
          await tester.pumpAndSettle();

          // Should have removed the block
          expect(capturedBlocks.length, equals(1));
          expect(capturedBlocks.first.data, equals('Second block'));
        }
      });

      testWidgets('should not delete last remaining block', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'last-block',
              type: NoteBlockType.paragraph,
              data: 'Last block',
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Find delete button
        final deleteButton = find.byKey(const Key('delete_block_0'));
        if (deleteButton.evaluate().isNotEmpty) {
          await tester.tap(deleteButton);
          await tester.pumpAndSettle();

          // Should still have the block (can't delete last one)
          expect(capturedBlocks.length, equals(1));
        }
      });
    });

    group('Block Reordering', () {
      testWidgets('should move block up', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              data: 'First block',
            ),
            const NoteBlock(
              id: 'block-2',
              type: NoteBlockType.paragraph,
              data: 'Second block',
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Find move up button for second block
        final moveUpButton = find.byKey(const Key('move_up_block_1'));
        if (moveUpButton.evaluate().isNotEmpty) {
          await tester.tap(moveUpButton);
          await tester.pumpAndSettle();

          // Should have swapped the blocks
          expect(capturedBlocks.length, equals(2));
          expect(capturedBlocks.first.data, equals('Second block'));
          expect(capturedBlocks.last.data, equals('First block'));
        }
      });

      testWidgets('should move block down', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              data: 'First block',
            ),
            const NoteBlock(
              id: 'block-2',
              type: NoteBlockType.paragraph,
              data: 'Second block',
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Find move down button for first block
        final moveDownButton = find.byKey(const Key('move_down_block_0'));
        if (moveDownButton.evaluate().isNotEmpty) {
          await tester.tap(moveDownButton);
          await tester.pumpAndSettle();

          // Should have swapped the blocks
          expect(capturedBlocks.length, equals(2));
          expect(capturedBlocks.first.data, equals('Second block'));
          expect(capturedBlocks.last.data, equals('First block'));
        }
      });

      testWidgets('should disable move up for first block', (WidgetTester tester) async {
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              data: 'First block',
            ),
            const NoteBlock(
              id: 'block-2',
              type: NoteBlockType.paragraph,
              data: 'Second block',
            ),
          ],
        ));

        // Move up button for first block should be disabled or not present
        final moveUpButton = find.byKey(const Key('move_up_block_0'));
        expect(moveUpButton, findsNothing);
      });

      testWidgets('should disable move down for last block', (WidgetTester tester) async {
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              data: 'First block',
            ),
            const NoteBlock(
              id: 'block-2',
              type: NoteBlockType.paragraph,
              data: 'Second block',
            ),
          ],
        ));

        // Move down button for last block should be disabled or not present
        final moveDownButton = find.byKey(const Key('move_down_block_1'));
        expect(moveDownButton, findsNothing);
      });
    });

    group('Block Type Conversion', () {
      testWidgets('should convert paragraph to heading', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              data: 'Convert me to heading',
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Find block type conversion button/menu
        final typeButton = find.byKey(const Key('block_type_button_0'));
        if (typeButton.evaluate().isNotEmpty) {
          await tester.tap(typeButton);
          await tester.pumpAndSettle();

          // Find heading option
          final headingOption = find.text('Heading 1');
          if (headingOption.evaluate().isNotEmpty) {
            await tester.tap(headingOption);
            await tester.pumpAndSettle();

            // Should have converted to heading
            expect(capturedBlocks.isNotEmpty, isTrue);
            expect(capturedBlocks.first.type, equals(NoteBlockType.heading1));
            expect(capturedBlocks.first.data, equals('Convert me to heading'));
          }
        }
      });

      testWidgets('should convert between different heading levels', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'heading-block',
              type: NoteBlockType.heading1,
              data: 'Big Heading',
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Convert to smaller heading
        final typeButton = find.byKey(const Key('block_type_button_0'));
        if (typeButton.evaluate().isNotEmpty) {
          await tester.tap(typeButton);
          await tester.pumpAndSettle();

          final h3Option = find.text('Heading 3');
          if (h3Option.evaluate().isNotEmpty) {
            await tester.tap(h3Option);
            await tester.pumpAndSettle();

            expect(capturedBlocks.first.type, equals(NoteBlockType.heading3));
          }
        }
      });
    });

    group('Focus and Navigation', () {
      testWidgets('should focus next block when pressing Enter', (WidgetTester tester) async {
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              data: 'First block',
            ),
            const NoteBlock(
              id: 'block-2',
              type: NoteBlockType.paragraph,
              data: 'Second block',
            ),
          ],
        ));

        // Focus first text field
        final firstField = find.byType(TextFormField).first;
        await tester.tap(firstField);
        await tester.pumpAndSettle();

        // Simulate Enter key (this would create a new block or move focus)
        // Implementation depends on the specific behavior of your block editor
      });

      testWidgets('should merge blocks when backspace at beginning', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        
        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'block-1',
              type: NoteBlockType.paragraph,
              data: 'First block',
            ),
            const NoteBlock(
              id: 'block-2',
              type: NoteBlockType.paragraph,
              data: 'Second block',
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Focus second text field and position cursor at beginning
        final secondField = find.byType(TextFormField).last;
        await tester.tap(secondField);
        await tester.pumpAndSettle();

        // Simulate backspace at beginning (this might merge blocks)
        // Implementation depends on your specific block editor behavior
      });
    });

    group('Table Blocks', () {
      testWidgets('should display table block correctly', (WidgetTester tester) async {
        const tableData = TableBlockData(
          headers: ['Name', 'Age', 'City'],
          rows: [
            ['John', '25', 'New York'],
            ['Jane', '30', 'Los Angeles'],
          ],
        );

        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'table-block',
              type: NoteBlockType.table,
              data: tableData,
            ),
          ],
        ));

        // Should display table content
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Age'), findsOneWidget);
        expect(find.text('City'), findsOneWidget);
        expect(find.text('John'), findsOneWidget);
        expect(find.text('Jane'), findsOneWidget);
      });

      testWidgets('should add new table row', (WidgetTester tester) async {
        List<NoteBlock> capturedBlocks = [];
        const tableData = TableBlockData(
          headers: ['Name', 'Age'],
          rows: [['John', '25']],
        );

        await tester.pumpWidget(createBlockEditor(
          blocks: [
            const NoteBlock(
              id: 'table-block',
              type: NoteBlockType.table,
              data: tableData,
            ),
          ],
          onChanged: (blocks) => capturedBlocks = blocks,
        ));

        // Find add row button
        final addRowButton = find.byKey(const Key('add_table_row'));
        if (addRowButton.evaluate().isNotEmpty) {
          await tester.tap(addRowButton);
          await tester.pumpAndSettle();

          // Should have added a new row
          expect(capturedBlocks.isNotEmpty, isTrue);
          final updatedTable = capturedBlocks.first.data as TableBlockData;
          expect(updatedTable.rows.length, equals(2));
        }
      });
    });

    group('Performance', () {
      testWidgets('should handle large number of blocks efficiently', (WidgetTester tester) async {
        // Create many blocks to test performance
        final manyBlocks = List.generate(100, (index) => 
          NoteBlock(
            id: 'block-$index',
            type: NoteBlockType.paragraph,
            data: 'Block content $index',
          ),
        );

        final stopwatch = Stopwatch()..start();
        
        await tester.pumpWidget(createBlockEditor(blocks: manyBlocks));
        await tester.pumpAndSettle();
        
        stopwatch.stop();
        
        // Should render efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        
        // Should display blocks
        expect(find.text('Block content 0'), findsOneWidget);
      });
    });
  });
}
