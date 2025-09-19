# Note Template Implementation Fix Prompts

Based on the audit findings, here are implementation prompts to address each issue:

---

## 🔴 Priority 1: Critical Fixes

### 1. Add Analytics for Template Creation

**Finding**: No "template_saved" event when users create templates.

**Implementation Prompt**:
```
You are adding analytics tracking for template creation in Duru Notes.

TASK:
In lib/ui/modern_edit_note_screen.dart, update the _saveAsTemplate method to track template creation:

1. After successfully creating the template (line ~1448), add:
   ```dart
   // Track analytics
   final analytics = ref.read(analyticsProvider);
   analytics.event('template_saved', properties: {
     'template_id': template.id,
     'source_note_id': widget.noteId ?? 'new_note',
     'tags_count': _currentTags.length,
     'has_metadata': true,
   });
   ```

2. Also add error tracking in the catch block:
   ```dart
   // Log error to monitoring
   logger.error('Failed to save template', error: e, data: {
     'noteId': widget.noteId,
     'title': cleanTitle,
   });
   ```

ACCEPTANCE CRITERIA:
- template_saved event tracked on success
- Errors logged to Sentry/monitoring
- Properties include relevant metadata
```

### 2. Fix Template Re-seeding Issue

**Finding**: Templates recreate after deletion because no persistent flag is stored.

**Implementation Prompt**:
```
You are fixing the template re-seeding issue to prevent unwanted recreation of deleted templates.

CONTEXT:
Currently, default templates are recreated if user deletes all templates because the app only checks if templates exist, not if they were previously seeded.

TASKS:
1. In lib/services/template_initialization_service.dart:
   - Add SharedPreferences dependency
   - Check and store seeding version
   - Only seed if version is newer

2. Implementation:
   ```dart
   import 'package:shared_preferences/shared_preferences.dart';
   
   class TemplateInitializationService {
     static const String _seedingVersionKey = 'default_templates_version';
     static const int currentVersion = 1;
     
     Future<void> initializeDefaultTemplates() async {
       final prefs = await SharedPreferences.getInstance();
       final seededVersion = prefs.getInt(_seedingVersionKey) ?? 0;
       
       if (seededVersion >= currentVersion) {
         debugPrint('Templates already seeded (v$seededVersion)');
         return;
       }
       
       // Check if user has any templates
       final existingTemplates = await notesRepository.listTemplates();
       
       // Only seed if no templates AND never seeded before
       if (existingTemplates.isEmpty && seededVersion == 0) {
         await _createDefaultTemplates();
         await prefs.setInt(_seedingVersionKey, currentVersion);
         debugPrint('Seeded default templates v$currentVersion');
       } else if (seededVersion < currentVersion) {
         // Future: Handle template updates
         await prefs.setInt(_seedingVersionKey, currentVersion);
       }
     }
   }
   ```

ACCEPTANCE CRITERIA:
- Templates only seed once on first app use
- Deleting all templates doesn't trigger re-seeding
- Version stored in SharedPreferences
- Future-proof for template updates
```

---

## 🟡 Priority 2: User Experience Improvements

### 3. Add Template Management UI

**Finding**: No way to edit or delete templates once created.

**Implementation Prompt**:
```
You are adding template management capabilities to Duru Notes.

TASKS:
1. In lib/ui/widgets/template_picker_sheet.dart, add long-press actions:
   ```dart
   Widget _buildTemplateOption(...) {
     return Material(
       child: InkWell(
         onTap: () => onTap(),
         onLongPress: () => _showTemplateOptions(template),
         ...
       ),
     );
   }
   
   void _showTemplateOptions(LocalNote template) {
     showModalBottomSheet(
       context: context,
       builder: (context) => Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           ListTile(
             leading: Icon(Icons.edit),
             title: Text('Edit Template'),
             onTap: () {
               Navigator.pop(context);
               _editTemplate(template);
             },
           ),
           ListTile(
             leading: Icon(Icons.delete, color: Colors.red),
             title: Text('Delete Template'),
             onTap: () {
               Navigator.pop(context);
               _deleteTemplate(template);
             },
           ),
         ],
       ),
     );
   }
   ```

2. Add template editing support in ModernEditNoteScreen:
   - Add isEditingTemplate flag
   - Preserve noteType when saving
   - Show "Editing Template" in header

3. Add delete functionality in NotesRepository:
   ```dart
   Future<bool> deleteTemplate(String templateId) async {
     try {
       await db.markNoteDeleted(templateId);
       await db.enqueue(templateId, 'delete_note');
       debugPrint('Template deleted: $templateId');
       return true;
     } catch (e) {
       debugPrint('Failed to delete template: $e');
       return false;
     }
   }
   ```

ACCEPTANCE CRITERIA:
- Long-press on template shows edit/delete options
- Edit opens template in editor (preserves template type)
- Delete removes template with confirmation
- Changes sync across devices
```

