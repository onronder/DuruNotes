import 'package:drift/drift.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/search/search_parser.dart';
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/infrastructure/helpers/note_decryption_helper.dart';

/// Unified search service that combines FTS, folder, and tag filtering
///
/// ENCRYPTION-AWARE SEARCH:
/// Since notes are now encrypted with XChaCha20-Poly1305, traditional SQL-based FTS5
/// cannot index encrypted content. This service uses a hybrid approach:
/// 1. Use SQL for structural filters (tags, folders, pinned, metadata)
/// 2. Decrypt candidate notes in memory
/// 3. Apply text search on decrypted content
///
/// Performance: Optimized to minimize decryption overhead by filtering first
class UnifiedSearchService {
  UnifiedSearchService({required this.db, required CryptoBox crypto})
    : _decryptHelper = NoteDecryptionHelper(crypto);

  final AppDb db;
  final NoteDecryptionHelper _decryptHelper;

  Future<List<LocalNote>> _applySort(
    List<LocalNote> notes,
    SortSpec sort, {
    Map<String, String>? decryptedTitles,
  }) async {
    if (notes.length <= 1 || sort.sortBy != SortBy.title) {
      return List<LocalNote>.from(notes);
    }

    final titles = <String, String>{};
    if (decryptedTitles != null) {
      titles.addAll(decryptedTitles);
    }

    for (final note in notes) {
      if (!titles.containsKey(note.id)) {
        titles[note.id] = await _decryptHelper.decryptTitle(note);
      }
    }

    int compare(LocalNote a, LocalNote b) {
      final titleA = titles[a.id]?.toLowerCase() ?? '';
      final titleB = titles[b.id]?.toLowerCase() ?? '';
      final primary = titleA.compareTo(titleB);
      if (primary != 0) {
        return sort.ascending ? primary : -primary;
      }
      final secondary = a.updatedAt.compareTo(b.updatedAt);
      return sort.ascending ? secondary : -secondary;
    }

    final sorted = List<LocalNote>.from(notes)..sort(compare);

    if (!sort.pinnedFirst) {
      return sorted;
    }

    final pinned = <LocalNote>[];
    final others = <LocalNote>[];
    for (final note in sorted) {
      if (note.isPinned) {
        pinned.add(note);
      } else {
        others.add(note);
      }
    }
    return [...pinned, ...others];
  }

  Future<List<LocalNote>> _sortedAndLimited(
    List<LocalNote> notes,
    SortSpec sort,
    int? limit, {
    Map<String, String>? decryptedTitles,
  }) async {
    final sorted = await _applySort(
      notes,
      sort,
      decryptedTitles: decryptedTitles,
    );
    if (limit != null && sorted.length > limit) {
      return sorted.take(limit).toList();
    }
    return sorted;
  }

