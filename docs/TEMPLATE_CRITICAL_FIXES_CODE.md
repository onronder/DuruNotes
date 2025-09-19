# Template Feature - Critical Fix Implementations

These are the exact code changes needed for Priority 1 fixes. Copy and paste these directly into your codebase.

---

## Fix 1: Add Analytics for Template Creation

### File: `lib/ui/modern_edit_note_screen.dart`

**Find this section (around line 1416-1464):**
```dart
Future<void> _saveAsTemplate() async {
  // ... existing code ...
  
  if (template == null) {
    throw Exception('Failed to create template');
  }

  if (!mounted) return;
  
  // Show success message
  _showInfoSnack('Template saved: ${template.title}');
```

**Replace with:**
```dart
Future<void> _saveAsTemplate() async {
  // ... existing code ...
  
  if (template == null) {
    throw Exception('Failed to create template');
  }

  // Track analytics event
  final analytics = ref.read(analyticsProvider);
  analytics.event('template_saved', properties: {
    'template_id': template.id,
    'source_note_id': widget.noteId ?? 'new_note',
    'tags_count': _currentTags.length,
    'has_body': cleanBody.isNotEmpty,
    'created_at': DateTime.now().toIso8601String(),
  });

  if (!mounted) return;
  
  // Show success message
  _showInfoSnack('Template saved: ${template.title}');
```

**Also update the catch block:**
```dart
} catch (e, stackTrace) {
  // Log error to monitoring
  final logger = ref.read(appLoggerProvider);
  logger.error('Failed to save template', 
    error: e,
    stackTrace: stackTrace,
    data: {
      'noteId': widget.noteId,
      'title': cleanTitle,
      'bodyLength': cleanBody.length,
    }
  );
  
  _showErrorSnack('Failed to save as template: $e');
```

---

## Fix 2: Prevent Template Re-seeding After Deletion

### File: `lib/services/template_initialization_service.dart`

**Replace the entire file with:**
```dart
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to initialize default templates for new users
class TemplateInitializationService {
  TemplateInitializationService({required this.notesRepository});
  
  final NotesRepository notesRepository;
  
  // Version tracking for template seeding
  static const String _seedingVersionKey = 'default_templates_version';
  static const String _hasSeededKey = 'has_seeded_templates';
  static const int currentVersion = 1;
  
  /// Check if user has any templates and create defaults if needed
  Future<void> initializeDefaultTemplates() async {
    try {
      // Get preferences
      final prefs = await SharedPreferences.getInstance();
      final seededVersion = prefs.getInt(_seedingVersionKey) ?? 0;
      final hasSeeded = prefs.getBool(_hasSeededKey) ?? false;
      
      // Check if user already has templates
      final existingTemplates = await notesRepository.listTemplates();
      
      if (existingTemplates.isNotEmpty) {
        debugPrint('User already has ${existingTemplates.length} templates');
        // Mark as seeded if not already
        if (!hasSeeded) {
          await prefs.setBool(_hasSeededKey, true);
          await prefs.setInt(_seedingVersionKey, currentVersion);
        }
        return;
      }
      
      // If we've seeded before but user deleted all templates, respect that
      if (hasSeeded && existingTemplates.isEmpty) {
        debugPrint('User has deleted all templates, not re-seeding');
        return;
      }
      
      // Only seed if never done before
      if (!hasSeeded) {
        debugPrint('Creating default templates for new user...');
        await _createDefaultTemplates();
        
        // Mark as seeded
        await prefs.setBool(_hasSeededKey, true);
        await prefs.setInt(_seedingVersionKey, currentVersion);
        debugPrint('Default templates initialized (v$currentVersion)');
      }
      
      // Handle future version updates
      if (seededVersion < currentVersion && seededVersion > 0) {
        // In future, we could add new templates or update existing ones
        debugPrint('Template version update available: v$seededVersion -> v$currentVersion');
        await prefs.setInt(_seedingVersionKey, currentVersion);
      }
      
    } catch (e) {
      debugPrint('Error initializing templates: $e');
      // Non-critical error, continue without templates
    }
  }
  
  Future<void> _createDefaultTemplates() async {
    // ... existing template creation code ...
  }
}
```

---

## Fix 3: Add Comprehensive Error Logging

### File: `lib/repository/notes_repository.dart`

**Update the `createTemplate` method (around line 430):**
```dart
Future<LocalNote?> createTemplate({
  required String title,
  required String body,
  List<String> tags = const [],
  Map<String, dynamic>? metadata,
}) async {
  try {
    final id = _uuid.v4();
    final now = DateTime.now();
    
    debugPrint('🔄 Creating template: "$title"');
    
    final template = LocalNote(
      id: id,
      title: title,
      body: body,
      noteType: NoteKind.template,
      deleted: false,
      isPinned: false,
      updatedAt: now,
      encryptedMetadata: metadata != null ? jsonEncode(metadata) : null,
    );
    
    await db.upsertNote(template);
    
    if (tags.isNotEmpty) {
      await db.replaceTagsForNote(id, tags.toSet());
    }
    
    await db.enqueue(id, 'upsert_note');
    
    debugPrint('✅ Template created locally: $id');
    return template;
    
  } catch (e, stackTrace) {
    // Use AppLogger for proper error tracking
    AppLogger().error('Failed to create template',
      error: e,
      stackTrace: stackTrace,
      data: {
        'title': title,
        'bodyLength': body.length,
        'tagsCount': tags.length,
        'hasMetadata': metadata != null,
      }
    );
    
    debugPrint('❌ Failed to create template: $e');
    return null;
  }
}
```

