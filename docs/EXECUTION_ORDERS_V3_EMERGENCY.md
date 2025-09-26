# 📋 EXECUTION ORDERS V3.0 - EMERGENCY PROTOCOL
**Status:** CRITICAL BUILD FAILURE
**Errors:** 670 compilation errors
**Timeline:** 3-4 weeks minimum

---

## 🚨 IMMEDIATE EXECUTION (WEEK 1)

### DAY 1: Type System Emergency Fix
```bash
# Morning (4 hours)
1. cd /Users/onronder/duru-notes
2. Create type converter utilities:
   mkdir -p lib/core/converters
   touch lib/core/converters/note_converter.dart
   touch lib/core/converters/folder_converter.dart

3. Implement converters:
   ```dart
   // note_converter.dart
   class NoteConverter {
     static domain.Note fromLocal(LocalNote local) {
       return domain.Note(
         id: local.id,
         title: local.title,
         body: local.body,
         updatedAt: local.updatedAt,
         deleted: local.deleted,
         isPinned: local.isPinned,
         noteType: local.noteType,
         version: local.version,
         userId: local.userId ?? '',
         folderId: null,
         encryptedMetadata: local.encryptedMetadata,
         attachmentMeta: local.attachmentMeta,
         metadata: local.metadata,
         tags: [],
         links: [],
       );
     }

     static LocalNote toLocal(domain.Note note) {
       return LocalNote(
         id: note.id,
         title: note.title,
         body: note.body,
         updatedAt: note.updatedAt,
         deleted: note.deleted,
         isPinned: note.isPinned,
         noteType: note.noteType,
         version: note.version,
         userId: note.userId,
         encryptedMetadata: note.encryptedMetadata,
         attachmentMeta: note.attachmentMeta,
         metadata: note.metadata,
       );
     }
   }
   ```

# Afternoon (4 hours)
4. Fix notes_list_screen.dart type casts:
   - Open lib/ui/notes_list_screen.dart
   - Import converters
   - Fix lines: 854, 860, 900, 907, 916, 941, 948, 962, 1004

5. Verify progress:
   dart analyze 2>&1 | grep "^  error" | wc -l
   # Should show <650 errors
```

### DAY 2: Continue Type Fixes
```bash
# Morning
1. Fix remaining notes_list_screen.dart errors:
   - Lines: 1073-1074, 1674, 1776, 1826, 2354
   - Lines: 2687-2709, 2802, 2810, 3352, 3488-3492

2. Fix unified_template_service.dart:
   - Line 226: Cast iteration variable
   - Line 314-319: Add null safety checks

# Afternoon
3. Fix modern_edit_note_screen.dart:
   - Line 1659: Initialize variable before use

4. Verify progress:
   dart analyze 2>&1 | grep "^  error" | wc -l
   # Should show <550 errors
```

### DAY 3: Repository Methods
```bash
# Morning
1. Fix INotesRepository interface:
   cd lib/domain/repositories
   # Add getAll() method definition

2. Implement missing methods:
   cd lib/infrastructure/repositories
   # Add setLinksForNote() to notes_core_repository.dart
   # Add batch loading methods

# Afternoon
3. Fix SupabaseNoteApi:
   cd lib/data/remote
   # Add fetchRecentNotes() method
   # Add fetchAllFolders() method

4. Verify progress:
   dart analyze 2>&1 | grep "^  error" | wc -l
   # Should show <450 errors
```

### DAY 4: Identifiers and Test Helpers
```bash
# Morning
1. Define missing enums:
   touch lib/domain/enums/conflict_resolution.dart
   ```dart
   enum ConflictResolutionStrategy {
     lastWriteWins,
     merge,
     keepBoth,
     manual
   }
   ```

2. Fix test helpers:
   cd test
   # Fix test_helpers.dart constructor issues

# Afternoon
3. Fix undefined providers:
   cd lib/providers
   # Add missing provider definitions

4. Verify progress:
   dart analyze 2>&1 | grep "^  error" | wc -l
   # Should show <350 errors
```

### DAY 5: Database Performance Crisis
```bash
# Morning
1. Fix N+1 queries:
   cd lib/infrastructure/repositories

   # Implement batch loading in notes_core_repository.dart:
   ```dart
   Future<Map<String, List<String>>> getBatchTagsForNotes(List<String> noteIds) async {
     final tags = await db.select(db.noteTags)
       .where((t) => t.noteId.isIn(noteIds))
       .get();

     final Map<String, List<String>> result = {};
     for (final tag in tags) {
       result.putIfAbsent(tag.noteId, () => []).add(tag.tag);
     }
     return result;
   }
   ```

# Afternoon
2. Add SQLite indexes:
   cd lib/data/migrations
   # Create new migration file
   # Add performance indexes

3. Test query performance:
   flutter test test/performance/
   # Verify <100ms query times
```

