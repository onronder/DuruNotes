# Critical Production Fixes - Immediate Action Required

## 🚨 Priority 1: Security & Debug Code Removal

### Issue: 551 Debug Statements in Production Code
**Risk Level**: HIGH - Exposes sensitive data in logs

**Fix Required**:
```bash
# Run this script to remove all debug statements
#!/bin/bash
echo "Removing debug statements from production code..."

# Replace debugPrint with conditional logging
find lib -name "*.dart" -type f -exec sed -i '' \
  's/debugPrint(/if (kReleaseMode) {} else if (kDebugMode) print(/g' {} \;

# Remove print statements
find lib -name "*.dart" -type f -exec sed -i '' \
  's/print(/if (kDebugMode) print(/g' {} \;

# Remove TODO/FIXME comments from production files
find lib -name "*.dart" -type f -exec sed -i '' \
  '/\/\/ TODO:/d; /\/\/ FIXME:/d; /\/\/ XXX:/d; /\/\/ HACK:/d' {} \;
```

### Issue: Exposed API Keys in Docker Config
**Risk Level**: CRITICAL

**Fix Required**:
1. Generate new JWT secrets:
```bash
openssl rand -base64 32
```

2. Update docker.env with production values
3. Never commit real keys to repository
4. Use environment variables in CI/CD

---

## 🚨 Priority 2: Error Handling Standardization

### Issue: Inconsistent Error Handling
**Risk Level**: HIGH - Can cause app crashes

**Required Pattern**:
```dart
// Standardized error handling wrapper
Future<T?> safeExecute<T>(
  Future<T> Function() operation, {
  required String context,
  T? fallback,
}) async {
  try {
    return await operation();
  } on AuthException catch (e, stack) {
    logger.error('Auth error in $context', error: e, stackTrace: stack);
    // Handle auth-specific error
    return fallback;
  } on TimeoutException catch (e, stack) {
    logger.error('Timeout in $context', error: e, stackTrace: stack);
    // Handle timeout
    return fallback;
  } catch (e, stack) {
    logger.error('Unexpected error in $context', error: e, stackTrace: stack);
    Sentry.captureException(e, stackTrace: stack);
    return fallback;
  }
}
```

### Files Requiring Immediate Fix:
1. `lib/repository/sync_service.dart` - Add uniform retry logic
2. `lib/services/inbox_management_service.dart` - Handle parse errors
3. `lib/services/note_task_sync_service.dart` - Add transaction rollback
4. `lib/ui/modern_edit_note_screen.dart` - Add error boundaries
5. `lib/providers.dart` - Handle provider disposal errors

---

## 🚨 Priority 3: Database Integrity

### Issue: Missing Cascade Constraints
**Risk Level**: MEDIUM - Can cause orphaned data

**SQL Migration Required**:
```sql
-- Add cascade delete constraints
ALTER TABLE note_folders 
  DROP CONSTRAINT IF EXISTS note_folders_note_id_fkey,
  ADD CONSTRAINT note_folders_note_id_fkey 
    FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE;

ALTER TABLE note_folders 
  DROP CONSTRAINT IF EXISTS note_folders_folder_id_fkey,
  ADD CONSTRAINT note_folders_folder_id_fkey 
    FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE;

ALTER TABLE note_tags 
  DROP CONSTRAINT IF EXISTS note_tags_note_id_fkey,
  ADD CONSTRAINT note_tags_note_id_fkey 
    FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE;

-- Add missing indexes
CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date) WHERE due_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reminders_scheduled_at ON reminders(scheduled_at) WHERE fired = false;
```

---

## 🚨 Priority 4: Performance Critical Fixes

### Issue: No Virtual Scrolling for Large Lists
**Risk Level**: HIGH - App freezes with 1000+ notes

**Implementation Required**:
```dart
// Replace ListView.builder with flutter_staggered_grid_view
dependencies:
  flutter_staggered_grid_view: ^0.7.0
  
// In notes_list_screen.dart
SliverStaggeredGrid.countBuilder(
  crossAxisCount: 1,
  itemCount: notes.length,
  itemBuilder: (context, index) {
    if (index >= notes.length - 20) {
      // Trigger pagination
      ref.read(notesPageProvider.notifier).loadMore();
    }
    return NoteCard(note: notes[index]);
  },
  staggeredTileBuilder: (index) => StaggeredTile.fit(1),
)
```

### Issue: Images Not Lazy Loaded
**Risk Level**: MEDIUM - High memory usage

**Fix Required**:
```dart
// Use CachedNetworkImage for all remote images
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  memCacheHeight: 200,
  memCacheWidth: 200,
)
```

