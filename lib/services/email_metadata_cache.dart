/// Temporary cache for email metadata until it can be synced
/// This is a workaround since LocalNote doesn't have a metadata field
class EmailMetadataCache {
  static final Map<String, Map<String, dynamic>> _cache = {};
  
  /// Store metadata for a note
  static void set(String noteId, Map<String, dynamic> metadata) {
    _cache[noteId] = metadata;
  }
  
  /// Retrieve metadata for a note
  static Map<String, dynamic>? get(String noteId) {
    return _cache[noteId];
  }
  
  /// Remove metadata after sync
  static void remove(String noteId) {
    _cache.remove(noteId);
  }
  
  /// Clear all cached metadata
  static void clear() {
    _cache.clear();
  }
}
