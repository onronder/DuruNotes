# Rollback Procedures - Domain Migration

## Quick Reference
**Emergency Hotline**: [On-call Engineer]
**Rollback Authority**: Engineering Lead or Senior Engineer
**Time to Rollback**: < 15 minutes

## Severity Levels

### 🔴 CRITICAL (Immediate Rollback)
- Data corruption or loss
- Authentication failures >10%
- Crash rate >5%
- Complete sync failure

### 🟡 HIGH (Rollback within 1 hour)
- Performance degradation >50%
- Sync errors >10%
- UI breaking changes
- Crash rate 2-5%

### 🟢 MEDIUM (Monitor and decide)
- Minor UI issues
- Performance degradation <50%
- Non-critical feature failures
- Increased error logs

## Rollback Methods

### Method 1: Feature Flag Rollback (Fastest - 5 minutes)
```dart
// 1. Update lib/core/migration/migration_config.dart
class MigrationConfig {
  final bool enableMigration = false; // DISABLE
  final bool useDomainEntities = false; // DISABLE
  final bool enableDualProviders = false; // DISABLE
}

// 2. Commit and push
git add lib/core/migration/migration_config.dart
git commit -m "EMERGENCY: Disable domain migration"
git push origin feature/domain-migration

// 3. Deploy hot fix
flutter build appbundle --release
flutter build ipa --release
```

### Method 2: Provider Rollback (10 minutes)
```dart
// In lib/providers.dart
class AppProviders {
  // Force old architecture
  static const bool useRefactoredArchitecture = false;

  // Disable migration features
  static final migrationConfigProvider = Provider<MigrationConfig>((ref) {
    return MigrationConfig(
      enableMigration: false,
      useDomainEntities: false,
      enableDualProviders: false,
    );
  });
}
```

### Method 3: Git Rollback (15 minutes)
```bash
# 1. Create rollback branch
git checkout -b emergency/rollback-migration

# 2. Revert migration commits
git revert b938e71  # Phase 7
git revert 86a1b5c  # Phase 6
git revert 00cf08c  # Phase 5
git revert [commit]  # Phase 4
git revert 07b8fb1  # Phase 3
git revert 93d2861  # Phase 2
git revert 8240c84  # Phase 1

# 3. Push and deploy
git push origin emergency/rollback-migration
```

### Method 4: Database Rollback (If needed)
```sql
-- Only if schema changes cause issues
-- Run in Supabase SQL Editor

-- Restore original schema
ALTER TABLE local_notes
  DROP COLUMN IF EXISTS version,
  DROP COLUMN IF EXISTS user_id,
  DROP COLUMN IF EXISTS attachment_meta,
  DROP COLUMN IF EXISTS metadata;

-- Update schema version
UPDATE schema_migrations
SET version = 12
WHERE version = 13;
```

## Step-by-Step Rollback Procedures

### 1. Identify the Issue
```bash
# Check error rates
curl https://api.sentry.io/projects/duru-notes/issues/

# Check crash reports
firebase crashlytics:symbols:upload

# Check user reports
```

### 2. Assess Severity
- [ ] Check error dashboard
- [ ] Review user complaints
- [ ] Analyze performance metrics
- [ ] Determine severity level

### 3. Initiate Rollback
#### For CRITICAL issues:
1. **Alert Team**
   ```
   @channel CRITICAL: Initiating domain migration rollback
   Issue: [Description]
   Impact: [User count]
   Rollback method: [Method chosen]
   ```

2. **Execute Rollback**
   - Use Method 1 (Feature Flag) for fastest response
   - Deploy immediately without full testing

3. **Verify Rollback**
   ```bash
   # Check that old code paths are active
   flutter logs | grep "Using legacy repositories"
   ```

#### For HIGH issues:
1. **Gather Data** (15 minutes)
   - Collect error logs
   - Document issue patterns
   - Identify affected users