---

## 🔒 WEEK 2: SECURITY & DEPENDENCIES

### DAY 6-8: Encryption Implementation
```bash
# Day 6: Setup
1. Add encryption package:
   flutter pub add encrypt

2. Create encryption service:
   touch lib/services/security/aes_encryption_service.dart

# Day 7: Implementation
3. Replace base64 with AES-256:
   cd lib/data/remote
   # Update supabase_note_api.dart lines 652-683

# Day 8: Testing
4. Add encryption tests:
   touch test/services/encryption_test.dart
   flutter test test/services/encryption_test.dart
```

### DAY 9-10: Dependency Updates
```bash
# Day 9: Resolve conflicts
1. Update pubspec.yaml:
   flutter_riverpod: ^3.0.0
   mockito: ^5.6.0
   test: ^1.25.0
   # Remove: riverpod: any

2. Run dependency update:
   flutter clean
   flutter pub upgrade
   flutter pub get

# Day 10: Fix deprecated APIs
3. Update Riverpod usage:
   # Remove all .parent usage
   # Update to Riverpod 3.0 patterns

4. Verify build:
   flutter build apk --debug
```

---

## 🏗️ WEEK 3-4: ARCHITECTURE CLEANUP

### WEEK 3: Migration Completion
```bash
# Remove dual architecture:
1. Choose domain-driven architecture
2. Delete legacy adapters:
   rm -rf lib/infrastructure/adapters/

3. Clean migration config:
   rm lib/core/migration/migration_config.dart

4. Remove feature flags:
   # Search and remove all migrationConfig.isFeatureEnabled calls
```

### WEEK 4: Final Cleanup
```bash
1. Split providers.dart:
   # Create modular provider files

2. Add const constructors:
   # Use IDE quick fix to add const

3. Fix widget keys:
   # Add ValueKey to all list items

4. Final verification:
   flutter analyze
   flutter test
   flutter build apk --release
```

---

## ✅ VALIDATION COMMANDS

### Daily Health Check:
```bash
#!/bin/bash
echo "=== Daily Build Health Check ==="
echo "Cleaning project..."
flutter clean

echo "Getting dependencies..."
flutter pub get

echo "Counting errors..."
ERROR_COUNT=$(dart analyze 2>&1 | grep "^  error" | wc -l)
echo "Current errors: $ERROR_COUNT"

echo "Running tests..."
flutter test --reporter compact

echo "Attempting build..."
flutter build apk --debug

echo "=== Health Check Complete ==="
```

### Performance Verification:
```bash
# Database query test:
flutter test test/performance/database_performance_test.dart

# Memory profiling:
flutter run --profile
# Use DevTools to monitor memory

# Build size check:
flutter build apk --analyze-size
```

---

## 🎯 SUCCESS CRITERIA

### Week 1 End:
- [ ] <200 compilation errors
- [ ] Type system fixed
- [ ] Repository methods implemented
- [ ] N+1 queries resolved

### Week 2 End:
- [ ] <50 compilation errors
- [ ] Real encryption implemented
- [ ] Dependencies updated
- [ ] Deprecated APIs fixed

### Week 3 End:
- [ ] 0 compilation errors
- [ ] Single architecture
- [ ] All tests passing
- [ ] Performance targets met

### Week 4 End:
- [ ] Production build successful
- [ ] Security audit passed
- [ ] Documentation complete
- [ ] Deployment ready

---

## 🚨 ROLLBACK PLAN

If progress stalls:
```bash
# Rollback to last stable commit:
git stash
git checkout e6ba49e  # Last stable commit
flutter clean
flutter pub get
flutter build apk --release

# Create hotfix branch:
git checkout -b hotfix/emergency-fixes
# Apply only critical fixes
```

---

## 📞 ESCALATION MATRIX

| Day | Expected Errors | Actual > Expected | Action |
|-----|----------------|-------------------|---------|
| 1   | <650           | Yes               | Add developer |
| 2   | <550           | Yes               | Extend timeline |
| 3   | <450           | Yes               | Architecture review |
| 4   | <350           | Yes               | Consider rollback |
| 5   | <250           | Yes               | Emergency meeting |

---

*These execution orders are based on the comprehensive audit dated September 26, 2025. Update progress daily.*