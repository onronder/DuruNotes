# 📋 STABILIZATION WORK PLAN
**Generated:** September 26, 2025
**Goal:** Get app running on iOS/Android with full sync functionality
**Timeline:** 2-3 weeks focused work
**Priority:** Stability over features

---

## 🎯 OBJECTIVES
1. **Build & Run**: Get app to compile and run on both platforms
2. **Full Stack**: Enable local-remote sync functionality
3. **All Screens**: Ensure all existing screens are functional
4. **No New Features**: Focus only on stabilization

---

## 📊 PHASE BREAKDOWN

### PHASE 1: BUILD FOUNDATION (Days 1-2)
**Goal:** Get the project to compile

#### Day 1: Dependency Resolution
1. Fix pubspec.yaml dependency conflicts
2. Move test packages to dev_dependencies
3. Pin specific versions instead of "any"
4. Update SDK constraints for null safety
5. Run flutter pub get successfully

#### Day 2: Compilation Errors
1. Fix remaining type errors in lib/
2. Complete type converters implementation
3. Fix repository method signatures
4. Resolve all undefined identifiers
5. Achieve 0 errors in production code

### PHASE 2: CORE FUNCTIONALITY (Days 3-5)
**Goal:** Get basic app running

#### Day 3: Repository Layer
1. Implement missing repository methods
2. Fix service adapters
3. Complete domain interfaces
4. Ensure data flow works

#### Day 4: UI Layer Fixes
1. Fix notes_list_screen.dart
2. Fix modern_edit_note_screen.dart
3. Ensure navigation works
4. Fix provider dependencies

#### Day 5: Platform Testing
1. Build iOS app
2. Build Android app
3. Test basic CRUD operations
4. Verify local database works

### PHASE 3: SYNC & SECURITY (Days 6-8)
**Goal:** Enable full-stack functionality

#### Day 6: Security Fix (CRITICAL)
1. Replace base64 with AES-256 encryption
2. Implement proper key management
3. Test encryption/decryption
4. Audit data security

#### Day 7: Sync Infrastructure
1. Fix Supabase connection
2. Implement auth flow
3. Test remote API calls
4. Verify RLS policies

#### Day 8: Bidirectional Sync
1. Implement push sync
2. Implement pull sync
3. Handle conflict resolution
4. Test offline/online modes

### PHASE 4: PERFORMANCE (Days 9-10)
**Goal:** Fix critical performance issues

#### Day 9: Database Optimization
1. Fix N+1 queries (7 locations)
2. Implement batch loading
3. Add missing indexes
4. Test with 1000+ notes

#### Day 10: Memory & UI Performance
1. Fix memory leaks
2. Optimize provider rebuilds
3. Fix large file issues
4. Profile and optimize

### PHASE 5: SCREEN VALIDATION (Days 11-12)
**Goal:** Ensure all screens work

#### Day 11: Core Screens
1. Notes List Screen
2. Note Editor Screen
3. Search Screen
4. Settings Screen

#### Day 12: Feature Screens
1. Folders Management
2. Templates Gallery
3. Task Management
4. Import/Export

### PHASE 6: INTEGRATION (Days 13-14)
**Goal:** Full system validation

#### Day 13: End-to-End Testing
1. Create new notes
2. Edit and delete
3. Folder organization
4. Search functionality
5. Sync validation

#### Day 14: Platform Validation
1. iOS full test
2. Android full test
3. Performance benchmarks
4. Bug fixes

---

## 🔧 TECHNICAL TASKS BY PRIORITY

### 🚨 IMMEDIATE (Day 1)
```yaml
# Fix pubspec.yaml
dependencies:
  flutter_riverpod: ^2.6.1
  drift: ^2.21.0
  supabase_flutter: ^2.7.0
  # Remove: riverpod: any
  # Pin all "any" versions

dev_dependencies:
  mockito: ^5.6.0
  test: ^1.25.0
  build_runner: ^2.7.2

environment:
  sdk: '>=3.0.0 <4.0.0'
```

### 🔥 CRITICAL (Days 2-3)
1. **Complete Type Converters**
   - TaskConverter
   - TemplateConverter
   - Fix all type cast errors

2. **Repository Methods**
   - Implement getAll() properly
   - Fix batch operations
   - Complete CRUD operations

### ⚡ HIGH PRIORITY (Days 4-8)
1. **Security Implementation**
   ```dart
   class AESEncryptionService {
     static final _key = Key.fromBase64('...');
     static final _iv = IV.fromSecureRandom(16);

     static String encrypt(String plainText) {
       final encrypter = Encrypter(AES(_key));
       return encrypter.encrypt(plainText, iv: _iv).base64;
     }
   }
   ```

2. **N+1 Query Fix**
   ```dart
   // Add batch loading
   Future<Map<String, List<String>>> getBatchTagsForNotes(List<String> noteIds)
   Future<Map<String, List<NoteLink>>> getBatchLinksForNotes(List<String> noteIds)
   ```

### 📈 OPTIMIZATION (Days 9-14)
1. Clean architecture decisions
2. Remove dual architecture remnants
3. Optimize large files
4. Fix provider structure

---

## ✅ SUCCESS CRITERIA

### Minimum Viable Product (MVP)
- [ ] App builds on iOS
- [ ] App builds on Android
- [ ] User can create/edit/delete notes
- [ ] Local storage works
- [ ] Basic sync works
- [ ] All screens load without crashes

### Full Functionality
- [ ] Bidirectional sync works
- [ ] Conflict resolution works
- [ ] Offline mode works
- [ ] Search works
- [ ] Folders work
- [ ] Templates work
- [ ] Import/Export works
- [ ] Performance acceptable (<100ms response)

---

## 📝 EXECUTION ORDER

### Week 1: Foundation
1. Fix dependencies (4 hours)
2. Fix compilation errors (8 hours)
3. Implement missing methods (8 hours)
4. Fix UI screens (8 hours)
5. Platform builds (4 hours)
6. Security fix (8 hours)

### Week 2: Full Stack
1. Sync implementation (8 hours)
2. Performance fixes (8 hours)
3. Screen validation (8 hours)
4. Integration testing (8 hours)
5. Bug fixes (8 hours)

---

## 🚫 DO NOT
- Add new features
- Refactor unnecessarily
- Change UI designs
- Modify business logic
- Update packages unnecessarily

---

## 📊 DAILY CHECKLIST

```bash
# Morning
flutter clean
flutter pub get
dart analyze 2>&1 | grep "error" | wc -l

# After changes
flutter test --no-sound-null-safety || true
flutter build apk --debug
flutter build ios --debug --no-codesign

# Evening
git add -A
git commit -m "Stabilization: Day X progress"
```

---

## 🎯 FINAL GOAL
**A stable, functional app that works on both platforms with full sync capabilities, ready for incremental improvements.**