2. **Team Decision**
   - Quick sync with team lead
   - Choose rollback method
   - Prepare communication

3. **Execute Rollback**
   - Use Method 2 (Provider Rollback)
   - Run quick smoke tests

### 4. Post-Rollback Actions

#### Immediate (Within 1 hour):
- [ ] Verify system stability
- [ ] Monitor error rates
- [ ] Check user sessions
- [ ] Document incident

#### Short-term (Within 24 hours):
- [ ] Root cause analysis
- [ ] Create fix plan
- [ ] Update test cases
- [ ] Team retrospective

#### Long-term (Within 1 week):
- [ ] Implement fixes
- [ ] Enhanced testing
- [ ] Update rollout plan
- [ ] Re-attempt migration

## Monitoring During Rollback

### Key Metrics to Watch
```dart
// Add temporary monitoring
class RollbackMonitor {
  static void trackRollback() {
    AppLogger.critical('ROLLBACK_INITIATED', data: {
      'timestamp': DateTime.now().toIso8601String(),
      'reason': 'domain_migration_issue',
      'method': 'feature_flag',
    });
  }

  static void verifyStability() {
    // Check every 5 minutes for 1 hour
    Timer.periodic(Duration(minutes: 5), (timer) {
      final errorRate = getErrorRate();
      if (errorRate > baseline) {
        AppLogger.warning('Rollback incomplete', data: {
          'errorRate': errorRate,
        });
      }
    });
  }
}
```

## Communication Templates

### User Communication
```
Subject: Temporary Service Adjustment

Dear Users,

We've temporarily reverted a recent update to ensure the best possible experience.
Your data is safe and the app remains fully functional.

We'll re-release the improvements once we've addressed the issue.

Thank you for your patience.
```

### Internal Communication
```
INCIDENT REPORT: Domain Migration Rollback

Time: [Timestamp]
Severity: [CRITICAL/HIGH/MEDIUM]
Impact: [X users affected]
Root Cause: [Brief description]
Action Taken: [Rollback method used]
Next Steps: [Fix plan]

Lessons Learned:
- [Key takeaway 1]
- [Key takeaway 2]
```

## Validation Checklist

### Pre-Rollback
- [ ] Backup current state
- [ ] Alert on-call team
- [ ] Prepare rollback branch
- [ ] Document issue

### During Rollback
- [ ] Execute chosen method
- [ ] Monitor metrics
- [ ] Test critical paths
- [ ] Update status page

### Post-Rollback
- [ ] Verify stability
- [ ] Close incident
- [ ] Document lessons
- [ ] Plan fixes

## Recovery Testing

### Test Scenarios
1. **Feature Flag Toggle**
   - Enable/disable migration
   - Verify both paths work
   - Check data consistency

2. **Partial Rollback**
   - Disable specific features
   - Keep others enabled
   - Test combinations

3. **Full Rollback**
   - Complete reversion
   - Data migration reversal
   - Schema downgrade

## Emergency Contacts

| Role | Name | Contact | Backup |
|------|------|---------|--------|
| Engineering Lead | - | - | - |
| DevOps Lead | - | - | - |
| Product Manager | - | - | - |
| Database Admin | - | - | - |

## Appendix: Common Issues and Solutions

### Issue: Mapper Failures
```dart
// Quick fix: Bypass mappers
if (emergencyMode) {
  return data; // Return raw data
} else {
  return NoteMapper.toDomain(data);
}
```

### Issue: Repository Errors
```dart
// Quick fix: Use legacy repositories
final repo = emergencyMode
  ? LegacyNotesRepository()
  : NotesRepository();
```

### Issue: Sync Conflicts
```dart
// Quick fix: Disable sync
if (emergencyMode) {
  return; // Skip sync
}
```

---

**Remember**: User data integrity is paramount. When in doubt, rollback.

*Document Version: 1.0*
*Last Updated: [Current Date]*
*Next Review: [Date + 30 days]*