import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duru_notes_app/ui/widgets/blocks/paragraph_block_widget.dart';
import 'package:duru_notes_app/models/note_block.dart';

void main() {
  group('ParagraphBlockWidget', () {
    late TextEditingController controller;
    late NoteBlock testBlock;
    NoteBlock? changedBlock;
    bool deletePressed = false;

    setUp(() {
      controller = TextEditingController(text: 'Test paragraph content');
      testBlock = const NoteBlock(
        type: NoteBlockType.paragraph,
        data: 'Test paragraph content',
      );
      changedBlock = null;
      deletePressed = false;
    });

    tearDown(() {
      controller.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ParagraphBlockWidget(
            block: testBlock,
            controller: controller,
            onChanged: (block) => changedBlock = block,
            onDelete: () => deletePressed = true,
          ),
        ),
      );
    }

    testWidgets('should display paragraph content correctly', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Test paragraph content'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('should show hint text when empty', (tester) async {
      controller.text = '';
      testBlock = const NoteBlock(type: NoteBlockType.paragraph, data: '');

      await tester.pumpWidget(createTestWidget());

      expect(find.text('Paragraph'), findsOneWidget);
    });

    testWidgets('should call onChanged when text is edited', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), 'Updated content');
      await tester.pump();

      expect(changedBlock, isNotNull);
      expect(changedBlock!.data, equals('Updated content'));
      expect(changedBlock!.type, equals(NoteBlockType.paragraph));
    });

    testWidgets('should call onDelete when delete button is pressed', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(deletePressed, isTrue);
    });

    testWidgets('should apply custom styling when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParagraphBlockWidget(
              block: testBlock,
              controller: controller,
              onChanged: (block) => changedBlock = block,
              onDelete: () => deletePressed = true,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.fontSize, equals(18.0));
      expect(textField.style?.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('should display custom hint text', (tester) async {
      controller.text = '';
      testBlock = const NoteBlock(type: NoteBlockType.paragraph, data: '');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParagraphBlockWidget(
              block: testBlock,
              controller: controller,
              onChanged: (block) => changedBlock = block,
              onDelete: () => deletePressed = true,
              hintText: 'Custom hint',
            ),
          ),
        ),
      );

      expect(find.text('Custom hint'), findsOneWidget);
    });
  });

  group('HeadingBlockWidget', () {
    late TextEditingController controller;
    late NoteBlock testBlock;

    setUp(() {
      controller = TextEditingController(text: 'Test heading');
      testBlock = const NoteBlock(
        type: NoteBlockType.heading1,
        data: 'Test heading',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    Widget createHeadingWidget(int level, NoteBlockType type) {
      return MaterialApp(
        home: Scaffold(
          body: HeadingBlockWidget(
            block: NoteBlock(type: type, data: 'Test heading'),
            controller: controller,
            onChanged: (_) {},
            onDelete: () {},
            level: level,
          ),
        ),
      );
    }

    testWidgets('should apply correct styling for H1', (tester) async {
      await tester.pumpWidget(createHeadingWidget(1, NoteBlockType.heading1));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.fontSize, equals(24.0));
      expect(textField.style?.fontWeight, equals(FontWeight.bold));
      expect(find.text('Heading 1'), findsOneWidget);
    });

    testWidgets('should apply correct styling for H2', (tester) async {
      await tester.pumpWidget(createHeadingWidget(2, NoteBlockType.heading2));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.fontSize, equals(20.0));
      expect(textField.style?.fontWeight, equals(FontWeight.bold));
      expect(find.text('Heading 2'), findsOneWidget);
    });

    testWidgets('should apply correct styling for H3', (tester) async {
      await tester.pumpWidget(createHeadingWidget(3, NoteBlockType.heading3));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.fontSize, equals(18.0));
      expect(textField.style?.fontWeight, equals(FontWeight.w600));
      expect(find.text('Heading 3'), findsOneWidget);
    });

    testWidgets('should handle invalid heading levels gracefully', (tester) async {
      await tester.pumpWidget(createHeadingWidget(99, NoteBlockType.heading1));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.fontSize, isNull);
      expect(textField.style?.fontWeight, isNull);
    });
  });
}