### 4. Add Localization Support

**Finding**: Template UI strings are hardcoded in English.

**Implementation Prompt**:
```
You are adding proper localization for template features.

TASKS:
1. In lib/l10n/app_en.arb, add:
   ```json
   {
     "templatePickerTitle": "Choose a Template",
     "templatePickerSubtitle": "Start with a template or blank note",
     "blankNoteOption": "Blank Note",
     "blankNoteDescription": "Start with an empty note",
     "noTemplatesTitle": "No Templates Yet",
     "noTemplatesDescription": "Create your first template to reuse common note structures",
     "templatesSection": "TEMPLATES",
     "saveAsTemplate": "Save as Template",
     "fromTemplate": "From Template",
     "templateSaved": "Template saved: {title}",
     "@templateSaved": {
       "placeholders": {
         "title": {"type": "String"}
       }
     },
     "failedToSaveTemplate": "Failed to save as template",
     "cannotSaveEmptyTemplate": "Cannot save empty note as template",
     "editTemplate": "Edit Template",
     "deleteTemplate": "Delete Template",
     "confirmDeleteTemplate": "Delete this template?",
     "templateDeleted": "Template deleted"
   }
   ```

2. In lib/l10n/app_tr.arb, add Turkish translations:
   ```json
   {
     "templatePickerTitle": "Şablon Seçin",
     "templatePickerSubtitle": "Şablonla veya boş notla başlayın",
     "blankNoteOption": "Boş Not",
     "blankNoteDescription": "Boş bir notla başla",
     "noTemplatesTitle": "Henüz Şablon Yok",
     "noTemplatesDescription": "Sık kullandığınız yapıları tekrar kullanmak için ilk şablonunuzu oluşturun",
     "templatesSection": "ŞABLONLAR",
     "saveAsTemplate": "Şablon Olarak Kaydet",
     "fromTemplate": "Şablondan",
     "templateSaved": "Şablon kaydedildi: {title}",
     "failedToSaveTemplate": "Şablon kaydedilemedi",
     "cannotSaveEmptyTemplate": "Boş not şablon olarak kaydedilemez",
     "editTemplate": "Şablonu Düzenle",
     "deleteTemplate": "Şablonu Sil",
     "confirmDeleteTemplate": "Bu şablon silinsin mi?",
     "templateDeleted": "Şablon silindi"
   }
   ```

3. Update all UI strings to use localization:
   ```dart
   // Instead of:
   Text('Choose a Template')
   // Use:
   Text(AppLocalizations.of(context).templatePickerTitle)
   ```

ACCEPTANCE CRITERIA:
- All template UI strings localized
- Supports EN and TR languages
- No hardcoded strings remain
- Follows existing app localization patterns
```

---

## 🟢 Priority 3: Monitoring & Polish

### 5. Add Error Logging to Sentry

**Finding**: Template errors only show snackbars, not logged to monitoring.