  /// Execute a unified search query with encryption-aware implementation
  ///
  /// Strategy:
  /// 1. Use SQL to filter by structural criteria (tags, folders, pinned, metadata)
  /// 2. Fetch candidate encrypted notes from database
  /// 3. Decrypt and filter by text search in memory
  ///
  /// Performance: Structural filters reduce candidate set before decryption
  ///
  /// SECURITY: Filters by userId to prevent cross-user data leakage
  Future<List<LocalNote>> search(
    SearchQuery query, {
    required String userId, // P0.5 SECURITY: Prevent cross-user search results
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    // Step 1: Build SQL query for structural filters (no text search in SQL)
    final candidates = await _fetchCandidates(query, userId, sort, limit);

    // Step 2: If no text search, return candidates as-is
    if (query.keywords.isEmpty) {
      return _sortedAndLimited(candidates, sort, limit);
    }

    // Step 3: Decrypt and filter by text search
    final keywords = query.keywords.toLowerCase().trim();
    final searchTerms = keywords
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final results = <LocalNote>[];
    final titleCache = <String, String>{};

    for (final note in candidates) {
      // Decrypt title and body
      final title = await _decryptHelper.decryptTitle(note);
      titleCache[note.id] = title;
      final body = await _decryptHelper.decryptBody(note);

      // Check if all search terms match (AND logic)
      final titleLower = title.toLowerCase();
      final bodyLower = body.toLowerCase();

      final matches = searchTerms.every(
        (term) => titleLower.contains(term) || bodyLower.contains(term),
      );

      if (matches) {
        results.add(note);
      }
    }

    return _sortedAndLimited(results, sort, limit, decryptedTitles: titleCache);
  }

  /// Fetch candidate notes using SQL-based structural filters
  ///
  /// SECURITY: Filters by userId to prevent cross-user data leakage
  Future<List<LocalNote>> _fetchCandidates(
    SearchQuery query,
    String userId,
    SortSpec sort,
    int? limit,
  ) async {
    // Start with base query
    // P0.5 SECURITY FIX: Add userId filter to prevent cross-user search results
    var q = db.select(db.localNotes)
      ..where((n) => n.deleted.equals(false) & n.userId.equals(userId));

    // Folder filter
    if (query.folderName != null) {
      final folder = await _findFolderByName(query.folderName!);
      if (folder == null) {
        return []; // Folder not found
      }

      // Join with note_folders to filter by folder
      final notesInFolder =
          await (db.select(db.noteFolders)..where(
                (nf) =>
                    nf.folderId.equals(folder.id) & nf.userId.equals(userId),
              ))
              .get();

      final noteIds = notesInFolder.map((nf) => nf.noteId).toSet();
      if (noteIds.isEmpty) {
        return [];
      }

      q.where((n) => n.id.isIn(noteIds.toList()));
    }

    // Tag filters
    if (query.includeTags.isNotEmpty) {
      final tagsAny = query.includeTags
          .map((t) => t.trim().toLowerCase())
          .toList();
      final notesWithTags = await (db.select(
        db.noteTags,
      )..where((nt) => nt.tag.isIn(tagsAny) & nt.userId.equals(userId))).get();

      final noteIds = notesWithTags.map((nt) => nt.noteId).toSet();
      if (noteIds.isEmpty) {
        return [];
      }

      q.where((n) => n.id.isIn(noteIds.toList()));
    }

    if (query.excludeTags.isNotEmpty) {
      final tagsNone = query.excludeTags
          .map((t) => t.trim().toLowerCase())
          .toList();
      final notesWithExcludedTags = await (db.select(
        db.noteTags,
      )..where((nt) => nt.tag.isIn(tagsNone) & nt.userId.equals(userId))).get();

      final excludedIds = notesWithExcludedTags.map((nt) => nt.noteId).toSet();
      if (excludedIds.isNotEmpty) {
        q.where((n) => n.id.isNotIn(excludedIds.toList()));
      }
    }

    // Pinned filter
    if (query.isPinned) {
      q.where((n) => n.isPinned.equals(true));
    }

    // Note type filter (exclude templates)
    q.where((n) => n.noteType.equals(0));

    // Apply sorting
    if (sort.pinnedFirst && !query.isPinned) {
      q.orderBy([
        (n) => OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc),
      ]);
    }

    switch (sort.sortBy) {
      case SortBy.updatedAt:
      case SortBy.createdAt:
        q.orderBy([
          (n) => OrderingTerm(
            expression: n.updatedAt,
            mode: sort.ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
        break;
      case SortBy.title:
        // Cannot sort by encrypted title at SQL level
        // Will sort after decryption if needed
        q.orderBy([
          (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
        ]);
        break;
      default:
        q.orderBy([
          (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
        ]);
    }

    // Apply limit (fetch more candidates if text search will filter)
    if (query.keywords.isNotEmpty) {
      // Fetch extra candidates since text filtering will reduce results
      final candidateLimit = limit != null ? limit * 3 : 300;
      q.limit(candidateLimit);
    } else if (limit != null) {
      final fetchLimit = sort.sortBy == SortBy.title ? limit * 3 : limit;
      q.limit(fetchLimit);
    }

    return q.get();
  }

  /// Find folder by name or path
  Future<LocalFolder?> _findFolderByName(String name) async {
    // Try exact name match first
    final folder =
        await (db.select(db.localFolders)
              ..where((f) => f.deleted.equals(false))
              ..where((f) => f.name.equals(name)))
            .getSingleOrNull();

    if (folder != null) return folder;

    // Try path match
    final path = name.startsWith('/') ? name : '/$name';
    return (db.select(db.localFolders)
          ..where((f) => f.deleted.equals(false))
          ..where((f) => f.path.equals(path)))
        .getSingleOrNull();
  }

  /// Execute a search query string (convenience method)
  ///
  /// P0.5 SECURITY: Requires userId to prevent cross-user search results
  Future<List<LocalNote>> searchString(
    String query, {
    required String userId,
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    final searchQuery = SearchParser.parse(query);
    return search(searchQuery, userId: userId, sort: sort, limit: limit);
  }

  /// Search notes by tags only (optimized for tag-only searches)
  ///
  /// P0.5 SECURITY: Requires userId to prevent cross-user search results
  Future<List<LocalNote>> searchByTags({
    required String userId,
    List<String> anyTags = const [],
    List<String> noneTags = const [],
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    if (anyTags.isEmpty && noneTags.isEmpty) {
      // No tags specified - return all notes for this user
      return _getAllNotes(userId: userId, sort: sort, limit: limit);
    }

    // Use unified search with tag filters only
    final query = SearchQuery(includeTags: anyTags, excludeTags: noneTags);

    return search(query, userId: userId, sort: sort, limit: limit);
  }

  /// Get all notes (no filters)
  ///
  /// P0.5 SECURITY: Filters by userId to prevent cross-user data access
  Future<List<LocalNote>> _getAllNotes({
    required String userId,
    SortSpec sort = const SortSpec(),
    int? limit,
  }) async {
    final query = db.select(db.localNotes)
      ..where((n) => n.deleted.equals(false) & n.userId.equals(userId));

    // Apply sorting
    if (sort.pinnedFirst) {
      query.orderBy([
        (n) => OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc),
      ]);
    }

    switch (sort.sortBy) {
      case SortBy.title:
        query.orderBy([
          (n) => OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc),
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
      final fetchLimit = sort.sortBy == SortBy.title ? limit * 3 : limit;
      query.limit(fetchLimit);
    }

    final rows = await query.get();
    return _sortedAndLimited(rows, sort, limit);
  }
}
