# Note Templates Feature Guide

## 🎉 How to Use Note Templates in Duru Notes

### What Are Templates?
Templates are reusable note structures that help you quickly create notes with predefined formats. Perfect for recurring note types like meeting notes, daily standups, project plans, etc.

## 📝 Creating Templates

### Method 1: Save Current Note as Template
1. Open any note in the editor
2. Tap the **⋮** (more options) menu in the top-right corner
3. Select **"Save as Template"**
4. Your note is now saved as a template!

### Method 2: Default Templates
When you first launch the app, we automatically create 5 default templates for you:
- 📝 **Meeting Notes** - Structured meeting documentation
- ✅ **Daily Standup** - Daily progress tracking
- 💡 **Project Planning** - Comprehensive project documentation
- 📚 **Book Notes** - Reading notes and reflections
- 🎯 **Weekly Review** - Weekly accomplishments and planning

## 📱 Using Templates

### Creating a Note from Template
1. From the notes list, tap the **+** FAB button
2. The FAB will expand to show options
3. Tap **"From Template"** (document icon)
4. A bottom sheet will appear showing:
   - **Blank Note** option (for regular notes)
   - All your saved templates with previews
5. Tap any template to instantly create a new note with that structure
6. The new note opens in the editor, ready for you to fill in

## 🔄 Template Syncing
- Templates sync across all your devices
- Templates are stored with `noteType=template` in the database
- They're hidden from regular note lists
- Templates count separately from your regular notes

## 🎨 Template Features

### What's Preserved in Templates:
- Title structure
- Body formatting (markdown)
- Tags
- Overall structure and placeholders

### What's NOT Preserved:
- Specific dates/times (use placeholders like [Date])
- Personal information
- Completed checkboxes (reset to unchecked)
- Attachments

## 💡 Tips for Creating Good Templates

1. **Use Placeholders**: Add [Date], [Name], [Topic] etc. for parts you'll fill in
2. **Include Structure**: Headers, sections, tables, checklists
3. **Add Tags**: Templates preserve tags for easy organization
4. **Keep It Generic**: Make templates reusable for multiple scenarios
5. **Iterate**: Update templates as you discover better structures

## 🛠️ Technical Details

### Database Implementation
- Templates use the same `notes` table with `note_type='template'`
- Local SQLite: Schema version 10 with `noteType` column
- Supabase: `note_type` column with CHECK constraint
- Filtering: `noteIsVisible()` helper excludes templates from regular queries

### Repository Methods
```dart
// List all templates
await notesRepository.listTemplates()

// Create a new template
await notesRepository.createTemplate(
  title: "Template Name",
  body: "Template content",
  tags: ["tag1", "tag2"]
)

// Create note from template
await notesRepository.createNoteFromTemplate(templateId)
```

## 🔍 Troubleshooting

**Q: I don't see the "From Template" button**
A: Make sure you have the latest version of the app. The FAB should expand when tapped to show the template option.

**Q: Templates aren't syncing**
A: Templates sync like regular notes. Check your internet connection and sync status.

**Q: Can I edit/delete templates?**
A: Currently, templates are permanent once created. Edit functionality coming soon.

**Q: How many templates can I have?**
A: No limit! Create as many as you need.

## 🚀 Future Enhancements (Planned)
- Edit existing templates
- Delete templates
- Template categories/folders
- Share templates with others
- Template marketplace
- Template versioning
- Template analytics (usage tracking)

## 📊 Current Status
✅ **Implemented:**
- Backend database support
- Create templates from notes
- Create notes from templates
- Default templates for new users
- Template syncing
- UI for template selection

🔜 **Coming Soon:**
- Template management screen
- Edit/delete templates
- Template sharing
- Template categories

---

**Last Updated:** January 2025
**Feature Version:** 1.0
