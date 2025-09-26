# 🔐 TODO: Security Vulnerabilities

> **Priority**: P0 - CRITICAL
> **Time Estimate**: 24 hours
> **Risk Level**: EXTREME
> **Current Score**: 3/10
> **Target Score**: 9/10

---

## 🚨 Current Security Status

### Vulnerabilities Found
- **SQL Injection**: Raw queries without parameterization
- **XSS Attacks**: No HTML sanitization
- **CSRF**: No token validation
- **Rate Limiting**: None (DDoS vulnerable)
- **Input Validation**: Missing on ALL forms
- **Authentication**: Weak middleware
- **Encryption**: Sensitive data stored in plaintext

---

## ✅ Task 1: Input Validation Service (6 hours)

### Create Service
- [ ] Create `/lib/services/security/input_validation_service.dart`
```dart
class InputValidationService {
  // Email validation
  // Phone validation
  // URL validation
  // Alphanumeric validation
  // SQL injection prevention
  // XSS prevention
}
```

### Validation Rules
- [ ] Email: RFC 5322 compliant
- [ ] Phone: International format support
- [ ] Password: Min 8 chars, 1 upper, 1 lower, 1 number, 1 special
- [ ] Username: Alphanumeric + underscore, 3-20 chars
- [ ] URLs: Valid protocol, domain, no javascript:
- [ ] Text: Strip HTML tags, escape special chars

### Integration Points (15+ forms)
- [ ] `/lib/ui/auth_screen.dart` - Login/Register forms
- [ ] `/lib/ui/modern_edit_note_screen.dart` - Note editor
- [ ] `/lib/ui/change_password_screen.dart` - Password change
- [ ] `/lib/features/folders/create_folder_dialog.dart` - Folder creation
- [ ] `/lib/features/templates/create_template_dialog.dart` - Template creation
- [ ] `/lib/ui/task_list_screen.dart` - Task creation
- [ ] `/lib/ui/modern_search_screen.dart` - Search input
- [ ] `/lib/ui/settings_screen.dart` - Settings forms
- [ ] `/lib/ui/reminders_screen.dart` - Reminder creation
- [ ] `/lib/ui/tags_screen.dart` - Tag creation
- [ ] `/lib/features/sync/conflict_resolution_dialog.dart` - Conflict inputs
- [ ] `/lib/ui/saved_search_management_screen.dart` - Search saving
- [ ] `/lib/ui/dialogs/goals_dialog.dart` - Goal inputs
- [ ] `/lib/ui/dialogs/task_metadata_dialog.dart` - Task metadata
- [ ] `/lib/ui/filters/filters_bottom_sheet.dart` - Filter inputs

---

## ✅ Task 2: SQL Injection Prevention (4 hours)

### Audit Current Queries
- [ ] Search for raw SQL: `grep -r "rawQuery\|execute\|WHERE.*\$" lib/`
- [ ] Document all instances in `SECURITY_AUDIT.md`
- [ ] Count total vulnerable queries: ___

### Fix Vulnerable Queries
- [ ] `/lib/data/local/app_db.dart` - Replace raw queries
- [ ] Use parameterized queries everywhere
- [ ] Example fix:
```dart
// BEFORE (vulnerable)
db.rawQuery("SELECT * FROM notes WHERE title = '$userInput'");

// AFTER (safe)
db.rawQuery("SELECT * FROM notes WHERE title = ?", [userInput]);
```

### Locations to Fix
- [ ] `searchNotes()` method - Line 1449
- [ ] `findFolderByName()` method - Line 2545
- [ ] Custom queries in sync operations
- [ ] Tag search queries
- [ ] Task filtering queries

---

## ✅ Task 3: XSS Protection (3 hours)

### Create Sanitization Service
- [ ] Create `/lib/services/security/html_sanitizer.dart`
- [ ] Implement HTML stripping
- [ ] Implement entity encoding
- [ ] Whitelist safe tags (if needed)

### Apply to All Text Outputs
- [ ] Note body rendering
- [ ] Note title display
- [ ] Folder names
- [ ] Tag names
- [ ] Task descriptions
- [ ] Template content
- [ ] Search results

### Markdown Rendering
- [ ] Audit `flutter_markdown` usage
- [ ] Ensure no raw HTML execution
- [ ] Sanitize before markdown parsing

---

## ✅ Task 4: Rate Limiting (4 hours)

### Create Rate Limiter
- [ ] Create `/lib/core/middleware/rate_limiter.dart`
```dart
class RateLimiter {
  // Per-user limits
  // Per-IP limits
  // Endpoint-specific limits
  // Exponential backoff
}
```

