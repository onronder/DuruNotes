import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/native.dart';

void main() async {
  // Create a test database connection
  final db = AppDb(NativeDatabase.memory());
  final notesRepo = NotesRepository(
    db: db,
    cryptoBox: null, // Templates work locally without encryption
    noteApi: null,
  );

  // Create some default templates
  final templates = [
    {
      'title': '📝 Meeting Notes',
      'body': '''# Meeting Notes
**Date:** [Date]
**Attendees:** [Names]

## Agenda
- [ ] Item 1
- [ ] Item 2

## Discussion Points


## Action Items
- [ ] 

## Next Steps
''',
      'tags': ['meeting', 'work'],
    },
    {
      'title': '✅ Daily Standup',
      'body': '''# Daily Standup - [Date]

## Yesterday
- 

## Today
- 

## Blockers
- None

## Notes
''',
      'tags': ['daily', 'standup'],
    },
    {
      'title': '💡 Project Idea',
      'body': '''# Project: [Name]

## Problem Statement


## Proposed Solution


## Key Features
1. 
2. 
3. 

## Technical Considerations


## Next Steps
- [ ] Research
- [ ] Prototype
- [ ] Validate
''',
      'tags': ['project', 'ideas'],
    },
    {
      'title': '📚 Book Notes',
      'body': '''# Book: [Title]
**Author:** [Name]
**Started:** [Date]

## Key Takeaways


## Favorite Quotes
> 

## Personal Reflections


## Action Items
- [ ] 
''',
      'tags': ['reading', 'books'],
    },
  ];

  for (var template in templates) {
    await notesRepo.createTemplate(
      title: template['title'] as String,
      body: template['body'] as String,
      tags: template['tags'] as List<String>,
      metadata: {'isDefault': true},
    );
    print('Created template: ${template['title']}');
  }

  print('\n✅ Test templates created successfully!');
  print('Restart the app to see them in the template picker.');
}
