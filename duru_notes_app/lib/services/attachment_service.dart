import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes_app/models/note_block.dart';

/// A service responsible for handling file attachments. It provides a
/// convenience method to pick a file from the device, compute a
/// content-based hash, upload it to a Supabase Storage bucket and return
/// an [AttachmentBlockData] with the user friendly filename and the
/// public URL. The service will avoid re-uploading duplicate files by
/// naming objects based on the SHA‑256 hash of their content. Encryption
/// of attachments is beyond the scope of this service and can be added
/// separately if desired.
class AttachmentService {
  AttachmentService(this.client, {this.bucket = 'attachments'});

  /// The Supabase client used to access the Storage API.
  final SupabaseClient client;

  /// The name of the Supabase Storage bucket where attachments are stored.
  final String bucket;

  /// Opens a file picker so the user can choose a file, then uploads the
  /// selected file to Supabase Storage if it does not already exist. The
  /// returned [AttachmentBlockData] contains the original filename and
  /// the public URL of the uploaded object. If the user cancels the
  /// picker or an error occurs, this method returns `null`.
  Future<AttachmentBlockData?> pickAndUpload() async {
    // Allow the user to pick a single file. Use withData to get the bytes
    // directly so that we can compute a hash without reading from disk.
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      return null;
    }
    // Compute a SHA‑256 digest of the file contents to use as a unique key.
    final digest = crypto.sha256.convert(bytes);
    final hash = digest.toString();
    // Preserve the original file extension so that the storage object
    // retains a recognizable type. If no extension, leave it empty.
    final ext = p.extension(file.name);
    final objectPath = ext.isNotEmpty ? '$hash$ext' : hash;
    // Attempt to upload the file. Use upsert: false to avoid overwriting
    // existing files with the same hash. If the file already exists, the
    // storage API will throw an error which we catch and ignore.
    try {
      await client.storage
          .from(bucket)
          .uploadBinary(objectPath, bytes, fileOptions: const FileOptions(upsert: false));
    } catch (e) {
      // Ignore "already exists" errors. Other errors should be rethrown.
      final msg = e.toString();
      if (!msg.contains('already exists')) {
        rethrow;
      }
    }
    // Generate a public URL for the uploaded file. If your bucket is not
    // public, you may need to create a signed URL instead.
    final urlResponse = client.storage.from(bucket).getPublicUrl(objectPath);
    final publicUrl = urlResponse;
    return AttachmentBlockData(filename: file.name, url: publicUrl);
  }
}