### Apply Rate Limits
- [ ] Authentication: 5 attempts per 15 minutes
- [ ] API calls: 100 per minute
- [ ] Search: 30 per minute
- [ ] Sync: 10 per minute
- [ ] Export: 5 per hour
- [ ] Import: 5 per hour

### Implementation
- [ ] Add to Supabase functions
- [ ] Add to local API endpoints
- [ ] Add UI feedback for rate limits
- [ ] Add retry logic with backoff

---

## ✅ Task 5: Authentication Middleware (3 hours)

### Create Auth Guard
- [ ] Create `/lib/core/guards/auth_guard.dart`
- [ ] Token validation
- [ ] Session management
- [ ] Permission checking
- [ ] Auto-logout on inactivity

### Protected Routes
- [ ] Note CRUD operations
- [ ] Folder management
- [ ] Settings access
- [ ] Sync operations
- [ ] Export/Import
- [ ] Template management

### Implementation
- [ ] Add @protected annotation
- [ ] Implement route guards
- [ ] Add to provider layer
- [ ] Test unauthorized access

---

## ✅ Task 6: CSRF Protection (2 hours)

### Token Generation
- [ ] Create CSRF token service
- [ ] Generate on session start
- [ ] Refresh every 30 minutes
- [ ] Store securely

### Token Validation
- [ ] Add to all POST requests
- [ ] Add to all PUT requests
- [ ] Add to all DELETE requests
- [ ] Validate on server side

### Implementation
- [ ] Add hidden field to forms
- [ ] Add header to API calls
- [ ] Server-side validation
- [ ] Error handling

---

## ✅ Task 7: Encryption at Rest (4 hours)

### Create Encryption Service
- [ ] Create `/lib/services/security/encryption_service.dart`
- [ ] AES-256 encryption
- [ ] Key management
- [ ] Key rotation support

### Encrypt Sensitive Data
- [ ] User credentials
- [ ] API tokens
- [ ] Sync tokens
- [ ] Personal information
- [ ] Note content (optional setting)

### Storage Locations
- [ ] SharedPreferences encryption
- [ ] SQLite field encryption
- [ ] File system encryption
- [ ] Keychain/Keystore integration

---

## 📊 Validation & Testing

### Security Audit Checklist
- [ ] Run OWASP dependency check
- [ ] SQL injection testing (sqlmap)
- [ ] XSS testing (all input fields)
- [ ] CSRF testing (token validation)
- [ ] Rate limit testing (stress test)
- [ ] Auth bypass testing
- [ ] Encryption verification

### Penetration Testing
- [ ] Input fuzzing
- [ ] Authentication attacks
- [ ] Session hijacking attempts
- [ ] Data leakage tests
- [ ] Error message analysis

### Compliance Check
- [ ] GDPR compliance
- [ ] Data retention policies
- [ ] Privacy policy alignment
- [ ] Security headers configured

---

## 🎯 Success Criteria

### All Must Be TRUE
- [ ] Zero SQL injection vulnerabilities
- [ ] Zero XSS vulnerabilities
- [ ] All forms have validation
- [ ] Rate limiting active
- [ ] CSRF tokens implemented
- [ ] Sensitive data encrypted
- [ ] Auth middleware on all routes
- [ ] Security score >= 9/10
- [ ] Penetration test passed
- [ ] Zero high/critical vulnerabilities in scan

---

## 📝 Testing Commands

```bash
# Check for SQL injection patterns
grep -r "WHERE.*[\$\+]" lib/ --include="*.dart"

# Find unvalidated TextFields
grep -r "TextField\|TextFormField" lib/ | grep -v "validator:"

# Check for raw HTML rendering
grep -r "Html(\|innerHtml" lib/

# Find unprotected routes
grep -r "class.*Screen\|class.*Page" lib/ | grep -v "@protected"

# Check encryption usage
grep -r "SharedPreferences\|storage" lib/ | grep -v "encrypt"
```

---

## ⚠️ Common Security Mistakes

1. **Trusting user input** - Always validate and sanitize
2. **Client-side only validation** - Also validate server-side
3. **Weak regex patterns** - Use proven validation patterns
4. **Not escaping output** - Escape for the context (HTML, SQL, etc)
5. **Hardcoded secrets** - Use environment variables
6. **Insufficient logging** - Log security events
7. **No rate limiting** - Always limit API calls
8. **Weak encryption** - Use AES-256 minimum

---

**Remember**: Security is not optional. Every vulnerability is a potential lawsuit or data breach.