---

## 🚨 Priority 5: Testing Critical Paths

### Minimum Required Tests (Create Immediately)

**1. Auth Flow Test** (`test/auth_flow_test.dart`):
```dart
void main() {
  group('Authentication Flow', () {
    test('Login with valid credentials', () async {
      // Test successful login
    });
    
    test('Handle invalid credentials', () async {
      // Test error handling
    });
    
    test('Rate limiting after failed attempts', () async {
      // Test rate limiting
    });
  });
}
```

**2. Sync Test** (`test/sync_test.dart`):
```dart
void main() {
  group('Sync Operations', () {
    test('Push local changes', () async {
      // Test push
    });
    
    test('Pull remote changes', () async {
      // Test pull
    });
    
    test('Handle conflicts', () async {
      // Test conflict resolution
    });
  });
}
```

**3. Encryption Test** (`test/encryption_test.dart`):
```dart
void main() {
  group('Encryption', () {
    test('Encrypt and decrypt note', () async {
      // Test encryption roundtrip
    });
    
    test('Handle missing keys', () async {
      // Test key recovery
    });
  });
}
```

---

## 🚨 Priority 6: Monitoring Setup

### Sentry Configuration Fix
```dart
// main.dart
await SentryFlutter.init(
  (options) {
    options.dsn = const String.fromEnvironment('SENTRY_DSN');
    options.environment = kReleaseMode ? 'production' : 'development';
    options.tracesSampleRate = kReleaseMode ? 0.1 : 1.0;
    options.attachScreenshot = true;
    options.attachViewHierarchy = true;
    options.beforeSend = (event, hint) {
      // Scrub sensitive data
      if (event.exceptions?.isNotEmpty ?? false) {
        for (var exception in event.exceptions!) {
          // Remove sensitive data from stack traces
          exception.stackTrace?.frames.removeWhere(
            (frame) => frame.absPath?.contains('api_key') ?? false
          );
        }
      }
      return event;
    };
  },
);
```

---

## 🔥 Quick Fix Script

Save and run this script to fix the most critical issues:

```bash
#!/bin/bash
# fix_critical_production_issues.sh

echo "🔧 Fixing critical production issues..."

# 1. Remove debug statements
echo "1. Removing debug statements..."
find lib -name "*.dart" -type f | while read file; do
  # Wrap debugPrint in kDebugMode check
  sed -i '' 's/debugPrint(/if (kDebugMode) debugPrint(/g' "$file"
  
  # Remove standalone print statements
  sed -i '' 's/^\s*print(/if (kDebugMode) print(/g' "$file"
done

# 2. Add error boundaries to main screens
echo "2. Adding error boundaries..."
cat > lib/ui/widgets/safe_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:duru_notes/core/monitoring/error_boundary.dart';

class SafeScreen extends StatelessWidget {
  final Widget child;
  final String screenName;
  
  const SafeScreen({
    required this.child,
    required this.screenName,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: child,
      fallback: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Something went wrong in $screenName'),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
EOF

# 3. Create production environment config
echo "3. Creating production config..."
cat > .env.production << 'EOF'
# Production Environment Variables
ENVIRONMENT=production
DEBUG_MODE=false
LOG_LEVEL=error
ENABLE_ANALYTICS=true
ENABLE_CRASH_REPORTING=true
SENTRY_TRACES_SAMPLE_RATE=0.1
EOF

# 4. Add pre-commit hook
echo "4. Adding pre-commit hook..."
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Check for debug statements
if git diff --cached --name-only | xargs grep -E "(debugPrint|print\(|TODO:|FIXME:)" > /dev/null; then
  echo "❌ Debug statements or TODO comments found in staged files"
  echo "Please remove them before committing to production"
  exit 1
fi
EOF
chmod +x .git/hooks/pre-commit

# 5. Run tests
echo "5. Running tests..."
flutter test || echo "⚠️ Some tests failed - please fix before deploying"

# 6. Analyze code
echo "6. Analyzing code..."
flutter analyze || echo "⚠️ Analysis issues found - please review"

echo "✅ Critical fixes applied. Please review changes before committing."
```

---

## Deployment Blockers

### MUST FIX before production:
1. ❌ Remove ALL debug code (551 instances)
2. ❌ Fix Docker credentials 
3. ❌ Add error boundaries to all screens
4. ❌ Implement basic auth/sync tests
5. ❌ Configure production Sentry
6. ❌ Add cascade constraints to database
7. ❌ Implement virtual scrolling for lists

### Estimated Time: 2-3 days with focused effort

---

*Generated: January 14, 2025*  
*Priority: CRITICAL - Fix immediately*
