import 'package:duru_notes/repository/notes_repository.dart';
import 'package:flutter/foundation.dart';

/// Service to initialize default templates for new users
class TemplateInitializationService {
  TemplateInitializationService({required this.notesRepository});
  
  final NotesRepository notesRepository;
  
  /// Check if user has any templates and create defaults if needed
  Future<void> initializeDefaultTemplates() async {
    try {
      // Check if user already has templates
      final existingTemplates = await notesRepository.listTemplates();
      
      if (existingTemplates.isNotEmpty) {
        debugPrint('User already has ${existingTemplates.length} templates');
        return;
      }
      
      debugPrint('Creating default templates for new user...');
      
      // Create default templates
      await _createDefaultTemplates();
      
    } catch (e) {
      debugPrint('Error initializing templates: $e');
      // Non-critical error, continue without templates
    }
  }
  
  Future<void> _createDefaultTemplates() async {
    final templates = [
      {
        'title': '📝 Meeting Notes',
        'body': '''# Meeting Notes
**Date:** [Date]
**Time:** [Time]
**Attendees:** [Names]

## Agenda
- [ ] Item 1
- [ ] Item 2
- [ ] Item 3

## Discussion Points

### Topic 1
- Key points discussed
- Decisions made

### Topic 2
- Key points discussed
- Decisions made

## Action Items
| Task | Owner | Due Date |
|------|-------|----------|
| | | |

## Next Steps
- 

## Follow-up Meeting
- Date: 
- Time: 
''',
        'tags': ['meeting', 'work'],
      },
      {
        'title': '✅ Daily Standup',
        'body': '''# Daily Standup - [Date]

## Yesterday
- Completed:
  - 
- Challenges:
  - 

## Today
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

## Blockers
- None

## Notes
- 
''',
        'tags': ['daily', 'standup', 'work'],
      },
      {
        'title': '💡 Project Planning',
        'body': '''# Project: [Name]

## Overview
Brief description of the project and its goals.

## Problem Statement
What problem are we solving?

## Proposed Solution
How will we solve this problem?

## Key Features
1. **Feature 1**
   - Description
   - User benefit
   
2. **Feature 2**
   - Description
   - User benefit

3. **Feature 3**
   - Description
   - User benefit

## Technical Requirements
- Platform: 
- Technology stack: 
- APIs needed: 
- Database requirements: 

## Timeline
| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Research | | |
| Design | | |
| Development | | |
| Testing | | |
| Launch | | |

## Success Metrics
- [ ] Metric 1
- [ ] Metric 2
- [ ] Metric 3

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| | | |

## Next Steps
1. 
2. 
3. 
''',
        'tags': ['project', 'planning', 'ideas'],
      },
      {
        'title': '📚 Book Notes',
        'body': '''# Book: [Title]
**Author:** [Name]
**Started:** [Date]
**Finished:** [Date]
**Rating:** ⭐⭐⭐⭐⭐

## Summary
Brief overview of the book's main ideas.

## Key Takeaways
1. **Takeaway 1**
   - Why it matters
   
2. **Takeaway 2**
   - Why it matters
   
3. **Takeaway 3**
   - Why it matters

## Favorite Quotes
> "Quote 1" - Page [X]

> "Quote 2" - Page [X]

> "Quote 3" - Page [X]

## Personal Reflections
How does this book relate to my life/work?

What will I do differently after reading this?

## Action Items
- [ ] Apply concept X to my work
- [ ] Research more about Y
- [ ] Share insight Z with team

## Related Books
- 
- 
''',
        'tags': ['reading', 'books', 'learning'],
      },
      {
        'title': '🎯 Weekly Review',
        'body': '''# Weekly Review - Week of [Date]

## Wins This Week 🎉
- 
- 
- 

## Challenges Faced 💪
- 
- 
- 

## Goals Completed ✅
- [ ] Goal 1
- [ ] Goal 2
- [ ] Goal 3

## Goals for Next Week 🎯
- [ ] 
- [ ] 
- [ ] 

## Key Learnings 📚
1. 
2. 
3. 

## Gratitude 🙏
Three things I'm grateful for this week:
1. 
2. 
3. 

## Areas for Improvement 📈
- 
- 

## Priority Focus for Next Week
Main focus: 

## Notes & Reflections
''',
        'tags': ['review', 'weekly', 'personal'],
      },
    ];
    
    for (final template in templates) {
      try {
        await notesRepository.createTemplate(
          title: template['title'] as String,
          body: template['body'] as String,
          tags: template['tags'] as List<String>,
          metadata: {
            'isDefault': true,
            'version': '1.0',
          },
        );
        debugPrint('Created template: ${template['title']}');
      } catch (e) {
        debugPrint('Failed to create template ${template['title']}: $e');
      }
    }
    
    debugPrint('Default templates initialization complete');
  }
}
