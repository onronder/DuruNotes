import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duru_notes_app/ui/widgets/blocks/todo_block_widget.dart';
import 'package:duru_notes_app/models/note_block.dart';

void main() {
  group('TodoBlockWidget', () {
    late TextEditingController controller;
    late NoteBlock testBlock;
    NoteBlock? changedBlock;
    bool deletePressed = false;

    setUp(() {
      controller = TextEditingController(text: 'Test todo item');
      testBlock = const NoteBlock(
        type: NoteBlockType.todo,
        data: TodoBlockData(text: 'Test todo item', checked: false),
      );
      changedBlock = null;
      deletePressed = false;
    });

    tearDown(() {
      controller.dispose();
    });

    Widget createTestWidget({NoteBlock? customBlock}) {
      return MaterialApp(
        home: Scaffold(
          body: TodoBlockWidget(
            block: customBlock ?? testBlock,
            controller: controller,
            onChanged: (block) => changedBlock = block,
            onDelete: () => deletePressed = true,
          ),
        ),
      );
    }

    testWidgets('should display todo content correctly', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Test todo item'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('should show unchecked checkbox for incomplete todo', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('should show checked checkbox for completed todo', (tester) async {
      final completedBlock = const NoteBlock(
        type: NoteBlockType.todo,
        data: TodoBlockData(text: 'Completed todo', checked: true),
      );

      await tester.pumpWidget(createTestWidget(customBlock: completedBlock));

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('should call onChanged when checkbox is toggled', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(changedBlock, isNotNull);
      final todoData = changedBlock!.data as TodoBlockData;
      expect(todoData.checked, isTrue);
      expect(todoData.text, equals('Test todo item'));
    });

    testWidgets('should call onChanged when text is edited', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), 'Updated todo text');
      await tester.pump();

      expect(changedBlock, isNotNull);
      final todoData = changedBlock!.data as TodoBlockData;
      expect(todoData.text, equals('Updated todo text'));
      expect(todoData.checked, isFalse);
    });

    testWidgets('should call onDelete when delete button is pressed', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(deletePressed, isTrue);
    });

    testWidgets('should apply strikethrough style for completed todos', (tester) async {
      final completedBlock = const NoteBlock(
        type: NoteBlockType.todo,
        data: TodoBlockData(text: 'Completed todo', checked: true),
      );
      controller.text = 'Completed todo';

      await tester.pumpWidget(createTestWidget(customBlock: completedBlock));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.decoration, equals(TextDecoration.lineThrough));
    });

    testWidgets('should apply normal style for incomplete todos', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.decoration, equals(TextDecoration.none));
    });

    testWidgets('should show hint text when empty', (tester) async {
      controller.text = '';
      final emptyBlock = const NoteBlock(
        type: NoteBlockType.todo,
        data: TodoBlockData(text: '', checked: false),
      );

      await tester.pumpWidget(createTestWidget(customBlock: emptyBlock));

      expect(find.text('Todo'), findsOneWidget);
    });

    testWidgets('should maintain checkbox state when toggling multiple times', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Toggle to checked
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      TodoBlockData todoData = changedBlock!.data as TodoBlockData;
      expect(todoData.checked, isTrue);

      // Update the widget with new state
      final checkedBlock = NoteBlock(
        type: NoteBlockType.todo,
        data: todoData,
      );
      await tester.pumpWidget(createTestWidget(customBlock: checkedBlock));

      // Toggle back to unchecked
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      todoData = changedBlock!.data as TodoBlockData;
      expect(todoData.checked, isFalse);
    });
  });

  group('TodoSummaryWidget', () {
    testWidgets('should display todo summary correctly', (tester) async {
      final todos = [
        const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: 'Todo 1', checked: true),
        ),
        const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: 'Todo 2', checked: false),
        ),
        const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: 'Todo 3', checked: true),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodoSummaryWidget(todos: todos),
          ),
        ),
      );

      expect(find.text('Todo List'), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });

    testWidgets('should hide progress when showProgress is false', (tester) async {
      final todos = [
        const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: 'Todo 1', checked: true),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodoSummaryWidget(
              todos: todos,
              showProgress: false,
            ),
          ),
        ),
      );

      expect(find.text('Todo List'), findsOneWidget);
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('should show empty widget for no todos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TodoSummaryWidget(todos: []),
          ),
        ),
      );

      expect(find.byType(Card), findsNothing);
    });

    testWidgets('should calculate progress correctly', (tester) async {
      final todos = [
        const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: 'Todo 1', checked: true),
        ),
        const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: 'Todo 2', checked: true),
        ),
        const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: 'Todo 3', checked: false),
        ),
        const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: 'Todo 4', checked: false),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodoSummaryWidget(todos: todos),
          ),
        ),
      );

      expect(find.text('2 of 4'), findsOneWidget);
      
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, equals(0.5)); // 2/4 = 0.5
    });

    testWidgets('should ignore non-todo blocks', (tester) async {
      final blocks = [
        const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: 'Todo 1', checked: true),
        ),
        const NoteBlock(
          type: NoteBlockType.paragraph,
          data: 'Regular paragraph',
        ),
        const NoteBlock(
          type: NoteBlockType.todo,
          data: TodoBlockData(text: 'Todo 2', checked: false),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodoSummaryWidget(todos: blocks),
          ),
        ),
      );

      expect(find.text('1 of 2'), findsOneWidget); // Only counts todos
    });
  });
}
