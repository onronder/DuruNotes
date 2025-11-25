# Secure Encrypted Sharing Implementation Plan

**Scope**: Implement password-protected, end-to-end encrypted share links for notes (and optionally attachments), using Supabase as storage and Duru Notes as the client, aligned with the existing architecture and feature flags.

**Out of Scope**: Monetization gating beyond basic hooks (paywall & feature flags wiring), AI/handwriting, voice recording/STT specifics.

---

## 1. Data Model & Backend (Supabase)

### 1.1 Shared Links Table

- **File**: `supabase/migrations/YYYYMMDD_add_secure_sharing.sql` (NEW)
  - [ ] Create `shared_links` table with fields:
    - `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`
    - `note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE`
    - `user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`
    - `encrypted_storage_path TEXT NOT NULL`
    - `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`
    - `expires_at TIMESTAMPTZ`
    - `max_views INTEGER`
    - `view_count INTEGER NOT NULL DEFAULT 0`
    - `revoked BOOLEAN NOT NULL DEFAULT FALSE`
  - [ ] Add indexes:
    - `idx_shared_links_user` on `(user_id, created_at DESC)`
    - `idx_shared_links_note` on `(note_id)`

- **File**: `supabase/migrations/YYYYMMDD_add_secure_sharing_policies.sql` (NEW)
  - [ ] RLS policies:
    - Owner can create/select/update/revoke own links.
    - Public access to encrypted blobs via a separate endpoint (no direct row read).

### 1.2 Storage Bucket for Encrypted Payloads

- **File**: `supabase/migrations/YYYYMMDD_create_secure_share_bucket.sql` (NEW)
  - [ ] Create `secure_shares` bucket (if not already present).
  - [ ] Restrict direct listing; access via generated signed URLs or backend API.

---

## 2. Client-Side Crypto & Key Handling

### 2.1 Key Derivation & Encryption

- **File**: `lib/core/crypto/secure_sharing_crypto.dart` (NEW)
  - [ ] Implement:
    - `deriveKeyFromPassword(String password, {String salt})` using PBKDF2 (or Argon2 if available).
    - `encryptPayload(Uint8List plaintext, SecretKey key)` → `EncryptedPayload { cipherText, nonce, mac, algoVersion }`.
    - `decryptPayload(EncryptedPayload payload, SecretKey key)` → `Uint8List`.
  - [ ] Use existing crypto primitives where possible (e.g., from `CryptoBox` or other core crypto util).

- **File**: `lib/core/crypto/secure_sharing_payload.dart` (NEW)
  - [ ] Define data model for serialized encrypted payload:
    - Versioned JSON with:
      - `noteId`, `title`, `body`, essential metadata.
      - (Optional) references to attachments, if included.
      - `cipherText`, `nonce`, `mac`, `kdfParams`.

### 2.2 Key Handling Strategy

- **File**: `lib/services/secure_sharing_service.dart` (NEW)
  - [ ] Implement:
    - `Future<SharedLink> createSecureShare({required Note note, required String password, DateTime? expiresAt, int? maxViews})`
      - Serialize note content into a minimal JSON payload.
      - Derive key from password.
      - Encrypt payload.
      - Upload encrypted blob to `secure_shares` bucket.
      - Create `shared_links` row with storage path + metadata.
      - Return a `SharedLink` model with a URL containing link ID.
    - `Future<void> revokeShare(String linkId)` – mark `revoked = true`.
  - [ ] Do **not** store raw password or derived key; only keep KDF parameters and storage path.

---

## 3. Public Link Consumption Flow

### 3.1 Link Format & Routing

- **File**: `lib/routes/app_router.dart` or routing config
  - [ ] Reserve a route pattern for secure links, e.g.:
    - `duru-notes://secure-share/<linkId>`
    - Web: `/share/<linkId>`

- **File**: `lib/ui/secure_share_view_screen.dart` (NEW)
  - [ ] UI for opening a secure share:
    - Prompts user for password.
    - Calls backend to fetch encrypted payload (via signed URL or direct storage link).
    - Derives key, decrypts payload, renders read-only note.
    - Handles errors:
      - Wrong password.
      - Expired link.
      - Revoked link.
      - Max views exceeded.

### 3.2 Backend Access Patterns (Optional API)

- **File**: `docs/SECURE_SHARING_BACKEND_API.md` (NEW)
  - [ ] Specify whether the client:
    - A: Directly reads blob from Supabase Storage via signed URLs, or
    - B: Calls an API endpoint which applies business rules (expiry, revocation, view counting).
  - [ ] If B:
    - Document the endpoint(s) (language/implementation TBD, outside this repo).

---

## 4. App UI Integration

### 4.1 Share Flow in Note Detail

- **File**: `lib/ui/modern_edit_note_screen.dart` or dedicated note detail screen
  - [ ] Add a “Secure Share” entry to the note actions menu.
  - [ ] When tapped:
    - Show dialog to:
      - Set password.
      - Optional expiry date.
      - Optional max views.
    - Call `SecureSharingService.createSecureShare`.
    - Show resulting share URL with a copy button.

### 4.2 Manage Existing Shares

- **File**: `lib/ui/settings/secure_shares_management_screen.dart` (NEW)
  - [ ] List user’s secure links (`shared_links` for current user):
    - Note title preview.
    - Created date, expiry, view count.
    - Status (active/expired/revoked).
  - [ ] Allow:
    - Revoking a link.
    - Copying a link to clipboard.

---

## 5. Feature Flag & Monetization Hooks

- **File**: `lib/core/feature_flags.dart`
  - [ ] Confirm `sharePro` flag exists.

- **File**: `lib/services/subscription_service.dart`
  - [ ] Confirm `hasFeatureAccess(FeatureFlags.sharePro)` support.

- **File**: `lib/ui/modern_edit_note_screen.dart`
  - [ ] Wrap “Secure Share” entry with:
    - For now, always allow for internal testing.
    - Add TODO markers where gating will be applied (check `sharePro` and show paywall prompt if disabled).

---

## 6. Testing & QA

### 6.1 Unit Tests

- **File**: `test/core/secure_sharing_crypto_test.dart` (NEW)
  - [ ] Verify:
    - Key derivation.
    - Encrypt/decrypt round-trips.
    - Handling of corrupt ciphertext.

- **File**: `test/services/secure_sharing_service_test.dart` (NEW)
  - [ ] Mock Supabase client:
    - Ensure createSecureShare:
      - Uploads encrypted blob.
      - Creates shared_links row with correct metadata.

### 6.2 Integration / Manual QA

- **Checklist**:
  - Create secure share, open link, enter correct password → note displays correctly.
  - Wrong password → error, no content leakage.
  - Expired link → error message.
  - Revoked link → error message.
  - Max views exceeded → error message.

---

## 7. Completion Criteria (Secure Sharing READY)

- [ ] Encrypted share links can be created and opened end-to-end.
- [ ] Passwords / keys never stored server-side.
- [ ] Expiry, revocation, and max views behave as expected.
- [ ] Errors are user-friendly (no raw stack traces).
- [ ] Core crypto and service tests are passing.

