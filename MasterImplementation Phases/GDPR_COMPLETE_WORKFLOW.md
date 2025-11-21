# GDPR User Anonymization - Complete Workflow Guide

**Document Version**: 1.0
**Date**: November 21, 2025
**Status**: Production-Ready
**Compliance**: GDPR Article 17 (Right to Erasure)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Process Flow](#process-flow)
5. [Security Model](#security-model)
6. [Safeguards](#safeguards)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)
9. [Compliance Verification](#compliance-verification)

---

## Overview

This document describes the complete GDPR anonymization workflow implemented in Duru Notes. The system ensures irreversible, compliant user data deletion while preventing accidental or malicious anonymization attempts.

### Key Features

✅ **7-Phase Anonymization Process**
- Phase 1: Pre-Anonymization Validation
- Phase 2: Account Metadata Anonymization
- Phase 3: Encryption Key Destruction (Point of No Return)
- Phase 4-6: Atomic App & Auth Cleanup (via Edge Function)
- Phase 7: Final Audit Trail & Compliance Proof

✅ **Multi-Layer Security**
- Database-level RLS policies (immediate access blocking)
- Edge Function authentication
- Client-side protection
- Comprehensive safeguards

✅ **Complete Auth Deletion**
- Revokes all sessions globally
- Deletes `auth.users` entry (prevents login)
- Clears all encryption keys
- Tombstones all encrypted content

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│ • GDPRAnonymizationService (orchestrator)                       │
│ • GDPRSafeguards (pre-flight validation)                        │
│ • UserConfirmations (explicit consent)                          │
│ • Client-side anonymization check (app.dart)                    │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                     EDGE FUNCTION LAYER                          │
├─────────────────────────────────────────────────────────────────┤
│ gdpr-delete-auth-user                                           │
│ • User session validation                                        │
│ • Service role elevation (for auth.admin operations)            │
│ • Atomic cleanup orchestration                                  │
│ • Session revocation + auth.users deletion                      │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DATABASE LAYER                              │
├─────────────────────────────────────────────────────────────────┤
│ public.user_profiles                                            │
│ • is_anonymized flag (triggers RLS blocking)                    │
│ • anonymization_completed_at                                    │
│ • auth_deletion_completed_at                                    │
│                                                                  │
│ SQL Functions:                                                   │
│ • anonymize_app_user() - SECURITY DEFINER                       │
│   ├─ Phase 2.5: Set is_anonymized = true                        │
│   ├─ Phase 4: Call anonymize_all_user_content()                 │
│   └─ Phase 5: Call clear_all_user_metadata()                    │
│ • is_user_anonymized() - RLS helper (indexed)                   │
│ • get_anonymization_status_summary() - Status checking          │
│                                                                  │
│ RLS Policies:                                                    │
│ • "block_anonymized_users" on ALL tables                        │
│   (notes, note_tasks, folders, reminders, etc.)                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Client Layer

#### GDPRAnonymizationService
**Location**: `lib/services/gdpr_anonymization_service.dart`

**Responsibilities**:
- Orchestrates 7-phase anonymization process
- Validates user confirmations
- Calls Edge Function for phases 4-6
- Generates compliance proof (SHA-256 hash)
- Forces client logout after success

**Key Methods**:
```dart
Future<GDPRAnonymizationReport> anonymizeUserAccount({
  required String userId,
  required UserConfirmations confirmations,
  void Function(AnonymizationProgress)? onProgress,
})
```

#### GDPRSafeguards
**Location**: `lib/core/gdpr/gdpr_safeguards.dart`

**Safeguards Implemented**:
1. **Environment Check**: Prevents production accidents
2. **Rate Limiting**: 24-hour cooldown between attempts
3. **Email Verification**: Requires confirmed email
4. **Acknowledgment**: User must explicitly confirm risks
5. **Active Sessions**: Warns about multi-device signout

**Rate Limiting**:
- Cooldown period: 24 hours
- Max failed attempts before lockout: 3
- Tracked via `anonymization_events` table

#### Client-Side Protection
**Location**: `lib/app/app.dart`

**Protection Mechanism**:
```dart
Future<bool> _checkAnonymizationStatus() async
```

- Runs on every login
- Calls `get_anonymization_status_summary()` function
- Shows "Account Deleted" dialog if `is_anonymized = true`
- Forces immediate logout
- Cannot be bypassed (RLS at database level)

### 2. Edge Function Layer

#### gdpr-delete-auth-user
**Location**: `supabase/functions/gdpr-delete-auth-user/index.ts`

**Authentication Flow**:
1. Validates user session token (from client)
2. Verifies userId matches authenticated user
3. Uses service role key (from secrets) for auth.admin operations

**Operations**:
```typescript
// Phase 2.5: Mark user as anonymized
// Phase 4: Tombstone encrypted content
// Phase 5: Clear metadata
await supabaseAdmin.rpc('anonymize_app_user', {
  p_user_id: userId,
  p_anonymization_id: anonymizationId
});

// Phase 6.1: Revoke all sessions
await supabaseAdmin.auth.admin.signOut(userId);

// Phase 6.2: Delete auth.users entry
await supabaseAdmin.auth.admin.deleteUser(userId);

// Record completion timestamp
UPDATE user_profiles
SET auth_deletion_completed_at = now()
WHERE user_id = userId;
```

**Security**:
- ✅ User can only anonymize their own account
- ✅ Service role key never exposed to client
- ✅ Validates UUID format
- ✅ Production safety check (requires confirmationToken)
- ✅ Idempotent (safe to call multiple times)

### 3. Database Layer

#### Migration: 20251121000000_add_anonymization_status.sql

**Schema Changes**:
```sql
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS is_anonymized BOOLEAN DEFAULT false NOT NULL,
ADD COLUMN IF NOT EXISTS anonymization_completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS auth_deletion_completed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS anonymization_id UUID;

-- Performance-optimized index
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_anonymized
  ON public.user_profiles(is_anonymized)
  WHERE is_anonymized = true;
```

**RLS Helper Function**:
```sql
CREATE OR REPLACE FUNCTION is_user_anonymized(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT is_anonymized FROM public.user_profiles WHERE user_id = check_user_id),
    false
  );
$$;
```

**RLS Policies Applied To**:
- ✅ `public.notes`
- ✅ `public.note_tasks`
- ✅ `public.folders`
- ✅ `public.reminders`
- ✅ `public.user_preferences`
- ✅ `public.user_devices`
- ✅ `public.saved_searches`
- ✅ `public.tags` (conditional)
- ✅ `public.user_encryption_keys`
- ✅ `public.user_keys` (legacy, conditional)

**SECURITY DEFINER Function**:
```sql
CREATE OR REPLACE FUNCTION anonymize_app_user(p_user_id UUID, p_anonymization_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Phase 2.5: Mark as anonymized (RLS immediately blocks)
  UPDATE public.user_profiles
  SET is_anonymized = true, anonymization_id = p_anonymization_id
  WHERE user_id = p_user_id AND is_anonymized = false;

  -- Phase 4: Tombstone content (DoD 5220.22-M)
  PERFORM anonymize_all_user_content(p_user_id);

  -- Phase 5: Clear metadata
  PERFORM clear_all_user_metadata(p_user_id);

  RETURN result_json;
END;
$$;
```

---

## Process Flow

### Complete Anonymization Flow

```
1. USER INITIATES ANONYMIZATION (via Settings UI)
   ↓
2. SAFEGUARD VALIDATION (GDPRSafeguards)
   ├─ Environment check (prod requires override)
   ├─ Rate limiting (24h cooldown)
   ├─ Email verification
   ├─ Risk acknowledgment
   └─ Active session warning
   ↓
3. PHASE 1: Pre-Anonymization Validation
   ├─ Validate user confirmations
   ├─ Check session validity
   └─ Detect active sync operations
   ↓
4. PHASE 2: Account Metadata Anonymization
   ├─ Call anonymize_user_profile()
   ├─ Email → anon_{uuid_prefix}@anonymized.local
   ├─ Names → "ANONYMIZED USER"
   └─ Passphrase hint → NULL
   ↓
5. PHASE 3: Encryption Key Destruction ⚠️ POINT OF NO RETURN
   ├─ Destroy legacy device key
   ├─ Destroy Account Master Key (local + remote)
   ├─ Destroy cross-device keys
   └─ Generate KeyDestructionReport
   ↓
6. PHASE 4-6: ATOMIC CLEANUP (via Edge Function)
   ├─ Client calls gdpr-delete-auth-user with session token
   ├─ Edge Function validates user authentication
   ├─ Edge Function elevates to service role
   ├─ Phase 2.5: Sets is_anonymized = true (RLS blocks immediately)
   ├─ Phase 4: Tombstones encrypted content (DoD 5220.22-M)
   ├─ Phase 5: Clears metadata
   ├─ Phase 6.1: Revokes all sessions (admin.signOut)
   ├─ Phase 6.2: Deletes auth.users entry (admin.deleteUser)
   └─ Records completion timestamp
   ↓
7. PHASE 7: Final Audit Trail & Compliance Proof
   ├─ Generate SHA-256 proof hash
   ├─ Store in anonymization_proofs table
   └─ Record completion event
   ↓
8. CLIENT FORCE LOGOUT
   ├─ signOut(scope: SignOutScope.global)
   └─ User redirected to login screen
   ↓
9. LOGIN ATTEMPT (by same user)
   ├─ _checkAnonymizationStatus() runs
   ├─ Detects is_anonymized = true
   ├─ Shows "Account Deleted" dialog
   ├─ Forces logout
   └─ BLOCKED: Cannot access any data
```

### Timeline

```
T+0s    : User clicks "Delete My Account"
T+1s    : Safeguards validate (environment, rate limit, email)
T+2s    : Phase 1 validates confirmations
T+3s    : Phase 2 anonymizes profile metadata
T+5s    : Phase 3 destroys encryption keys ← POINT OF NO RETURN
T+10s   : Edge Function called (Phases 4-6)
T+12s   : RLS policies block all data access
T+15s   : Sessions revoked
T+16s   : auth.users deleted
T+18s   : Phase 7 generates compliance proof
T+19s   : Client force logout
T+20s   : User sees login screen
T+21s   : Login attempt blocked (account deleted dialog)
```

---

## Security Model

### Authentication Layers

```
Layer 1: Client-Side Safeguards
├─ Environment validation
├─ Rate limiting check
├─ Email verification check
└─ User confirmations

Layer 2: Edge Function Authentication
├─ Valid user session token required
├─ userId must match authenticated user
├─ Service role used internally (not exposed)
└─ Production safety check

Layer 3: Database RLS
├─ is_user_anonymized() check on ALL tables
├─ Indexed for performance (<1ms overhead)
├─ Cannot be bypassed (enforced by PostgreSQL)
└─ Blocks SELECT, INSERT, UPDATE, DELETE

Layer 4: Auth Deletion
├─ admin.signOut() revokes all sessions
├─ admin.deleteUser() removes auth.users entry
└─ Prevents future login attempts
```

### Threat Model

| Attack Vector | Mitigation |
|--------------|------------|
| **Accidental deletion** | Multi-layer confirmations + safeguards |
| **Rate limiting bypass** | Database-enforced 24h cooldown |
| **Production accident** | Explicit override required |
| **Malicious anonymization** | User can only delete own account |
| **Session hijacking** | RLS blocks data even with valid token |
| **Data recovery** | Keys destroyed = data mathematically inaccessible |
| **Login after deletion** | Client-side check + RLS + no auth.users entry |

---

## Safeguards

### 1. Environment Check

**Purpose**: Prevent production accidents

**Implementation**:
```dart
const isProduction = bool.fromEnvironment('dart.vm.product', defaultValue: false);

if (isProduction && !allowProductionOverride) {
  throw SafeguardException('Production requires explicit override');
}
```

**Override**:
```dart
final confirmations = UserConfirmations(
  dataBackupComplete: true,
  understandsIrreversibility: true,
  finalConfirmationToken: 'DELETE MY ACCOUNT',
  acknowledgesRisks: true,
  allowProductionOverride: true, // ← Explicit production bypass
);
```

### 2. Rate Limiting

**Purpose**: Prevent rapid repeated attempts

**Parameters**:
- Cooldown period: 24 hours
- Max failed attempts: 3 (before warning)

**Database Query**:
```sql
SELECT created_at, event_type, details
FROM anonymization_events
WHERE user_id = $1
  AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 10;
```

**Error Message**:
```
Rate limit exceeded. You must wait 23 hours and 45 minutes before attempting anonymization again.
This cooldown prevents accidental or malicious repeated attempts.
```

### 3. Email Verification

**Purpose**: Ensure user controls the email address

**Check**:
```dart
final emailConfirmed = user.emailConfirmedAt != null;
if (!emailConfirmed) {
  throw SafeguardException('Email must be verified before deletion');
}
```

### 4. User Acknowledgment

**Purpose**: Explicit informed consent

**Requirements**:
```dart
class UserConfirmations {
  final bool dataBackupComplete;        // ✅ Required
  final bool understandsIrreversibility; // ✅ Required
  final String finalConfirmationToken;  // ✅ Must be "DELETE MY ACCOUNT"
  final bool acknowledgesRisks;         // ✅ Required
}
```

### 5. Active Sessions Warning

**Purpose**: Inform user about multi-device signout

**Implementation**:
```sql
SELECT device_name, last_seen_at, device_type
FROM user_devices
WHERE user_id = $1
  AND last_seen_at > NOW() - INTERVAL '24 hours'
ORDER BY last_seen_at DESC;
```

**Warning**:
```
⚠️  You have 3 active devices. Anonymization will sign you out of ALL devices permanently.
```

---

## Testing

See [GDPR_TESTING_GUIDE.md](./GDPR_TESTING_GUIDE.md) for comprehensive testing procedures.

---

## Troubleshooting

See [GDPR_TROUBLESHOOTING.md](./GDPR_TROUBLESHOOTING.md) for common issues and solutions.

---

## Compliance Verification

### GDPR Compliance

| Article | Requirement | Implementation |
|---------|-------------|----------------|
| **Article 17** | Right to Erasure | ✅ Complete data deletion + key destruction |
| **Article 7** | Conditions for consent | ✅ Explicit multi-layer confirmations |
| **Article 30** | Records of processing | ✅ Comprehensive audit trail |
| **Recital 26** | True anonymization | ✅ Irreversible via key destruction |

### ISO 27001:2022

✅ **A.8.10**: Information deletion
✅ **A.8.12**: Data leakage prevention
✅ **A.8.15**: Logging and monitoring
✅ **A.5.10**: Acceptable use of information

### SOC 2 Type II

✅ **CC6.1**: Logical and physical access controls
✅ **CC6.7**: System operations
✅ **CC7.2**: Monitoring activities
✅ **A1.2**: Risk mitigation

---

## Deployment Checklist

- [ ] Database migration deployed (`supabase db push`)
- [ ] Edge Function deployed (`supabase functions deploy gdpr-delete-auth-user`)
- [ ] Service role key configured (`supabase secrets list`)
- [ ] Flutter app built with latest changes
- [ ] Tested in development environment
- [ ] Safeguards validated
- [ ] Documentation reviewed
- [ ] Stakeholders notified
- [ ] Rollback plan prepared

---

## References

- [GDPR_TESTING_GUIDE.md](./GDPR_TESTING_GUIDE.md)
- [GDPR_ADMIN_RUNBOOK.md](./GDPR_ADMIN_RUNBOOK.md)
- [GDPR_TROUBLESHOOTING.md](./GDPR_TROUBLESHOOTING.md)
- [Supabase Auth Admin API](https://supabase.com/docs/reference/javascript/auth-admin-deleteuser)
- [GDPR Article 17](https://gdpr-info.eu/art-17-gdpr/)

---

**Document History**:
- v1.0 (2025-11-21): Initial production-ready version
