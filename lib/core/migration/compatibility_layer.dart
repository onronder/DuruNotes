import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;

/// DEPRECATED: This compatibility layer is no longer functional after encryption migration.
///
/// Post-encryption migration, all conversions between LocalNote and domain.Note
/// must go through the repository layer (NotesRepository) which properly handles
/// encryption/decryption with the encryption service.
///
/// This file should not be used in new code and will be removed after migration.
@Deprecated('Use NotesRepository methods instead')
abstract class CompatibilityLayer {
  /// Convert domain Note entity to infrastructure LocalNote
  static LocalNote domainToLocal(domain.Note note) {
    throw UnsupportedError(
      'CompatibilityLayer.domainToLocal is no longer supported after encryption migration. '
      'Use NotesRepository methods which properly handle encryption/decryption.',
    );
  }

  /// Convert infrastructure LocalNote to domain Note entity
  static domain.Note localToDomain(LocalNote note) {
    throw UnsupportedError(
      'CompatibilityLayer.localToDomain is no longer supported after encryption migration. '
      'Use NotesRepository methods which properly handle encryption/decryption.',
    );
  }

  /// Convert list of domain Notes to LocalNotes
  static List<LocalNote> domainListToLocal(List<domain.Note> notes) {
    throw UnsupportedError(
      'CompatibilityLayer.domainListToLocal is no longer supported after encryption migration. '
      'Use NotesRepository methods which properly handle encryption/decryption.',
    );
  }

  /// Convert list of LocalNotes to domain Notes
  static List<domain.Note> localListToDomain(List<LocalNote> notes) {
    throw UnsupportedError(
      'CompatibilityLayer.localListToDomain is no longer supported after encryption migration. '
      'Use NotesRepository methods which properly handle encryption/decryption.',
    );
  }
}
