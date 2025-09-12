import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/search/search_parser.dart';

/// Unified search service that combines FTS, folder, and tag filtering in one SQL pass
class UnifiedSearchService {
  final AppDb db;

  UnifiedSearchService({required this.db});

  /// Execute a unified search query using a single SQL pass
  Future<List<LocalNote>> search(SearchQuery query, {
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    // Build variables list for parameterized query
    final vars = <Variable>[];
    
    // Normalize tags to lowercase for case-insensitive matching
    final anyTags = query.includeTags.map((t) => t.trim().toLowerCase()).toList();
    final noneTags = query.excludeTags.map((t) => t.trim().toLowerCase()).toList();
    
    // Build FTS expression if keywords present
    String? ftsExpr;
    if (query.keywords.isNotEmpty) {
      ftsExpr = _buildFtsMatch(query.keywords);
      vars.add(Variable<String>(ftsExpr));
    }
    
    // Get folder ID if folder name is specified
    String? folderId;
    if (query.folderName != null) {
      final folder = await _findFolderByName(query.folderName!);
      if (folder == null) {
        // Folder not found - return empty result
        return [];
      }
      folderId = folder.id;
      vars.add(Variable<String>(folderId));
    }
    
    // Build dynamic placeholders for tag lists
    final anyPlaceholders = List.generate(anyTags.length, (_) => '?').join(', ');
    final nonePlaceholders = List.generate(noneTags.length, (_) => '?').join(', ');
    
    // Add tag variables
    for (final tag in anyTags) {
      vars.add(Variable<String>(tag));
    }
    for (final tag in noneTags) {
      vars.add(Variable<String>(tag));
    }
    
    // Build the unified SQL query
    final sql = _buildUnifiedSql(
      hasFts: ftsExpr != null,
      hasFolderId: folderId != null,
      anyTagsPlaceholders: anyPlaceholders,
      noneTagsPlaceholders: nonePlaceholders,
      hasAnyTags: anyTags.isNotEmpty,
      hasNoneTags: noneTags.isNotEmpty,
      isPinnedFilter: query.isPinned,
      hasAttachment: query.hasAttachment,
      fromEmail: query.fromEmail,
      fromWeb: query.fromWeb,
      sort: sort,
      limit: limit,
    );
    
    // Execute the unified query
    final rows = await db.customSelect(
      sql, 
      variables: vars,
      readsFrom: {
        db.localNotes,
        if (folderId != null) db.noteFolders,
        if (anyTags.isNotEmpty || noneTags.isNotEmpty) db.noteTags,
      },
    ).get();
    
    // Map rows to LocalNote objects
    return rows.map((row) {
      // Map the row data to a LocalNote
      return LocalNote(
        id: row.read<String>('id'),
        title: row.read<String>('title'),
        body: row.read<String>('body'),
        encryptedMetadata: row.readNullable<String>('encrypted_metadata'),
        updatedAt: row.read<DateTime>('updated_at'),
        deleted: row.read<bool>('deleted'),
        isPinned: row.read<bool>('is_pinned'),
      );
    }).toList();
  }
  
  /// Build the unified SQL query string
  String _buildUnifiedSql({
    required bool hasFts,
    required bool hasFolderId,
    required String anyTagsPlaceholders,
    required String noneTagsPlaceholders,
    required bool hasAnyTags,
    required bool hasNoneTags,
    required bool isPinnedFilter,
    required bool hasAttachment,
    required bool fromEmail,
    required bool fromWeb,
    required SortSpec sort,
    int? limit,
  }) {
    final buffer = StringBuffer();
    
    // SELECT clause
    buffer.writeln('SELECT DISTINCT n.*');
    buffer.writeln('FROM local_notes n');
    
    // JOIN clauses
    if (hasFts) {
      buffer.writeln('JOIN fts_notes f ON f.id = n.id');
    }
    if (hasFolderId) {
      buffer.writeln('JOIN note_folders nf ON nf.note_id = n.id');
    }
    
    // WHERE clause
    buffer.writeln('WHERE n.deleted = 0');
    
    // FTS match condition
    if (hasFts) {
      buffer.writeln('  AND f MATCH ?');
    }
    
    // Folder filter
    if (hasFolderId) {
      buffer.writeln('  AND nf.folder_id = ?');
    }
    
    // Tag filters using EXISTS/NOT EXISTS subqueries
    if (hasAnyTags) {
      buffer.writeln('  AND EXISTS (');
      buffer.writeln('    SELECT 1 FROM note_tags nt');
      buffer.writeln('    WHERE nt.note_id = n.id');
      buffer.writeln('      AND nt.tag IN ($anyTagsPlaceholders)');
      buffer.writeln('  )');
    }
    
    if (hasNoneTags) {
      buffer.writeln('  AND NOT EXISTS (');
      buffer.writeln('    SELECT 1 FROM note_tags nt2');
      buffer.writeln('    WHERE nt2.note_id = n.id');
      buffer.writeln('      AND nt2.tag IN ($noneTagsPlaceholders)');
      buffer.writeln('  )');
    }
    
    // Additional filters
    if (isPinnedFilter) {
      buffer.writeln('  AND n.is_pinned = 1');
    }
    
    // Metadata filters (using JSON extraction if metadata is stored as JSON)
    if (hasAttachment) {
      buffer.writeln('  AND n.encrypted_metadata IS NOT NULL');
      buffer.writeln(r"  AND json_extract(n.encrypted_metadata, '$.has_attachments') = true");
    }
    
    if (fromEmail) {
      buffer.writeln('  AND n.encrypted_metadata IS NOT NULL');
      buffer.writeln(r"  AND json_extract(n.encrypted_metadata, '$.source') = 'email'");
    }
    
    if (fromWeb) {
      buffer.writeln('  AND n.encrypted_metadata IS NOT NULL');
      buffer.writeln(r"  AND json_extract(n.encrypted_metadata, '$.source') = 'web'");
    }
    
    // ORDER BY clause
    buffer.writeln('ORDER BY');
    
    // Pinned first if enabled
    if (sort.pinnedFirst && !isPinnedFilter) {
      buffer.writeln('  n.is_pinned DESC,');
    }
    
    // Sort field
    buffer.write('  ');
    buffer.writeln(_getSqlSort(sort));
    
    // LIMIT clause
    if (limit != null) {
      buffer.writeln('LIMIT $limit');
    }
    
    return buffer.toString();
  }
  
  /// Build FTS match expression from keywords
  String _buildFtsMatch(String keywords) {
    // Split keywords and add wildcard suffix for prefix matching
    final terms = keywords
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => _escapeFtsToken(t))
        .map((t) => '$t*')  // Add wildcard for prefix matching
        .toList();
    
    // Join with AND operator for all terms must match
    return terms.join(' ');
  }
  