**Implementation Prompt**:
```
You are adding proper error logging for template operations.

CONTEXT:
Template failures should be logged to Sentry for monitoring, not just debugPrint.

TASKS:
1. Update all template error handling to use AppLogger:
   ```dart
   // In lib/repository/notes_repository.dart
   } catch (e, stackTrace) {
     logger.error('Failed to create template', 
       error: e,
       stackTrace: stackTrace,
       data: {
         'title': title,
         'hasBody': body.isNotEmpty,
         'tagsCount': tags.length,
       }
     );
     return null;
   }
   ```

2. In lib/ui/modern_edit_note_screen.dart _saveAsTemplate:
   ```dart
   } catch (e, stackTrace) {
     logger.error('Template save failed',
       error: e,
       stackTrace: stackTrace,
       data: {
         'sourceNoteId': widget.noteId,
         'hasContent': cleanBody.isNotEmpty,
       }
     );
     _showErrorSnack('Failed to save as template: $e');
   }
   ```

3. In template initialization service:
   ```dart
   } catch (e, stackTrace) {
     logger.error('Template initialization failed',
       error: e,
       stackTrace: stackTrace,
       data: {
         'templateCount': templates.length,
         'isFirstRun': seededVersion == 0,
       }
     );
   }
   ```

ACCEPTANCE CRITERIA:
- All template errors logged to Sentry
- Error context includes relevant data
- Stack traces preserved
- User still sees friendly error messages
```

### 6. Improve Template Icons & UI Polish

**Finding**: Same icon used for templates and documents, could be more distinctive.

**Implementation Prompt**:
```
You are improving the visual distinction of templates in the UI.

TASKS:
1. Update template icons to be more distinctive:
   ```dart
   // In template picker
   icon: Icons.dashboard_customize_rounded, // For templates
   // or
   icon: Icons.layers_rounded, // Alternative template icon
   
   // Keep document icon for blank note
   icon: Icons.note_add_rounded, // For blank note
   ```

2. Add visual differentiation for default vs custom templates:
   ```dart
   Widget _buildTemplateOption(...) {
     final isDefault = template.encryptedMetadata?.contains('isDefault') ?? false;
     
     return Container(
       decoration: BoxDecoration(
         border: Border(
           left: BorderSide(
             width: 3,
             color: isDefault 
               ? colorScheme.primary.withOpacity(0.3)
               : Colors.transparent,
           ),
         ),
       ),
       child: InkWell(
         child: Row(
           children: [
             Container(
               decoration: BoxDecoration(
                 color: isDefault
                   ? colorScheme.primaryContainer
                   : colorScheme.tertiaryContainer,
               ),
               child: Icon(
                 isDefault 
                   ? Icons.auto_awesome_rounded
                   : Icons.dashboard_customize_rounded,
               ),
             ),
             // Add badge for default templates
             if (isDefault)
               Padding(
                 padding: EdgeInsets.only(left: 8),
                 child: Chip(
                   label: Text('Default', style: TextStyle(fontSize: 10)),
                   visualDensity: VisualDensity.compact,
                 ),
               ),
           ],
         ),
       ),
     );
   }
   ```

3. Add template count to FAB label:
   ```dart
   // In notes_list_screen.dart
   final templateCount = ref.watch(templateListProvider).maybeWhen(
     data: (templates) => templates.length,
     orElse: () => 0,
   );
   
   _buildModernMiniFAB(
     icon: Icons.dashboard_customize_rounded,
     label: templateCount > 0 
       ? 'From Template ($templateCount)'
       : 'From Template',
   );
   ```

ACCEPTANCE CRITERIA:
- Templates have distinct icon from documents
- Default templates visually different from custom
- Template count shown in FAB
- Consistent with Material 3 design
```

---

## 💡 Optional Enhancements

### 7. Template Categories (Future)

**Implementation Prompt**:
```
Future enhancement to organize templates by category:
- Work templates
- Personal templates
- Meeting templates
- Project templates

Add 'category' field to template metadata and group in picker.
```

### 8. Template Sharing (Future)

**Implementation Prompt**:
```
Future enhancement for template marketplace:
- Export template as JSON
- Import template from file/URL
- Share templates between users
- Template versioning
```

---

## ✅ Already Fixed Issues

The following issues mentioned in the audit are already addressed in the current implementation:

1. **Tag Visibility**: Tags are properly filtered with `AND n.note_type = 0` in all tag queries
2. **Task Extraction**: Tasks use `noteIsVisible()` which filters out templates

---

## 📊 Implementation Priority

1. **Immediate** (Do now):
   - Add template_saved analytics
   - Fix re-seeding issue
   - Add error logging

2. **Short-term** (This week):
   - Add template management UI
   - Add localization

3. **Long-term** (Future releases):
   - Template categories
   - Template sharing/marketplace
   - Advanced template features
