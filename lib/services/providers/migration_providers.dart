// ============================================================================
// DEPRECATED: This migration provider file is now obsolete
// ============================================================================
//
// Encryption migration is now handled automatically via database schema
// during app bootstrap. All data is encrypted by default for new users,
// and existing data is migrated seamlessly when the app detects plaintext.
//
// The DataEncryptionMigrationService and DataMigrationDialog are kept
// for reference but are no longer actively used in the app flow.
//
// Related files (preserved for reference):
// - lib/services/data_encryption_migration_service.dart
// - lib/ui/dialogs/data_migration_dialog.dart
//
// Migration is now handled by:
// - Database schema (encryption_status column)
// - AppBootstrap encryption initialization
// - Automatic detection and migration on first launch
// ============================================================================

// Providers removed - migration is now automatic
// If manual migration is ever needed, use:
// - Direct database operations with CryptoBox
// - Schema-based encryption flags
// - Bootstrap-time migration checks
