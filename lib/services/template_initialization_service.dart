import 'package:duru_notes/data/local/app_db.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Service to initialize default templates
class TemplateInitializationService {
  static Future<void> initializeDefaultTemplates(AppDb db) async {
    final templates = await db.getAllTemplates();

    // Only initialize if no templates exist
    if (templates.isNotEmpty) return;

    final now = DateTime.now();
    final uuid = Uuid();

    // Default templates
    final defaultTemplates = [
      LocalTemplatesCompanion(
        id: Value(uuid.v4()),
        title: Value('📝 Meeting Notes'),
        body: Value('''# Meeting Notes - {{date}}

## Attendees
- {{attendees}}

## Agenda
1. {{topic1}}
2. {{topic2}}
3. {{topic3}}

## Discussion Points
-

## Action Items
- [ ] {{action1}}
- [ ] {{action2}}

## Next Steps
- Next meeting: {{nextMeetingDate}}
'''),
        tags: Value('["meeting", "notes", "work"]'),
        isSystem: Value(true),
        category: Value('meeting'),
        description: Value('Standard meeting notes template'),
        icon: Value('meeting_room'),
        sortOrder: Value(1),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),

      LocalTemplatesCompanion(
        id: Value(uuid.v4()),
        title: Value('✅ Daily Standup'),
        body: Value('''# Daily Standup - {{date}}

## Yesterday
- {{yesterday_work}}

## Today
- {{today_plan}}

## Blockers
- {{blockers:None}}

## Notes
-
'''),
        tags: Value('["daily", "standup", "agile"]'),
        isSystem: Value(true),
        category: Value('work'),
        description: Value('Daily standup template'),
        icon: Value('today'),
        sortOrder: Value(2),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),

      LocalTemplatesCompanion(
        id: Value(uuid.v4()),
        title: Value('🎯 Weekly Review'),
        body: Value('''# Weekly Review - Week of {{weekStartDate}}

## Accomplishments
- ✅ {{accomplishment1}}
- ✅ {{accomplishment2}}
- ✅ {{accomplishment3}}

## Challenges
- {{challenge1}}
- {{challenge2}}

## Next Week's Goals
1. {{goal1}}
2. {{goal2}}
3. {{goal3}}

## Notes & Reflections
{{reflections}}

## Metrics
- Tasks Completed: {{tasksCompleted}}
- Hours Worked: {{hoursWorked}}
'''),
        tags: Value('["weekly", "review", "planning"]'),
        isSystem: Value(true),
        category: Value('planning'),
        description: Value('Weekly review and planning template'),
        icon: Value('calendar_view_week'),
        sortOrder: Value(3),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),

      LocalTemplatesCompanion(
        id: Value(uuid.v4()),
        title: Value('💡 Project Planning'),
        body: Value('''# Project: {{projectName}}

## Overview
{{projectDescription}}

## Goals
1. {{goal1}}
2. {{goal2}}
3. {{goal3}}

## Timeline
- Start Date: {{startDate}}
- End Date: {{endDate}}
- Duration: {{duration}}

## Team
- Project Lead: {{projectLead}}
- Team Members: {{teamMembers}}

## Milestones
1. {{milestone1}} - {{date1}}
2. {{milestone2}} - {{date2}}
3. {{milestone3}} - {{date3}}

## Resources Needed
- {{resource1}}
- {{resource2}}

## Risks
- {{risk1}}
- {{risk2}}

## Success Criteria
- {{criteria1}}
- {{criteria2}}
'''),
        tags: Value('["project", "planning", "management"]'),
        isSystem: Value(true),
        category: Value('planning'),
        description: Value('Project planning template'),
        icon: Value('rocket_launch'),
        sortOrder: Value(4),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),

      LocalTemplatesCompanion(
        id: Value(uuid.v4()),
        title: Value('📚 Book Notes'),
        body: Value('''# Book Notes: {{bookTitle}}
**Author:** {{author}}
**Date Started:** {{dateStarted}}
**Date Finished:** {{dateFinished:In Progress}}

## Summary
{{summary}}

## Key Takeaways
1. {{takeaway1}}
2. {{takeaway2}}
3. {{takeaway3}}

## Favorite Quotes
> "{{quote1}}"
> — Page {{page1}}

> "{{quote2}}"
> — Page {{page2}}

## Personal Reflections
{{reflections}}

## Action Items
- [ ] {{action1}}
- [ ] {{action2}}

## Rating: {{rating}}/5
'''),
        tags: Value('["reading", "books", "learning"]'),
        isSystem: Value(true),
        category: Value('personal'),
        description: Value('Book reading notes template'),
        icon: Value('menu_book'),
        sortOrder: Value(5),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    ];

    // Insert all templates
    for (final template in defaultTemplates) {
      await db.into(db.localTemplates).insert(template);
    }
  }
}