**Update the `createNoteFromTemplate` method:**
```dart
Future<LocalNote?> createNoteFromTemplate(String templateId) async {
  try {
    debugPrint('🔄 Creating note from template: $templateId');
    
    final template = await getNote(templateId);
    if (template == null || template.noteType != NoteKind.template) {
      throw StateError('Template not found: $templateId');
    }
    
    final tags = await getTagsForNote(templateId);
    final newId = _uuid.v4();
    final now = DateTime.now();
    
    final metadata = {
      'source': 'template',
      'sourceTemplateId': templateId,
      'sourceTemplateTitle': template.title,
    };
    
    final note = LocalNote(
      id: newId,
      title: template.title,
      body: template.body,
      noteType: NoteKind.note,
      deleted: false,
      isPinned: false,
      updatedAt: now,
      encryptedMetadata: jsonEncode(metadata),
    );
    
    await db.upsertNote(note);
    
    if (tags.isNotEmpty) {
      await db.replaceTagsForNote(newId, tags.toSet());
    }
    
    await db.enqueue(newId, 'upsert_note');
    
    debugPrint('✅ Note created from template: $newId');
    return note;
    
  } catch (e, stackTrace) {
    // Use AppLogger for proper error tracking
    AppLogger().error('Failed to create note from template',
      error: e,
      stackTrace: stackTrace,
      data: {
        'templateId': templateId,
        'errorType': e.runtimeType.toString(),
      }
    );
    
    debugPrint('❌ Failed to create note from template: $e');
    return null;
  }
}
```

---

## Fix 4: Add Template Deletion Method

### File: `lib/repository/notes_repository.dart`

**Add this new method:**
```dart
/// Delete a template (soft delete with sync)
Future<bool> deleteTemplate(String templateId) async {
  try {
    debugPrint('🗑️ Deleting template: $templateId');
    
    // Verify it's actually a template
    final template = await getNote(templateId);
    if (template == null || template.noteType != NoteKind.template) {
      throw StateError('Not a template: $templateId');
    }
    
    // Mark as deleted locally
    await db.markNoteDeleted(templateId);
    
    // Queue for remote deletion
    await db.enqueue(templateId, 'delete_note');
    
    debugPrint('✅ Template deleted: $templateId');
    return true;
    
  } catch (e, stackTrace) {
    AppLogger().error('Failed to delete template',
      error: e,
      stackTrace: stackTrace,
      data: {
        'templateId': templateId,
      }
    );
    
    debugPrint('❌ Failed to delete template: $e');
    return false;
  }
}
```

---

## Fix 5: Add Analytics Event Definitions

### File: `lib/services/analytics/analytics_service.dart`

**Add to the `AnalyticsEvents` class:**
```dart
class AnalyticsEvents {
  // ... existing events ...
  
  // Template events
  static const String templateSaved = 'template_saved';
  static const String templateUsed = 'template_used';
  static const String templateDeleted = 'template_deleted';
  static const String templateEdited = 'template_edited';
  static const String templatePickerOpened = 'template_picker_opened';
  static const String templatePickerCancelled = 'template_picker_cancelled';
}

class AnalyticsProperties {
  // ... existing properties ...
  
  // Template properties
  static const String templateId = 'template_id';
  static const String templateTitle = 'template_title';
  static const String sourceNoteId = 'source_note_id';
  static const String isDefaultTemplate = 'is_default_template';
  static const String templateCount = 'template_count';
}
```

---

## Testing Commands

After applying these fixes, test with:

```bash
# Run the app with debug info
flutter run --dart-define=SHOW_DEBUG_INFO=true

# Check for compilation errors
flutter analyze

# Run tests
flutter test

# Build for release
flutter build ios --release
flutter build apk --release
```

---

## Verification Checklist

After implementing these fixes:

1. **Analytics Verification**:
   - [ ] Create a template and verify `template_saved` event fires
   - [ ] Check event properties in analytics dashboard
   - [ ] Verify error tracking in Sentry

2. **Persistence Verification**:
   - [ ] Create templates on fresh install
   - [ ] Delete all templates
   - [ ] Restart app - templates should NOT recreate
   - [ ] Fresh install should still get default templates

3. **Error Logging Verification**:
   - [ ] Force a template creation error
   - [ ] Check Sentry for error report
   - [ ] Verify error context data

4. **Template Deletion**:
   - [ ] Call deleteTemplate method
   - [ ] Verify template marked as deleted
   - [ ] Verify sync queue entry created

---

## Rollback Plan

If issues arise after deployment:

1. **Analytics Issues**: Events can be filtered/ignored in analytics platform
2. **Persistence Issues**: Clear SharedPreferences key via remote config
3. **Error Spam**: Adjust Sentry sampling rate for template errors
4. **Delete Issues**: Revert deleteTemplate method, no data loss

All changes are backward compatible and can be safely rolled back.
