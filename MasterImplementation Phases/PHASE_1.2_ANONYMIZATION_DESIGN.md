# Phase 1.2: GDPR-Compliant Anonymization Design
**Date**: 2025-11-19
**Status**: Design Complete - Ready for Implementation
**Compliance Focus**: GDPR Article 17 (Right to Erasure) & Recital 26 (Anonymization)

---

## Executive Summary

This document provides a production-grade design for GDPR-compliant user data anonymization in Duru Notes. The design ensures **true anonymization** (not mere pseudonymization) through **irreversible key destruction and encrypted blob overwriting**, meeting GDPR Article 17 requirements while preserving system integrity and compliance audit trails.

**Key Legal Finding**: Under GDPR Recital 26, anonymization is an acceptable alternative to deletion if the data is **irreversibly de-identified** such that the data subject cannot be re-identified by any reasonably available means.

**Key Technical Finding**: For encrypted data systems, true anonymization requires **both** key destruction **and** encrypted blob overwriting to prevent forensic recovery.

---

## Table of Contents

1. [Legal Requirements Analysis](#1-legal-requirements-analysis)
2. [Technical Anonymization Strategy](#2-technical-anonymization-strategy)
3. [Data Classification Framework](#3-data-classification-framework)
4. [Implementation Architecture](#4-implementation-architecture)
5. [Compliance Validation Framework](#5-compliance-validation-framework)
6. [Risk Mitigation Strategies](#6-risk-mitigation-strategies)
7. [Testing Strategy](#7-testing-strategy)
8. [Implementation Roadmap](#8-implementation-roadmap)

---

## 1. Legal Requirements Analysis

### 1.1 GDPR Article 17 - Right to Erasure

**Applicable Provisions**:
- **Article 17(1)**: The data subject shall have the right to obtain from the controller the erasure of personal data concerning him or her without undue delay.
- **Article 17(3) Exemptions**: Erasure does NOT apply when processing is necessary for:
  - Compliance with legal obligations (e.g., financial records)
  - Establishment, exercise, or defense of legal claims (e.g., abuse reports)
  - Public interest, scientific/historical research (with safeguards)

**Key Legal Question**: Is anonymization sufficient for Article 17 compliance?

**Answer**: **YES**, according to GDPR Recital 26 and Austrian DPA ruling (DSB-D123.270/0009-DSB/2018):
> *"The principles of data protection should not apply to anonymous information, namely information which does not relate to an identified or identifiable natural person or to **personal data rendered anonymous in such a manner that the data subject is not or no longer identifiable**."*

**Legal Standard**: Anonymization satisfies Article 17 **if and only if** the data is **irreversibly anonymized** such that:
1. The data subject cannot be re-identified by the controller
2. The data subject cannot be re-identified by any third party using reasonably available means
3. The anonymization process cannot be reversed

### 1.2 GDPR Recital 26 - Anonymization vs Pseudonymization

**Identifiability Test** (from Recital 26):
> *"To determine whether a natural person is identifiable, account should be taken of all the means **reasonably likely to be used**, such as singling out, either by the controller or by another person to identify the natural person directly or indirectly."*

**Critical Distinction**:

| Aspect | Pseudonymization | Anonymization (True) |
|--------|------------------|---------------------|
| **Reversibility** | Reversible with additional information | Irreversible |
| **GDPR Applicability** | Still personal data (GDPR applies) | NOT personal data (GDPR does not apply) |
| **Re-identification Risk** | Possible if key/mapping exists | Impossible with reasonable means |
| **Example** | Encrypted data with key stored elsewhere | Encrypted data + key destroyed + blob overwritten |

**For Duru Notes**: Our encrypted data becomes truly anonymous when:
1. **Account Master Key (AMK)** is securely destroyed (local + remote)
2. **Legacy device keys** are securely destroyed
3. **Encrypted blobs** are overwritten with random data (prevent forensic recovery)
4. **User profile** is anonymized (email → `anonymized_{hash}@deleted.local`)

### 1.3 ISO 29100 Privacy Framework Standards

**ISO 29100:2024** defines best practices for PII management:

**Anonymization Requirements**:
- De-identify data to anonymize by default
- Don't assume removal of direct identifiers is sufficient
- Implement "privacy by design" approach

**Data Deletion Requirements** (ISO 27001:2022):
- **Control 8.3.2**: Secure deletion of unnecessary information
- **Methods**: Overwriting, cryptographic erase (key destruction), degaussing
- **Documentation**: Document deletion processes and verify completion

**Key Management**:
- Don't store encrypted data and keys where they can be simultaneously accessed
- Implement comprehensive key lifecycle management
- Ensure key destruction is irreversible

### 1.4 Legal Conclusion

**For GDPR Article 17 Compliance**, Duru Notes must implement:

✅ **MUST IMPLEMENT**:
1. **Cryptographic Erasure**: Destroy all encryption keys (AMK + legacy keys)
2. **Blob Overwriting**: Overwrite encrypted data before deletion
3. **Profile Anonymization**: Replace PII with anonymized placeholders
4. **Audit Log Anonymization**: Remove PII from audit trails (preserve structure)
5. **Export Before Erasure**: Offer data export (GDPR Article 20)
6. **Verification**: Prove data cannot be recovered

❌ **INSUFFICIENT** (Pseudonymization):
- Deleting keys without overwriting encrypted blobs (forensic recovery possible)
- Anonymizing profile without destroying keys (encrypted data still linkable)
- Soft deletion without overwriting (data remains in database blocks)

---

## 2. Technical Anonymization Strategy

### 2.1 Seven-Phase Anonymization Process

Our anonymization strategy follows a **defense-in-depth** approach with **irreversibility verification** at each stage.

```
┌─────────────────────────────────────────────────────────────────┐
│              GDPR-Compliant Anonymization Flow                  │
└─────────────────────────────────────────────────────────────────┘

Phase 1: Verification
  ├─ Generate confirmation code (6-digit, 15-minute expiry)
  ├─ Re-authenticate user (verify identity)
  ├─ Show irreversibility warning
  └─ Require explicit consent

Phase 2: Backup & Export (GDPR Article 20)
  ├─ Export all user data (decrypted JSON)
  ├─ Include: notes, tasks, folders, reminders, profile
  ├─ Verify export completeness
  └─ Provide download link (or save to device)

Phase 3: Encrypted Blob Overwriting
  ├─ Notes: Overwrite title_encrypted, body_encrypted, metadata_encrypted
  ├─ Tasks: Overwrite content_encrypted
  ├─ Folders: Overwrite name_encrypted, props_encrypted
  ├─ Reminders: Overwrite title_encrypted, body_encrypted, location_name_encrypted
  ├─ Method: Write random 32-byte sequences (CSRNG)
  └─ Verify: Read back and confirm overwrite

Phase 4: Key Destruction (Irreversible Step)
  ├─ Local AMK: 3-pass overwrite + delete (iOS Keychain / Android EncryptedSharedPrefs)
  ├─ Local Legacy Keys: 3-pass overwrite + delete
  ├─ Remote AMK: Overwrite user_keys.wrapped_key + delete row
  ├─ Remote Encryption Keys: Delete user_encryption_keys row
  ├─ Memory Overwriting: Zero out in-memory keys
  └─ Cross-Device Revocation: Broadcast key revocation event

Phase 5: Profile Anonymization
  ├─ Email: user@example.com → anonymized_{sha256(userId)[:16]}@deleted.local
  ├─ Name: "John Doe" → "Anonymized User"
  ├─ Profile Photo: Clear/delete
  ├─ Passphrase Hint: Clear
  ├─ Account Record: Preserve (for FK integrity, marked as anonymized)
  └─ Auth Metadata: Clear userMetadata, preserve minimal appMetadata

Phase 6: Audit Log Anonymization
  ├─ trash_events.item_title: "My Secret Note" → "ANONYMIZED"
  ├─ trash_events.user_id: Preserve (links to anonymized account)
  ├─ trash_events.metadata: Add {"anonymized": true, "timestamp": ISO8601}
  ├─ Security Audit Logs: Rotate/archive (90-day retention)
  └─ Insert anonymization event: action="anonymize_account"

Phase 7: Verification & Logging
  ├─ Verify AMK destruction (local + remote)
  ├─ Verify legacy key destruction
  ├─ Attempt to decrypt sample data (MUST FAIL)
  ├─ Scan for remaining PII (MUST be clean)
  ├─ Log anonymization completion event
  └─ Return anonymization report (timestamp, verification results)
```

### 2.2 Phase 3: Encrypted Blob Overwriting (Detailed)

**Current Implementation** (Reminders Only - lines 815-837 in gdpr_compliance_service.dart):
```dart
await (db.update(db.noteReminders)..where(...))
  .write(NoteRemindersCompanion(
    titleEncrypted: Value(Uint8List.fromList(List.filled(32, 0))),
    bodyEncrypted: Value(Uint8List.fromList(List.filled(32, 0))),
    locationNameEncrypted: Value(Uint8List.fromList(List.filled(32, 0))),
    title: const Value(''),
    body: const Value(''),
    locationName: const Value(''),
  ));
```

**Required Extension** (Apply to All Encrypted Entities):

**Notes** (`local_notes` table):
```dart
Future<void> _overwriteNoteEncryptedBlobs(String userId) async {
  final userNoteIds = await (db.select(db.localNotes)
    ..where((n) => n.userId.equals(userId))).map((n) => n.id).get();
  
  if (userNoteIds.isEmpty) return;
  
  // Batch overwrite for performance (1000 notes per batch)
  const batchSize = 1000;
  for (var i = 0; i < userNoteIds.length; i += batchSize) {
    final batch = userNoteIds.skip(i).take(batchSize).toList();
    
    await (db.update(db.localNotes)..where((n) => n.id.isIn(batch)))
      .write(LocalNotesCompanion(
        titleEncrypted: Value(_randomBytes(32)),
        bodyEncrypted: Value(_randomBytes(256)),  // Larger for body
        metadataEncrypted: Value(_randomBytes(64)),
        // Clear plaintext fields if any
        title: const Value('[ANONYMIZED]'),
      ));
  }
}

Uint8List _randomBytes(int length) {
  final rng = Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => rng.nextInt(256)));
}
```

**Tasks** (`note_tasks` table):
```dart
Future<void> _overwriteTaskEncryptedBlobs(String userId) async {
  final userNoteIds = await (db.select(db.localNotes)
    ..where((n) => n.userId.equals(userId))).map((n) => n.id).get();
  
  if (userNoteIds.isEmpty) return;
  
  await (db.update(db.noteTasks)..where((t) => t.noteId.isIn(userNoteIds)))
    .write(NoteTasksCompanion(
      contentEncrypted: Value(_randomBytes(128)),
      content: const Value('[ANONYMIZED]'),
    ));
}
```

**Folders** (`local_folders` table):
```dart
Future<void> _overwriteFolderEncryptedBlobs(String userId) async {
  await (db.update(db.localFolders)..where((f) => f.userId.equals(userId)))
    .write(LocalFoldersCompanion(
      nameEncrypted: Value(_randomBytes(64)),
      propsEncrypted: Value(_randomBytes(128)),
      name: const Value('[ANONYMIZED]'),
    ));
}
```

**Why Random Data Instead of Zeros?**
- **Forensic Detection**: All-zero patterns are easily identifiable as "wiped" data
- **Plausible Deniability**: Random data looks like valid encrypted content
- **Defense in Depth**: Even if keys were somehow recovered, decryption yields random noise

### 2.3 Phase 4: Key Destruction (Detailed)

**Multi-Layer Key Destruction** (Defense in Depth):

**Layer 1: Local Device Key Destruction**
```dart
/// Secure key destruction with DoD 5220.22-M 3-pass overwrite
Future<void> securelyDestroyMasterKey(String userId) async {
  final keyName = '$_prefix$userId';
  
  // 1. Read current key
  final currentKey = await _storage.read(key: keyName);
  if (currentKey == null) return; // Already deleted
  
  // 2. DoD 5220.22-M: 3-pass overwrite
  // Pass 1: Write 0x00
  await _storage.write(key: keyName, value: base64Encode(List.filled(32, 0x00)));
  
  // Pass 2: Write 0xFF
  await _storage.write(key: keyName, value: base64Encode(List.filled(32, 0xFF)));
  
  // Pass 3: Write random data
  await _storage.write(
    key: keyName,
    value: base64Encode(_randomBytes(32)),
  );
  
  // 3. Delete keychain entry
  await _storage.delete(key: keyName);
  
  // 4. Memory overwriting (best effort - Dart GC limitations)
  if (currentKey != null) {
    final bytes = base64Decode(currentKey);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }
  
  // 5. Verify deletion
  final verification = await _storage.read(key: keyName);
  if (verification != null) {
    throw Exception('Key destruction verification failed');
  }
}
```

**Layer 2: Account Master Key (AMK) Destruction**
```dart
Future<void> destroyRemoteAmk(String userId) async {
  // 1. Overwrite wrapped_key with random data
  await _client.from('user_keys').upsert({
    'user_id': userId,
    'wrapped_key': base64Encode(_randomBytes(256)),
    'kdf_params': {'overwritten': true},
  });
  
  // 2. Delete row
  await _client.from('user_keys').delete().eq('user_id', userId);
  
  // 3. Delete user_encryption_keys row
  await _client.from('user_encryption_keys').delete().eq('user_id', userId);
  
  // 4. Clear local AMK cache
  await clearLocalAmk();
}
```

**Layer 3: Cross-Device Key Revocation**

**New Table**: `key_revocation_events` (Supabase migration)
```sql
CREATE TABLE public.key_revocation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  revocation_timestamp timestamptz NOT NULL DEFAULT timezone('utc', now()),
  reason text NOT NULL CHECK (reason IN ('user_requested', 'account_anonymized', 'security_breach')),
  
  -- RLS: Users can only read their own revocation events
  CONSTRAINT rls_user_only CHECK (user_id = auth.uid())
);

CREATE INDEX key_revocation_user_idx ON public.key_revocation_events (user_id, revocation_timestamp DESC);

ALTER TABLE public.key_revocation_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY key_revocation_select_own ON public.key_revocation_events
  FOR SELECT USING (user_id = auth.uid());
```

**Client-Side Revocation Check** (on app startup):
```dart
Future<void> checkKeyRevocation(String userId) async {
  final revocations = await _client
    .from('key_revocation_events')
    .select()
    .eq('user_id', userId)
    .order('revocation_timestamp', ascending: false)
    .limit(1);
  
  if (revocations.isNotEmpty) {
    // Keys revoked - force re-authentication or show anonymization message
    await clearLocalAmk();
    await deleteMasterKey(userId);
    throw KeyRevokedException('Account keys have been revoked');
  }
}
```

**Broadcast Revocation Event**:
```dart
Future<void> broadcastKeyRevocation(String userId, String reason) async {
  await _client.from('key_revocation_events').insert({
    'user_id': userId,
    'reason': reason,
  });
}
```

### 2.4 Phase 5: Profile Anonymization (Detailed)

**Supabase Auth User Anonymization**:

GDPR requires we CAN'T delete auth.users due to:
1. Foreign key integrity (ON DELETE CASCADE would cascade to audit logs)
2. Legal retention requirements (audit logs must be kept)
3. System stability (orphaned references)

**Solution**: Anonymize in place

```dart
Future<void> anonymizeUserProfile(String userId) async {
  // 1. Generate anonymized email
  final hash = sha256.convert(utf8.encode(userId)).toString();
  final anonymizedEmail = 'anonymized_${hash.substring(0, 16)}@deleted.local';
  
  // 2. Update Supabase Auth user metadata
  await _client.auth.admin.updateUserById(
    userId,
    attributes: UserAttributes(
      email: anonymizedEmail,
      data: {
        'anonymized': true,
        'anonymized_at': DateTime.now().toIso8601String(),
      },
    ),
  );
  
  // 3. Update user_profiles table
  await _client.from('user_profiles').update({
    'email': anonymizedEmail,
    'first_name': 'Anonymized',
    'last_name': 'User',
    'passphrase_hint': null,
  }).eq('user_id', userId);
  
  // 4. Clear profile photo (Supabase Storage)
  try {
    await _client.storage.from('avatars').remove(['$userId.jpg']);
  } catch (e) {
    // Profile photo may not exist - ignore
  }
}
```

### 2.5 Phase 6: Audit Log Anonymization (Detailed)

**Principle**: Preserve audit structure for compliance, remove PII

**Supabase Function** (new migration):
```sql
CREATE OR REPLACE FUNCTION public.anonymize_user_audit_trail(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Anonymize trash_events
  UPDATE public.trash_events
  SET
    item_title = 'ANONYMIZED',
    metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
      'anonymized', true,
      'anonymized_at', timezone('utc', now())
    )
  WHERE user_id = p_user_id;
  
  -- Insert anonymization event
  INSERT INTO public.trash_events (
    user_id,
    item_type,
    item_id,
    item_title,
    action,
    metadata
  ) VALUES (
    p_user_id,
    'account',
    p_user_id,
    'ANONYMIZED',
    'permanent_delete', -- Treated as permanent action
    jsonb_build_object(
      'action', 'account_anonymized',
      'timestamp', timezone('utc', now()),
      'gdpr_article_17', true
    )
  );
END;
$$;

COMMENT ON FUNCTION public.anonymize_user_audit_trail IS
  'Anonymizes all audit log entries for a user while preserving audit structure for compliance';

GRANT EXECUTE ON FUNCTION public.anonymize_user_audit_trail TO authenticated;
```

**Client-Side Invocation**:
```dart
Future<void> anonymizeAuditLogs(String userId) async {
  await _client.rpc('anonymize_user_audit_trail', params: {'p_user_id': userId});
}
```

**Security Audit Logs** (Local Files):
- **Retention**: 90 days (configured in SecurityAuditTrail)
- **Action**: Archive logs older than 30 days before anonymization
- **Preservation**: Keep anonymization event itself (for compliance proof)

```dart
Future<void> archiveAndRotateSecurityAuditLogs(String userId) async {
  final auditTrail = SecurityAuditTrail();
  
  // Archive last 30 days
  final archive = await auditTrail.getAuditReport(
    startDate: DateTime.now().subtract(Duration(days: 30)),
    endDate: DateTime.now(),
  );
  
  // Save archive
  final archiveFile = File('${documentsDir}/security_audit/anonymization_archive_${userId}_${DateTime.now().millisecondsSinceEpoch}.json');
  await archiveFile.writeAsString(jsonEncode(archive));
  
  // Log anonymization event
  await auditTrail.logAccess(
    resource: 'User Account',
    granted: true,
    reason: 'Account anonymized per GDPR Article 17 request',
  );
  
  // Rotate logs (delete older than 30 days)
  // New logs will have anonymized userId references
}
```

### 2.6 Phase 7: Verification & Logging (Detailed)

**Comprehensive Verification Checklist**:

```dart
class AnonymizationVerificationReport {
  final bool amkDestroyed;
  final bool legacyKeysDestroyed;
  final bool encryptedBlobsOverwritten;
  final bool profileAnonymized;
  final bool auditLogsAnonymized;
  final bool decryptionFails;
  final bool noPiiRemaining;
  final DateTime verificationTimestamp;
  final List<String> warnings;
  
  bool get isFullyAnonymized =>
    amkDestroyed &&
    legacyKeysDestroyed &&
    encryptedBlobsOverwritten &&
    profileAnonymized &&
    auditLogsAnonymized &&
    decryptionFails &&
    noPiiRemaining;
}

Future<AnonymizationVerificationReport> verifyAnonymization(String userId) async {
  final warnings = <String>[];
  
  // 1. Verify AMK destroyed (local)
  final localAmk = await getLocalAmk(userId: userId);
  final amkDestroyed = localAmk == null;
  if (!amkDestroyed) warnings.add('Local AMK still present');
  
  // 2. Verify AMK destroyed (remote)
  final remoteAmk = await _client.from('user_keys')
    .select()
    .eq('user_id', userId)
    .maybeSingle();
  final remoteAmkDestroyed = remoteAmk == null;
  if (!remoteAmkDestroyed) warnings.add('Remote AMK still present');
  
  // 3. Verify legacy keys destroyed
  final legacyKey = await _storage.read(key: 'mk:$userId');
  final legacyKeysDestroyed = legacyKey == null;
  if (!legacyKeysDestroyed) warnings.add('Legacy device key still present');
  
  // 4. Verify encrypted blobs overwritten (sample check)
  final sampleNote = await (db.select(db.localNotes)
    ..where((n) => n.userId.equals(userId))
    ..limit(1)).getSingleOrNull();
  
  bool encryptedBlobsOverwritten = true;
  if (sampleNote != null) {
    // Check if blobs are random (not all zeros, not original data)
    if (sampleNote.titleEncrypted != null) {
      final titleBytes = sampleNote.titleEncrypted!;
      if (titleBytes.every((b) => b == 0) || titleBytes.length == 0) {
        warnings.add('Encrypted blobs not properly overwritten');
        encryptedBlobsOverwritten = false;
      }
    }
  }
  
  // 5. Verify profile anonymized
  final profile = await _client.from('user_profiles')
    .select()
    .eq('user_id', userId)
    .single();
  
  final profileAnonymized = profile['email'].toString().startsWith('anonymized_');
  if (!profileAnonymized) warnings.add('Profile email not anonymized');
  
  // 6. Verify audit logs anonymized
  final auditSample = await _client.from('trash_events')
    .select()
    .eq('user_id', userId)
    .limit(1)
    .maybeSingle();
  
  final auditLogsAnonymized = auditSample == null || 
    auditSample['item_title'] == 'ANONYMIZED';
  if (!auditLogsAnonymized) warnings.add('Audit logs not fully anonymized');
  
  // 7. Verify decryption fails (critical test)
  bool decryptionFails = false;
  if (sampleNote != null && sampleNote.titleEncrypted != null) {
    try {
      await cryptoBox.decryptStringForNote(
        userId: userId,
        noteId: sampleNote.id,
        data: sampleNote.titleEncrypted!,
      );
      warnings.add('CRITICAL: Decryption succeeded - anonymization failed!');
    } catch (e) {
      // Expected: decryption should fail
      decryptionFails = true;
    }
  } else {
    decryptionFails = true; // No data to decrypt
  }
  
  // 8. Scan for remaining PII
  final noPiiRemaining = await _scanForPii(userId);
  if (!noPiiRemaining) warnings.add('PII detected in database');
  
  return AnonymizationVerificationReport(
    amkDestroyed: amkDestroyed && remoteAmkDestroyed,
    legacyKeysDestroyed: legacyKeysDestroyed,
    encryptedBlobsOverwritten: encryptedBlobsOverwritten,
    profileAnonymized: profileAnonymized,
    auditLogsAnonymized: auditLogsAnonymized,
    decryptionFails: decryptionFails,
    noPiiRemaining: noPiiRemaining,
    verificationTimestamp: DateTime.now(),
    warnings: warnings,
  );
}

Future<bool> _scanForPii(String userId) async {
  // Scan database for common PII patterns
  // This is a heuristic check, not exhaustive
  
  // Check notes for email patterns
  final notesWithEmail = await db.customSelect(
    'SELECT COUNT(*) as count FROM local_notes WHERE user_id = ? AND (title LIKE "%@%" OR body LIKE "%@%")',
    variables: [Variable.withString(userId)],
  ).getSingle();
  
  if (notesWithEmail.read<int>('count') > 0) return false;
  
  // Add more PII pattern checks as needed
  
  return true;
}
```

---

## 3. Data Classification Framework

### 3.1 Decision Matrix: Delete vs Anonymize vs Retain

```
┌─────────────────────────────────────────────────────────────────────┐
│                  Data Classification Decision Tree                  │
└─────────────────────────────────────────────────────────────────────┘

                        ┌─────────────┐
                        │  User Data  │
                        └──────┬──────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
         ┌──────▼──────┐  ┌───▼───┐  ┌──────▼──────┐
         │  MUST       │  │  CAN  │  │   MUST      │
         │  DELETE     │  │ ANON  │  │  PRESERVE   │
         └─────────────┘  └───────┘  └─────────────┘
```

### 3.2 MUST DELETE (Complete Removal Required)

**Legal Basis**: GDPR Article 17(1) - No exemptions apply

| Data Type | Location | Deletion Method | Verification |
|-----------|----------|-----------------|--------------|
| **Account Master Key (AMK)** | `user_keys` (Supabase) | 3-pass overwrite + DELETE | Query returns null |
| **Account Master Key (AMK)** | Local secure storage | 3-pass overwrite + delete | Read returns null |
| **Legacy Device Keys** | iOS Keychain / Android EncryptedSharedPrefs | 3-pass overwrite + delete | Read returns null |
| **User Encryption Keys** | `user_encryption_keys` (Supabase) | DELETE row | Query returns null |
| **Passphrase Hint** | `user_profiles.passphrase_hint` | SET NULL | Field is null |
| **Profile Photo** | Supabase Storage `avatars/` | DELETE blob | File not found |
| **Cached Files** | Temporary directory | DELETE directory | Directory empty |
| **Secure Storage (All)** | FlutterSecureStorage | deleteAll() | isEmpty() returns true |
| **Shared Preferences (User-specific)** | SharedPreferences | Remove user keys | Keys not found |

### 3.3 CAN ANONYMIZE AND RETAIN (Irreversibly De-identify)

**Legal Basis**: GDPR Recital 26 - Anonymized data is not personal data

| Data Type | Original State | Anonymized State | Retention Justification |
|-----------|----------------|------------------|------------------------|
| **Encrypted Note Content** | `title_encrypted` = encrypted bytes | Random bytes (32B+) | System integrity (FK relationships) |
| **Encrypted Task Content** | `content_encrypted` = encrypted bytes | Random bytes (128B) | System integrity |
| **Encrypted Folder Names** | `name_encrypted` = encrypted bytes | Random bytes (64B) | System integrity |
| **User Email** | `user@example.com` | `anonymized_abc123@deleted.local` | Auth system integrity |
| **User Name** | `John Doe` | `Anonymized User` | Profile structure |
| **Audit Log Item Titles** | `"My Secret Note"` | `"ANONYMIZED"` | Compliance audit trail (legal requirement) |
| **Audit Log Metadata** | Timestamps, actions | Add `{anonymized: true}` | Compliance audit trail |
| **Account Record** | Active user | Marked as anonymized | FK integrity, legal hold |

**Irreversibility Guarantees**:
- Keys destroyed → Encrypted blobs are random noise (cannot decrypt)
- Email anonymized with one-way hash → Cannot reverse to original
- Audit log titles replaced → Original content unrecoverable

### 3.4 MUST PRESERVE (Legal/Compliance Obligations)

**Legal Basis**: GDPR Article 17(3) exemptions

| Data Type | Retention Period | Legal Basis | Access Control |
|-----------|------------------|-------------|----------------|
| **Anonymized Audit Logs** | 7 years | Legal compliance, defense of legal claims | Admin only |
| **Anonymized Account Record** | Indefinite | System integrity, FK relationships | System only (no user access) |
| **Anonymization Event Log** | 7 years | Proof of GDPR compliance | Admin only |
| **Financial Records** | 7 years (if subscription exists) | Tax law, accounting requirements | Admin only |
| **Abuse/Safety Reports** | 7 years | Legal obligation, public safety | Legal team only |

**Anonymization Requirement**: Even preserved data MUST be anonymized (no PII)

### 3.5 Shared Content Handling

**Current State**: No shared content (confirmed in research)
- All data filtered by `userId`
- RLS policies: `auth.uid()` enforcement
- No cross-user queries in repositories

**Future-Proofing**: If collaborative features added later:

**Decision Rule**:
```
IF content is single-user owned:
  → Anonymize per standard process

ELSE IF content is shared/collaborative:
  → User's contributions: Anonymize (replace with "Deleted User")
  → Other users' data: PRESERVE
  → Shared ownership: Requires consent from ALL owners
```

**Example**: Shared Note
- User A requests anonymization
- Shared note with User B
- **Action**: 
  - User A's edits/comments → Replace with "[Deleted User]"
  - Note remains accessible to User B
  - User A's ownership claim removed

**Recommendation**: Add `is_shared` flag to all content tables for future use

---

## 4. Implementation Architecture

### 4.1 Service Structure

**New Service**: `AnonymizationService`
**Location**: `/lib/services/anonymization_service.dart`

**Dependencies**:
- `GDPRComplianceService` (for export)
- `AccountKeyService` (for AMK destruction)
- `KeyManager` (for legacy key destruction)
- `CryptoBox` (for decryption verification)
- `AppDb` (for database operations)
- `SupabaseClient` (for remote operations)
- `SecurityAuditTrail` (for audit logging)

**API Surface**:
```dart
class AnonymizationService {
  /// Main anonymization workflow
  Future<AnonymizationResult> anonymizeUserData({
    required String userId,
    required String confirmationCode,
    bool createBackup = true,
    ProgressCallback? onProgress,
  });
  
  /// Phase-specific methods (for testing and granular control)
  Future<String> generateConfirmationCode(String userId);
  Future<bool> verifyConfirmationCode(String userId, String code);
  Future<File> createBackupExport(String userId);
  Future<void> overwriteEncryptedBlobs(String userId);
  Future<void> destroyEncryptionKeys(String userId);
  Future<void> anonymizeUserProfile(String userId);
  Future<void> anonymizeAuditLogs(String userId);
  Future<void> deleteSupabaseStorage(String userId);
  Future<AnonymizationVerificationReport> verifyAnonymization(String userId);
  
  /// Utility methods
  Future<void> broadcastKeyRevocation(String userId);
  Future<void> createAnonymizationProof(String userId, AnonymizationVerificationReport report);
}
```

### 4.2 Data Flow Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Anonymization Data Flow                           │
└──────────────────────────────────────────────────────────────────────┘

User Request
     │
     ▼
┌──────────────────────┐
│  UI Layer            │
│  - Confirmation Flow │
│  - Progress Tracking │
│  - Export Download   │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ AnonymizationService │ ◄─── Orchestrates entire process
└──────┬───────────────┘
       │
       ├──────────────────────┬──────────────────────┬──────────────────────┐
       │                      │                      │                      │
       ▼                      ▼                      ▼                      ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   AppDb     │      │AccountKey   │      │  KeyManager │      │  Supabase   │
│  (Drift)    │      │  Service    │      │             │      │   Client    │
│             │      │             │      │             │      │             │
│ - Overwrite │      │ - Destroy   │      │ - Destroy   │      │ - Anonymize │
│   blobs     │      │   AMK       │      │   legacy    │      │   profile   │
│             │      │   (remote)  │      │   keys      │      │ - Delete    │
│ - Delete    │      │ - Clear AMK │      │             │      │   user_keys │
│   records   │      │   (local)   │      │             │      │ - Anonymize │
└─────────────┘      └─────────────┘      └─────────────┘      │   audit logs│
                                                                 └─────────────┘
       │                      │                      │                      │
       └──────────────────────┴──────────────────────┴──────────────────────┘
                                       │
                                       ▼
                          ┌─────────────────────────┐
                          │ Verification &          │
                          │ Proof Generation        │
                          │                         │
                          │ - Verify keys destroyed │
                          │ - Test decryption fails │
                          │ - Generate report       │
                          │ - Log to audit trail    │
                          └─────────────────────────┘
```

### 4.3 Database Schema Changes

**New Migration**: `20250320000000_add_anonymization_support.sql`

```sql
-- =====================================================
-- 1. Add key_revocation_events table
-- =====================================================

CREATE TABLE public.key_revocation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  revocation_timestamp timestamptz NOT NULL DEFAULT timezone('utc', now()),
  reason text NOT NULL CHECK (reason IN ('user_requested', 'account_anonymized', 'security_breach')),
  metadata jsonb,
  
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX key_revocation_user_idx ON public.key_revocation_events (user_id, revocation_timestamp DESC);

ALTER TABLE public.key_revocation_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY key_revocation_select_own ON public.key_revocation_events
  FOR SELECT USING (user_id = auth.uid());

-- =====================================================
-- 2. Add anonymization tracking to user_profiles
-- =====================================================

ALTER TABLE public.user_profiles
  ADD COLUMN anonymized_at timestamptz,
  ADD COLUMN anonymization_report jsonb;

COMMENT ON COLUMN public.user_profiles.anonymized_at IS
  'Timestamp when account was anonymized per GDPR Article 17';

COMMENT ON COLUMN public.user_profiles.anonymization_report IS
  'Verification report from anonymization process (for compliance proof)';

-- =====================================================
-- 3. Create anonymization helper function
-- =====================================================

CREATE OR REPLACE FUNCTION public.anonymize_user_audit_trail(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Anonymize trash_events
  UPDATE public.trash_events
  SET
    item_title = 'ANONYMIZED',
    metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
      'anonymized', true,
      'anonymized_at', timezone('utc', now())
    )
  WHERE user_id = p_user_id;
  
  -- Insert anonymization event
  INSERT INTO public.trash_events (
    user_id,
    item_type,
    item_id,
    item_title,
    action,
    metadata
  ) VALUES (
    p_user_id,
    'account',
    p_user_id,
    'ANONYMIZED',
    'permanent_delete',
    jsonb_build_object(
      'action', 'account_anonymized',
      'timestamp', timezone('utc', now()),
      'gdpr_article_17', true
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.anonymize_user_audit_trail TO authenticated;

-- =====================================================
-- 4. Create anonymization proof storage
-- =====================================================

CREATE TABLE public.anonymization_proofs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  anonymization_timestamp timestamptz NOT NULL DEFAULT timezone('utc', now()),
  verification_report jsonb NOT NULL,
  proof_hash text NOT NULL, -- SHA-256 hash of report for integrity
  
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX anonymization_proofs_user_idx ON public.anonymization_proofs (user_id);

ALTER TABLE public.anonymization_proofs ENABLE ROW LEVEL SECURITY;

CREATE POLICY anonymization_proofs_select_own ON public.anonymization_proofs
  FOR SELECT USING (user_id = auth.uid());

COMMENT ON TABLE public.anonymization_proofs IS
  'Immutable proof of GDPR-compliant anonymization for legal compliance';
```

### 4.4 Progress Tracking & User Feedback

**Progress Callback Interface**:
```dart
typedef ProgressCallback = void Function(AnonymizationProgress progress);

class AnonymizationProgress {
  final AnonymizationPhase currentPhase;
  final int currentStep;
  final int totalSteps;
  final String message;
  final double percentage;
  
  const AnonymizationProgress({
    required this.currentPhase,
    required this.currentStep,
    required this.totalSteps,
    required this.message,
  }) : percentage = (currentStep / totalSteps) * 100;
}

enum AnonymizationPhase {
  verification,
  backup,
  overwritingBlobs,
  destroyingKeys,
  anonymizingProfile,
  anonymizingAuditLogs,
  verification,
  complete,
}
```

**UI Progress Flow**:
```dart
await anonymizationService.anonymizeUserData(
  userId: userId,
  confirmationCode: code,
  createBackup: true,
  onProgress: (progress) {
    setState(() {
      _currentProgress = progress;
    });
    
    // Update UI
    // Show progress bar: progress.percentage
    // Show phase: progress.currentPhase.name
    // Show message: progress.message
  },
);
```

**Example Progress Messages**:
1. "Verifying confirmation code..."
2. "Creating encrypted backup... (1/7)"
3. "Overwriting encrypted data... (2/7)"
4. "Destroying encryption keys... (3/7)"
5. "Anonymizing profile... (4/7)"
6. "Anonymizing audit logs... (5/7)"
7. "Verifying anonymization... (6/7)"
8. "Complete! Your data has been anonymized." (7/7)

### 4.5 Error Handling & Rollback

**Critical Insight**: After Phase 4 (Key Destruction), **rollback is IMPOSSIBLE**

**Pre-Key-Destruction Errors** (Phases 1-3):
- **Strategy**: Full rollback
- **Action**: Revert blob overwrites, delete backup, return error

**Post-Key-Destruction Errors** (Phases 5-7):
- **Strategy**: Best-effort completion
- **Action**: Log error, continue with remaining phases, mark as "partially anonymized"

```dart
class AnonymizationResult {
  final bool success;
  final AnonymizationVerificationReport? verificationReport;
  final List<String> errors;
  final List<String> warnings;
  final DateTime timestamp;
  final File? backupFile;
  
  bool get isFullyAnonymized => success && (verificationReport?.isFullyAnonymized ?? false);
  bool get isPartiallyAnonymized => !success && verificationReport != null;
}

Future<AnonymizationResult> anonymizeUserData({...}) async {
  final errors = <String>[];
  final warnings = <String>[];
  File? backupFile;
  
  try {
    // Phase 1: Verification
    onProgress?.call(AnonymizationProgress(
      currentPhase: AnonymizationPhase.verification,
      currentStep: 1,
      totalSteps: 7,
      message: 'Verifying confirmation code...',
    ));
    
    if (!await verifyConfirmationCode(userId, confirmationCode)) {
      throw AnonymizationException('Invalid confirmation code');
    }
    
    // Phase 2: Backup
    if (createBackup) {
      onProgress?.call(AnonymizationProgress(
        currentPhase: AnonymizationPhase.backup,
        currentStep: 2,
        totalSteps: 7,
        message: 'Creating encrypted backup...',
      ));
      
      try {
        backupFile = await createBackupExport(userId);
      } catch (e) {
        warnings.add('Backup creation failed: $e');
        // Continue without backup if user consented
      }
    }
    
    // Phase 3: Blob Overwriting (Reversible)
    onProgress?.call(AnonymizationProgress(
      currentPhase: AnonymizationPhase.overwritingBlobs,
      currentStep: 3,
      totalSteps: 7,
      message: 'Overwriting encrypted data...',
    ));
    
    try {
      await overwriteEncryptedBlobs(userId);
    } catch (e) {
      // ROLLBACK: Before key destruction, we can still abort
      throw AnonymizationException('Blob overwriting failed: $e');
    }
    
    // POINT OF NO RETURN: Phase 4 - Key Destruction
    onProgress?.call(AnonymizationProgress(
      currentPhase: AnonymizationPhase.destroyingKeys,
      currentStep: 4,
      totalSteps: 7,
      message: 'Destroying encryption keys... (irreversible)',
    ));
    
    try {
      await destroyEncryptionKeys(userId);
    } catch (e) {
      // CANNOT ROLLBACK: Keys may be partially destroyed
      errors.add('Key destruction failed: $e');
      // Continue best-effort
    }
    
    // Phase 5-7: Best-effort completion
    // (errors logged but don't stop process)
    
    // ... remaining phases
    
    // Final verification
    final verificationReport = await verifyAnonymization(userId);
    
    return AnonymizationResult(
      success: errors.isEmpty && verificationReport.isFullyAnonymized,
      verificationReport: verificationReport,
      errors: errors,
      warnings: warnings,
      timestamp: DateTime.now(),
      backupFile: backupFile,
    );
    
  } catch (e, stack) {
    _logger.error('Anonymization failed', error: e, stackTrace: stack);
    
    return AnonymizationResult(
      success: false,
      verificationReport: null,
      errors: [e.toString(), ...errors],
      warnings: warnings,
      timestamp: DateTime.now(),
      backupFile: backupFile,
    );
  }
}
```

---

## 5. Compliance Validation Framework

### 5.1 Test Cases for GDPR Compliance

**Test Suite**: `test/services/anonymization_service_test.dart`

**Test 1: Irreversibility Test**
```dart
test('anonymized data cannot be recovered after anonymization', () async {
  // Setup
  final userId = 'test_user_123';
  final testNote = await createTestNote(userId, title: 'Secret Data', body: 'Confidential Info');
  
  // Backup keys before anonymization (simulate attacker with backups)
  final amkBackup = await accountKeyService.getLocalAmk();
  final legacyKeyBackup = await keyManager.getMasterKey(userId);
  
  // Act: Anonymize
  final result = await anonymizationService.anonymizeUserData(
    userId: userId,
    confirmationCode: await anonymizationService.generateConfirmationCode(userId),
  );
  
  // Assert: Anonymization succeeded
  expect(result.success, isTrue);
  expect(result.verificationReport.isFullyAnonymized, isTrue);
  
  // Critical Test: Try to restore keys and decrypt
  await accountKeyService.setLocalAmk(amkBackup!);
  await keyManager.setMasterKey(userId, legacyKeyBackup);
  
  final anonymizedNote = await db.getNote(testNote.id);
  
  // Decryption MUST fail (blobs are random data now)
  expect(
    () => cryptoBox.decryptStringForNote(
      userId: userId,
      noteId: anonymizedNote.id,
      data: anonymizedNote.titleEncrypted!,
    ),
    throwsA(isA<DecryptionException>()),
  );
  
  // Decrypted content MUST NOT match original
  final decryptedTitle = await _attemptDecrypt(anonymizedNote.titleEncrypted!);
  expect(decryptedTitle, isNot('Secret Data'));
});
```

**Test 2: De-identification Test**
```dart
test('anonymized account cannot be linked back to user', () async {
  // Setup
  final userId = 'test_user_123';
  final originalEmail = 'john.doe@example.com';
  
  await setupUserProfile(userId, email: originalEmail, name: 'John Doe');
  
  // Act: Anonymize
  await anonymizationService.anonymizeUserData(
    userId: userId,
    confirmationCode: await anonymizationService.generateConfirmationCode(userId),
  );
  
  // Assert: Profile is anonymized
  final profile = await supabase.from('user_profiles').select().eq('user_id', userId).single();
  
  expect(profile['email'], isNot(originalEmail));
  expect(profile['email'], startsWith('anonymized_'));
  expect(profile['first_name'], equals('Anonymized'));
  expect(profile['last_name'], equals('User'));
  
  // Assert: Cannot reverse email to original
  expect(profile['email'], isNot(contains('john')));
  expect(profile['email'], isNot(contains('doe')));
  
  // Assert: Audit logs are anonymized
  final auditLogs = await supabase.from('trash_events').select().eq('user_id', userId).get();
  
  for (final log in auditLogs) {
    expect(log['item_title'], equals('ANONYMIZED'));
  }
});
```

**Test 3: PII Removal Test**
```dart
test('no PII remains after anonymization', () async {
  // Setup
  final userId = 'test_user_123';
  
  await setupUserWithData(userId,
    email: 'test@example.com',
    name: 'Test User',
    notes: ['Note with email: personal@example.com', 'Secret task'],
    tasks: ['Buy gift for test@example.com'],
  );
  
  // Act: Anonymize
  await anonymizationService.anonymizeUserData(
    userId: userId,
    confirmationCode: await anonymizationService.generateConfirmationCode(userId),
  );
  
  // Assert: Scan entire database for PII
  final piiScanResult = await _scanDatabaseForPii(userId);
  
  expect(piiScanResult.emailsFound, isEmpty);
  expect(piiScanResult.namesFound, isEmpty);
  expect(piiScanResult.phoneNumbersFound, isEmpty);
  
  // Assert: Encrypted blobs are random
  final notes = await db.select(db.localNotes).where((n) => n.userId.equals(userId)).get();
  
  for (final note in notes) {
    // Blobs should be random (entropy check)
    expect(_calculateEntropy(note.titleEncrypted!), greaterThan(7.0)); // High entropy = random
  }
});
```

**Test 4: Export Completeness Test (GDPR Article 20)**
```dart
test('exported data contains all user information', () async {
  // Setup
  final userId = 'test_user_123';
  
  await setupUserWithData(userId,
    notes: 10,
    tasks: 20,
    folders: 3,
    reminders: 5,
  );
  
  // Act: Export
  final exportFile = await anonymizationService.createBackupExport(userId);
  
  // Assert: Export contains all data
  final exportData = jsonDecode(await exportFile.readAsString());
  
  expect(exportData['userData']['notes'], hasLength(10));
  expect(exportData['userData']['tasks'], hasLength(20));
  expect(exportData['userData']['folders'], hasLength(3));
  expect(exportData['userData']['reminders'], hasLength(5));
  
  // Assert: Notes are decrypted
  final firstNote = exportData['userData']['notes'][0];
  expect(firstNote['title'], isNot('[DECRYPTION_FAILED]'));
  expect(firstNote['body'], isNot('[DECRYPTION_FAILED]'));
  
  // Assert: GDPR metadata present
  expect(exportData['exportMetadata']['gdprCompliant'], isTrue);
  expect(exportData['exportMetadata']['format'], equals('JSON'));
});
```

**Test 5: Audit Trail Test**
```dart
test('anonymization event is logged and verifiable', () async {
  // Setup
  final userId = 'test_user_123';
  
  // Act: Anonymize
  final result = await anonymizationService.anonymizeUserData(
    userId: userId,
    confirmationCode: await anonymizationService.generateConfirmationCode(userId),
  );
  
  // Assert: Anonymization event logged
  final auditEvents = await supabase.from('trash_events')
    .select()
    .eq('user_id', userId)
    .eq('action', 'permanent_delete')
    .get();
  
  final anonymizationEvent = auditEvents.firstWhere(
    (e) => e['metadata']['action'] == 'account_anonymized',
  );
  
  expect(anonymizationEvent, isNotNull);
  expect(anonymizationEvent['metadata']['gdpr_article_17'], isTrue);
  
  // Assert: Proof stored
  final proofs = await supabase.from('anonymization_proofs')
    .select()
    .eq('user_id', userId)
    .get();
  
  expect(proofs, hasLength(1));
  expect(proofs[0]['verification_report']['isFullyAnonymized'], isTrue);
  
  // Assert: Timestamp is accurate
  final proofTimestamp = DateTime.parse(proofs[0]['anonymization_timestamp']);
  final now = DateTime.now();
  expect(proofTimestamp.difference(now).inMinutes, lessThan(1));
});
```

### 5.2 Compliance Audit Checklist

**Pre-Production Checklist**:

- [ ] **Article 17 Compliance**
  - [ ] Anonymization satisfies erasure requirement
  - [ ] Exemptions documented (audit logs, legal holds)
  - [ ] User can request anonymization via UI
  - [ ] Confirmation code required (prevents accidental deletion)
  - [ ] Irreversibility warning displayed

- [ ] **Recital 26 Compliance**
  - [ ] Data is truly anonymous (not pseudonymized)
  - [ ] Re-identification is impossible with reasonable means
  - [ ] Keys are destroyed (not just hidden)
  - [ ] Encrypted blobs overwritten (not just deleted)

- [ ] **Article 20 Compliance (Data Portability)**
  - [ ] Export includes all user data
  - [ ] Export is machine-readable (JSON)
  - [ ] Export includes decrypted content
  - [ ] Export offered before anonymization

- [ ] **Technical Safeguards**
  - [ ] 3-pass key overwriting (DoD 5220.22-M)
  - [ ] Encrypted blob randomization (CSRNG)
  - [ ] Cross-device key revocation
  - [ ] Verification tests pass

- [ ] **Documentation**
  - [ ] Privacy policy updated
  - [ ] GDPR compliance statement
  - [ ] User guide for anonymization
  - [ ] Internal procedures documented

---

## 6. Risk Mitigation Strategies

### 6.1 Legal Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Incomplete Anonymization** | GDPR violation, fines up to €20M / 4% revenue | - Comprehensive verification suite<br>- Third-party privacy audit<br>- Regular compliance reviews |
| **Re-identification Possible** | GDPR violation, reputational damage | - True anonymization (key destruction + blob overwrite)<br>- Periodic re-assessment with new technology |
| **No Proof of Compliance** | Regulatory investigation, fines | - Immutable anonymization proofs<br>- Detailed audit logs<br>- Verification reports |
| **Retained PII After "Deletion"** | GDPR violation | - PII scanning automation<br>- Database schema audits<br>- Backup sanitization |

### 6.2 Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Key Restoration from Backups** | Data recovery → not truly anonymous | - Backup sanitization policy<br>- Encrypted backups with rotated keys<br>- Backup retention limits |
| **Encrypted Data Recovery** | Forensic recovery → re-identification | - Blob overwriting (random data)<br>- Multi-pass overwrite (DoD standard)<br>- SSD TRIM support verification |
| **Audit Log PII Leakage** | Audit logs contain PII → GDPR violation | - Audit log anonymization function<br>- Automated PII scanning<br>- Regular audit log reviews |
| **Cross-Device Sync After Anonymization** | Old devices sync deleted data back | - Key revocation broadcast<br>- Client-side revocation checks<br>- Sync validation (reject anonymized accounts) |

### 6.3 Operational Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Accidental Anonymization** | Data loss, user dissatisfaction | - Confirmation code (15-minute expiry)<br>- Re-authentication requirement<br>- Clear irreversibility warning |
| **No User Confirmation** | Unauthorized anonymization | - Multi-factor confirmation<br>- Email notification with cancellation link<br>- 24-hour cooling-off period (optional) |
| **Process Interruption/Failure** | Partial anonymization, inconsistent state | - Atomic transactions where possible<br>- Error handling with best-effort completion<br>- Manual cleanup procedures |
| **Data Corruption** | Database integrity issues | - Pre-anonymization verification<br>- Foreign key preservation<br>- Database backups before anonymization |

### 6.4 Backup Sanitization Policy

**Problem**: Encrypted backups contain keys and encrypted data → restore could de-anonymize

**Solution**: Backup Rotation with Key Destruction Awareness

```dart
/// Backup Sanitization Policy
/// 
/// Requirement: After anonymization, old backups MUST NOT be restorable
/// 
/// Strategy:
/// 1. Backups are encrypted with a backup-specific key (not user AMK)
/// 2. After anonymization, backup keys are also destroyed
/// 3. Backup retention: 30 days max (then auto-purge)
/// 4. Backup metadata includes user_id → anonymized users' backups are flagged
/// 5. Restore operations check anonymization status (reject if anonymized)

class BackupSanitizationPolicy {
  Future<void> sanitizeBackupsAfterAnonymization(String userId) async {
    // 1. Find all backups for user
    final backups = await _listBackups(userId);
    
    // 2. For each backup:
    for (final backup in backups) {
      // Option A: Delete backup entirely
      await _deleteBackup(backup.id);
      
      // Option B: Overwrite backup encryption key (make unrecoverable)
      // await _overwriteBackupKey(backup.id);
    }
    
    // 3. Mark user as "no backups" in metadata
    await _updateBackupMetadata(userId, allowBackups: false);
  }
}
```

**Recommendation**: Implement "backup-free anonymization" option:
- User chooses: "Export only" (no server-side backup retention)
- Server-side backups deleted immediately after anonymization
- User receives export file locally

---

## 7. Testing Strategy

### 7.1 Test Pyramid

```
                    ┌─────────────┐
                    │   E2E (10%) │  Manual testing, compliance validation
                    └─────────────┘
                  ┌───────────────────┐
                  │ Integration (30%) │  Full flow testing, DB verification
                  └───────────────────┘
              ┌─────────────────────────────┐
              │      Unit Tests (60%)       │  Key destruction, blob overwrite, logic
              └─────────────────────────────┘
```

### 7.2 Unit Tests (60% Coverage Target)

**File**: `test/services/anonymization_service_test.dart`

**Test Categories**:

1. **Key Destruction Tests**
   - `test('destroyEncryptionKeys removes local AMK')`
   - `test('destroyEncryptionKeys removes remote AMK')`
   - `test('destroyEncryptionKeys removes legacy device keys')`
   - `test('destroyEncryptionKeys overwrites keys before deletion')`
   - `test('destroyEncryptionKeys verification fails if keys remain')`

2. **Blob Overwriting Tests**
   - `test('overwriteEncryptedBlobs randomizes note blobs')`
   - `test('overwriteEncryptedBlobs randomizes task blobs')`
   - `test('overwriteEncryptedBlobs randomizes folder blobs')`
   - `test('overwriteEncryptedBlobs uses CSRNG for randomness')`
   - `test('overwriteEncryptedBlobs batch processing works')`

3. **Profile Anonymization Tests**
   - `test('anonymizeUserProfile anonymizes email')`
   - `test('anonymizeUserProfile anonymizes name')`
   - `test('anonymizeUserProfile clears profile photo')`
   - `test('anonymizeUserProfile preserves account record')`

4. **Audit Log Anonymization Tests**
   - `test('anonymizeAuditLogs removes item_title PII')`
   - `test('anonymizeAuditLogs preserves audit structure')`
   - `test('anonymizeAuditLogs inserts anonymization event')`

5. **Verification Tests**
   - `test('verifyAnonymization detects remaining keys')`
   - `test('verifyAnonymization detects un-overwritten blobs')`
   - `test('verifyAnonymization confirms decryption fails')`
   - `test('verifyAnonymization scans for PII')`

### 7.3 Integration Tests (30% Coverage Target)

**File**: `test/integration/anonymization_flow_test.dart`

**Test Scenarios**:

1. **Full Anonymization Flow**
```dart
test('complete anonymization workflow succeeds', () async {
  // Setup: Create user with full dataset
  final userId = await createTestUser();
  await seedUserData(userId, notes: 100, tasks: 50, folders: 5);
  
  // Act: Anonymize
  final code = await anonymizationService.generateConfirmationCode(userId);
  final result = await anonymizationService.anonymizeUserData(
    userId: userId,
    confirmationCode: code,
    createBackup: true,
  );
  
  // Assert: Success
  expect(result.success, isTrue);
  expect(result.verificationReport.isFullyAnonymized, isTrue);
  
  // Assert: Keys destroyed
  expect(await accountKeyService.getLocalAmk(), isNull);
  
  // Assert: Blobs overwritten
  final notes = await db.select(db.local EOFNotes).where((n) => n.userId.equals(userId)).get();
  expect(notes.every((n) => _isRandom(n.titleEncrypted!)), isTrue);
  
  // Assert: Profile anonymized
  final profile = await supabase.from('user_profiles').select().eq('user_id', userId).single();
  expect(profile['email'], startsWith('anonymized_'));
  
  // Assert: Backup created
  expect(result.backupFile, isNotNull);
  expect(await result.backupFile!.exists(), isTrue);
});
```

2. **Multi-Device Key Revocation**
```dart
test('key revocation propagates to all devices', () async {
  // Setup: Simulate 3 devices with same user
  final userId = 'test_user_123';
  final device1 = await createDeviceSession(userId);
  final device2 = await createDeviceSession(userId);
  final device3 = await createDeviceSession(userId);
  
  // Act: Anonymize on device1
  await anonymizationService.anonymizeUserData(
    userId: userId,
    confirmationCode: await anonymizationService.generateConfirmationCode(userId),
  );
  
  // Assert: Device2 detects revocation
  expect(
    () => device2.checkKeyRevocation(userId),
    throwsA(isA<KeyRevokedException>()),
  );
  
  // Assert: Device3 detects revocation
  expect(
    () => device3.checkKeyRevocation(userId),
    throwsA(isA<KeyRevokedException>()),
  );
  
  // Assert: Revocation event exists
  final revocations = await supabase.from('key_revocation_events')
    .select()
    .eq('user_id', userId)
    .get();
  
  expect(revocations, hasLength(1));
  expect(revocations[0]['reason'], equals('account_anonymized'));
});
```

3. **Backup + Anonymization**
```dart
test('backup contains all data before anonymization', () async {
  // Setup
  final userId = 'test_user_123';
  final secretNote = await createNote(userId, title: 'Secret', body: 'Confidential');
  
  // Act: Anonymize with backup
  final result = await anonymizationService.anonymizeUserData(
    userId: userId,
    confirmationCode: await anonymizationService.generateConfirmationCode(userId),
    createBackup: true,
  );
  
  // Assert: Backup contains decrypted data
  final backup = jsonDecode(await result.backupFile!.readAsString());
  final backupNote = backup['userData']['notes'].firstWhere((n) => n['id'] == secretNote.id);
  
  expect(backupNote['title'], equals('Secret'));
  expect(backupNote['body'], equals('Confidential'));
  
  // Assert: Database has anonymized data
  final dbNote = await db.getNote(secretNote.id);
  final decrypted = await cryptoBox.decryptStringForNote(
    userId: userId,
    noteId: dbNote.id,
    data: dbNote.titleEncrypted!,
  );
  
  // Decryption should fail (keys destroyed)
  expect(decrypted, isNot('Secret'));
});
```

### 7.4 E2E Tests (10% Coverage Target)

**File**: `test/e2e/anonymization_ui_test.dart`

**Test Scenarios**:

1. **User-Triggered Anonymization**
```dart
testWidgets('user can anonymize account via settings', (tester) async {
  // Setup: Login
  await loginAsTestUser(tester);
  
  // Navigate: Settings → Account → Delete Account
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete Account'));
  await tester.pumpAndSettle();
  
  // Assert: Warning dialog shown
  expect(find.text('This action is irreversible'), findsOneWidget);
  
  // Act: Confirm
  await tester.tap(find.text('Request Confirmation Code'));
  await tester.pumpAndSettle();
  
  // Assert: Confirmation code sent
  expect(find.text('Confirmation code sent to your email'), findsOneWidget);
  
  // Enter code (mock)
  final code = await getConfirmationCodeFromEmail();
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.text('Anonymize Account'));
  await tester.pumpAndSettle();
  
  // Assert: Progress shown
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  
  // Wait for completion
  await tester.pumpAndSettle(Duration(seconds: 10));
  
  // Assert: Success message
  expect(find.text('Account successfully anonymized'), findsOneWidget);
  
  // Assert: Logged out
  expect(find.text('Login'), findsOneWidget);
});
```

2. **Verification of Data Unrecoverability**
```dart
test('anonymized data cannot be recovered even with backup tools', () async {
  // This is a manual test procedure (not automated)
  // 
  // Procedure:
  // 1. Create test account with notes
  // 2. Anonymize account
  // 3. Use SQLite viewer to inspect database
  // 4. Verify encrypted blobs are random
  // 5. Attempt to use old keys (from pre-anonymization backup)
  // 6. Verify decryption fails
  // 
  // Expected: All encrypted data is unrecoverable
});
```

### 7.5 Compliance Test (Legal Team Review)

**Test Plan**: `docs/GDPR_COMPLIANCE_TEST_PLAN.md`

**Compliance Validation Checklist**:

1. **Article 17 - Right to Erasure**
   - [ ] User can request erasure via UI
   - [ ] Erasure request requires confirmation
   - [ ] User is warned about irreversibility
   - [ ] Erasure completes within 30 days (GDPR requirement)
   - [ ] Proof of erasure is generated

2. **Article 20 - Right to Data Portability**
   - [ ] User receives complete export before anonymization
   - [ ] Export is machine-readable (JSON)
   - [ ] Export includes all personal data
   - [ ] Export is downloadable/saveable

3. **Recital 26 - True Anonymization**
   - [ ] Data subject cannot be re-identified
   - [ ] Process is irreversible
   - [ ] No additional information exists to re-identify
   - [ ] Third parties cannot re-identify (audit log titles anonymized)

4. **ISO 29100 - Privacy Framework**
   - [ ] Encryption keys are destroyed
   - [ ] PII is removed or anonymized
   - [ ] Audit trail preserves compliance evidence

**Legal Review Required**:
- Privacy policy update (describe anonymization process)
- Terms of service update (user responsibilities)
- GDPR compliance statement (Article 17 satisfaction)

---

## 8. Implementation Roadmap

### 8.1 Week 1: Foundation & Infrastructure

**Goal**: Build core anonymization infrastructure

**Tasks**:
1. **Database Schema** (Day 1-2)
   - [ ] Create `key_revocation_events` table migration
   - [ ] Add `anonymized_at`, `anonymization_report` to `user_profiles`
   - [ ] Create `anonymization_proofs` table migration
   - [ ] Create `anonymize_user_audit_trail` function
   - [ ] Test migrations on staging

2. **Key Destruction** (Day 3-4)
   - [ ] Implement `KeyManager.securelyDestroyMasterKey()` (3-pass overwrite)
   - [ ] Implement `AccountKeyService.destroyRemoteAmk()`
   - [ ] Implement key revocation broadcast
   - [ ] Unit tests for key destruction
   - [ ] Verification tests (keys destroyed)

3. **Blob Overwriting** (Day 5)
   - [ ] Implement `_overwriteNoteEncryptedBlobs()`
   - [ ] Implement `_overwriteTaskEncryptedBlobs()`
   - [ ] Implement `_overwriteFolderEncryptedBlobs()`
   - [ ] Extend existing reminder blob overwriting
   - [ ] Unit tests for blob overwriting

**Deliverables**:
- Database migrations (production-ready)
- Key destruction utilities (tested)
- Blob overwriting utilities (tested)
- Unit test coverage: 60%

### 8.2 Week 2: Core Anonymization Service

**Goal**: Implement `AnonymizationService` with full workflow

**Tasks**:
1. **Service Skeleton** (Day 1)
   - [ ] Create `AnonymizationService` class
   - [ ] Define API surface
   - [ ] Implement confirmation code generation
   - [ ] Implement progress tracking
   - [ ] Error handling framework

2. **Phase Implementation** (Day 2-4)
   - [ ] Phase 1: Verification
   - [ ] Phase 2: Backup & Export
   - [ ] Phase 3: Blob Overwriting
   - [ ] Phase 4: Key Destruction
   - [ ] Phase 5: Profile Anonymization
   - [ ] Phase 6: Audit Log Anonymization
   - [ ] Phase 7: Verification

3. **Integration** (Day 5)
   - [ ] Integrate with `GDPRComplianceService`
   - [ ] Integrate with existing deletion flow
   - [ ] Add to dependency injection
   - [ ] Integration tests

**Deliverables**:
- `AnonymizationService` (production-ready)
- Integration tests: 30%
- Error handling and rollback logic

### 8.3 Week 3: UI/UX & Safety Features

**Goal**: Build user-facing anonymization flow

**Tasks**:
1. **Confirmation Flow UI** (Day 1-2)
   - [ ] Settings → Account → Delete Account screen
   - [ ] Irreversibility warning dialog
   - [ ] Confirmation code request UI
   - [ ] Code entry and verification UI
   - [ ] Export option checkbox

2. **Progress Tracking UI** (Day 3)
   - [ ] Progress bar with phase indicators
   - [ ] Phase-specific messages
   - [ ] Cancellation logic (pre-key-destruction only)
   - [ ] Error display

3. **Verification & Completion** (Day 4)
   - [ ] Verification results screen
   - [ ] Download backup button
   - [ ] Anonymization proof display
   - [ ] Logout and redirect

4. **Safety Features** (Day 5)
   - [ ] Email notification (confirmation code)
   - [ ] 24-hour cooling-off period (optional)
   - [ ] Re-authentication before anonymization
   - [ ] Device verification

**Deliverables**:
- Complete UI flow (Settings to completion)
- E2E tests: 10%
- User documentation

### 8.4 Week 4: Testing, Documentation & Compliance

**Goal**: Production readiness and compliance validation

**Tasks**:
1. **Comprehensive Testing** (Day 1-2)
   - [ ] Run full test suite (unit + integration + E2E)
   - [ ] Fix failing tests
   - [ ] Manual testing on iOS
   - [ ] Manual testing on Android
   - [ ] Edge case testing

2. **Compliance Validation** (Day 3)
   - [ ] Legal team review
   - [ ] Privacy policy update
   - [ ] GDPR compliance statement
   - [ ] Third-party privacy audit (if required)

3. **Documentation** (Day 4)
   - [ ] User guide: "How to Delete Your Account"
   - [ ] Developer documentation: `AnonymizationService` API
   - [ ] Compliance documentation: GDPR Article 17 satisfaction
   - [ ] Internal procedures: Manual anonymization (if needed)

4. **Production Deployment** (Day 5)
   - [ ] Deploy database migrations to production
   - [ ] Deploy app update (with anonymization feature)
   - [ ] Monitor error logs
   - [ ] Set up compliance alerts

**Deliverables**:
- Production-ready anonymization feature
- Complete test coverage (60% unit, 30% integration, 10% E2E)
- Legal compliance documentation
- User-facing documentation

---

## 9. Success Criteria & Acceptance Tests

### 9.1 Legal Compliance Criteria

**GDPR Article 17 Compliance**:
- ✅ User can request erasure via UI
- ✅ Erasure is completed within reasonable time (< 30 days)
- ✅ Proof of erasure is generated and stored
- ✅ User receives data export before erasure (Article 20)

**GDPR Recital 26 Compliance**:
- ✅ Anonymization is irreversible
- ✅ Data subject cannot be re-identified by controller
- ✅ Data subject cannot be re-identified by third parties
- ✅ No additional information exists for re-identification

**ISO 29100 Compliance**:
- ✅ PII is removed or anonymized
- ✅ Encryption keys are destroyed
- ✅ Privacy by design implemented

### 9.2 Technical Acceptance Criteria

**Key Destruction**:
- ✅ Local AMK destroyed (3-pass overwrite)
- ✅ Remote AMK destroyed (overwrite + delete)
- ✅ Legacy device keys destroyed (3-pass overwrite)
- ✅ Key revocation broadcast to all devices
- ✅ Verification confirms keys are gone

**Blob Overwriting**:
- ✅ Notes: title, body, metadata encrypted blobs overwritten
- ✅ Tasks: content encrypted blobs overwritten
- ✅ Folders: name, props encrypted blobs overwritten
- ✅ Reminders: title, body, location encrypted blobs overwritten
- ✅ Random data used (CSRNG, high entropy)

**Profile Anonymization**:
- ✅ Email replaced with `anonymized_{hash}@deleted.local`
- ✅ Name replaced with "Anonymized User"
- ✅ Profile photo deleted
- ✅ Account record preserved (FK integrity)

**Audit Log Anonymization**:
- ✅ `trash_events.item_title` → "ANONYMIZED"
- ✅ Anonymization event logged
- ✅ Audit structure preserved

**Verification**:
- ✅ Decryption fails (keys destroyed)
- ✅ No PII detected in database
- ✅ Verification report generated
- ✅ Anonymization proof stored

### 9.3 User Experience Criteria

**Ease of Use**:
- ✅ Anonymization request is 3 clicks from Settings
- ✅ Confirmation code is easy to understand
- ✅ Progress is visible and clear
- ✅ Backup download is intuitive

**Safety**:
- ✅ User is warned about irreversibility
- ✅ Confirmation code prevents accidental deletion
- ✅ Re-authentication required
- ✅ Export offered before anonymization

**Transparency**:
- ✅ User knows what will happen
- ✅ User receives verification report
- ✅ User can download proof of anonymization

---

## 10. Future Enhancements

### 10.1 Scheduled Anonymization

**Feature**: Allow users to schedule anonymization for a future date

**Use Case**: User wants to delete account but needs time to export data

**Implementation**:
```dart
Future<void> scheduleAnonymization({
  required String userId,
  required DateTime scheduledDate,
}) async {
  await supabase.from('scheduled_anonymizations').insert({
    'user_id': userId,
    'scheduled_for': scheduledDate.toIso8601String(),
  });
  
  // Cron job or Cloud Function checks daily and executes scheduled anonymizations
}
```

### 10.2 Partial Anonymization

**Feature**: Allow users to anonymize specific data types (e.g., "delete all notes but keep folders")

**Use Case**: User wants to selectively erase sensitive data

**Legal Consideration**: Must still satisfy Article 17 for requested data types

### 10.3 Anonymization Analytics

**Feature**: Track anonymization metrics (for product improvement)

**Metrics**:
- Number of anonymization requests per month
- Time to complete anonymization
- Failure rate by phase
- User reasons for anonymization (optional survey)

**Privacy**: Metrics must be anonymized (no PII)

### 10.4 Third-Party Data Deletion

**Feature**: Automatically request deletion from third-party services (if any integrations exist)

**Examples**:
- Cloud storage providers (if attachments stored externally)
- Analytics services (if user data sent)
- Email service providers (if emails stored)

**Implementation**: Add `ThirdPartyDeletionService` with provider-specific APIs

---

## 11. Appendices

### Appendix A: Legal References

**GDPR**:
- **Article 17**: Right to Erasure ('Right to be Forgotten')
  - https://gdpr-info.eu/art-17-gdpr/
- **Recital 26**: Not Applicable to Anonymous Data
  - https://gdpr-info.eu/recitals/no-26/
- **Article 20**: Right to Data Portability
  - https://gdpr-info.eu/art-20-gdpr/

**ISO Standards**:
- **ISO 29100:2024**: Information Technology - Security Techniques - Privacy Framework
- **ISO 27001:2022**: Information Security Management (Control 8.3.2 - Data Disposal)

**Case Law**:
- Austrian DPA: DSB-D123.270/0009-DSB/2018 (Anonymization satisfies Article 17)

### Appendix B: Glossary

- **AMK (Account Master Key)**: Server-bound encryption key wrapped with user passphrase
- **Anonymization**: Irreversible process of rendering data non-identifiable
- **Pseudonymization**: Reversible replacement of identifiers (still personal data under GDPR)
- **CSRNG**: Cryptographically Secure Random Number Generator
- **DoD 5220.22-M**: US Department of Defense data sanitization standard (3-pass overwrite)
- **FK (Foreign Key)**: Database relationship constraint
- **PII (Personally Identifiable Information)**: Data that identifies a natural person
- **RLS (Row Level Security)**: Database security policy restricting row access

### Appendix C: File Locations

**Core Services**:
- `/lib/services/anonymization_service.dart` (NEW)
- `/lib/services/gdpr_compliance_service.dart` (EXISTING)
- `/lib/services/account_key_service.dart` (EXISTING)
- `/lib/core/crypto/key_manager.dart` (EXISTING)

**Database Migrations**:
- `/supabase/migrations/20250320000000_add_anonymization_support.sql` (NEW)

**Tests**:
- `/test/services/anonymization_service_test.dart` (NEW)
- `/test/integration/anonymization_flow_test.dart` (NEW)
- `/test/e2e/anonymization_ui_test.dart` (NEW)

**UI**:
- `/lib/ui/screens/settings/account_deletion_screen.dart` (NEW)
- `/lib/ui/screens/settings/anonymization_progress_screen.dart` (NEW)

### Appendix D: Performance Estimates

**Anonymization Time** (based on data size):

| Data Size | Estimated Time | Bottleneck |
|-----------|----------------|------------|
| 100 notes, 50 tasks | 5-10 seconds | Blob overwriting |
| 1,000 notes, 500 tasks | 30-60 seconds | Blob overwriting (batched) |
| 10,000 notes, 5,000 tasks | 3-5 minutes | Blob overwriting (batched) |

**Optimization**:
- Batch blob overwrites (1000 rows per transaction)
- Parallel processing (local + remote operations)
- Background job for large datasets (with progress tracking)

---

## Conclusion

This design provides a **production-grade, GDPR-compliant anonymization system** for Duru Notes that:

✅ **Satisfies GDPR Article 17** (Right to Erasure) through true anonymization
✅ **Meets GDPR Recital 26 standards** (irreversible, no re-identification possible)
✅ **Follows ISO 29100 best practices** (privacy by design, key destruction, PII removal)
✅ **Preserves system integrity** (FK relationships, audit logs)
✅ **Provides user transparency** (export before deletion, verification reports)
✅ **Enables compliance auditing** (immutable proofs, detailed logging)

**Next Steps**:
1. Legal team review and approval
2. Privacy policy update
3. Implementation (4-week roadmap)
4. Third-party privacy audit (optional)
5. Production deployment

**Prepared By**: Claude Code
**Date**: 2025-11-19
**Status**: Ready for Implementation

---

**Document Version**: 1.0
**Last Updated**: 2025-11-19
**Approvals Required**: Legal Team, Product Team, Engineering Lead