  /// Escape special FTS characters
  String _escapeFtsToken(String token) {
    // Escape special FTS5 characters
    return token
        .replaceAll('"', '""')
        .replaceAll("'", "''");
  }
  
  /// Get SQL sort expression
  String _getSqlSort(SortSpec sort) {
    final dir = sort.ascending ? 'ASC' : 'DESC';
    
    switch (sort.sortBy) {
      case SortBy.updatedAt:
        return 'n.updated_at $dir';
      case SortBy.createdAt:
        // Since we don't have created_at, use updated_at as proxy
        return 'n.updated_at $dir';
      case SortBy.title:
        return 'LOWER(n.title) $dir';
      default:
        return 'n.updated_at $dir';
    }
  }
  
  /// Find folder by name or path
  Future<LocalFolder?> _findFolderByName(String name) async {
    // Try exact name match first
    var folder = await (db.select(db.localFolders)
          ..where((f) => f.deleted.equals(false))
          ..where((f) => f.name.equals(name)))
        .getSingleOrNull();
    
    if (folder != null) return folder;
    
    // Try path match
    final path = name.startsWith('/') ? name : '/$name';
    return await (db.select(db.localFolders)
          ..where((f) => f.deleted.equals(false))
          ..where((f) => f.path.equals(path)))
        .getSingleOrNull();
  }
  
  /// Execute a search query string (convenience method)
  Future<List<LocalNote>> searchString(String query, {
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    final searchQuery = SearchParser.parse(query);
    return search(searchQuery, sort: sort, limit: limit);
  }
  
  /// Search notes by tags only (optimized for tag-only searches)
  Future<List<LocalNote>> searchByTags({
    List<String> anyTags = const [],
    List<String> noneTags = const [],
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    if (anyTags.isEmpty && noneTags.isEmpty) {
      // No tags specified - return all notes
      return await _getAllNotes(sort: sort, limit: limit);
    }
    
    // Use unified search with tag filters only
    final query = SearchQuery(
      includeTags: anyTags,
      excludeTags: noneTags,
    );
    
    return search(query, sort: sort, limit: limit);
  }
  
  /// Get all notes (no filters)
  Future<List<LocalNote>> _getAllNotes({
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    final query = db.select(db.localNotes)
      ..where((n) => n.deleted.equals(false));
    
    // Apply sorting
    if (sort.pinnedFirst) {
      query.orderBy([
        (n) => OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc),
      ]);
    }
    
    switch (sort.sortBy) {
      case SortBy.title:
        query.orderBy([
          (n) => OrderingTerm(
            expression: n.title.lower(),
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
        break;
      case SortBy.createdAt:
      case SortBy.updatedAt:
      default:
        query.orderBy([
          (n) => OrderingTerm(
            expression: n.updatedAt,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
        break;
    }
    
    if (limit != null) {
      query.limit(limit);
    }
    
    return await query.get();
  }
}
