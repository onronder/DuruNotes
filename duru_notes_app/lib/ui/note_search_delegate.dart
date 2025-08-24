import 'package:flutter/material.dart';
import 'package:duru_notes_app/data/local/app_db.dart';

class NoteSearchDelegate extends SearchDelegate<LocalNote?> {
  NoteSearchDelegate({required this.db});

  final AppDb db;
  int _token = 0; // yarış durumlarını atlamak için

  @override
  String? get searchFieldLabel => 'Search notes (#tag supported)';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Clear',
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  Future<List<LocalNote>> _doSearch(String q, int myToken) async {
    final res = await db.searchNotes(q);
    // Eski isteklerin sonuçlarını yut
    if (myToken != _token) return const <LocalNote>[];
    return res;
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final current = ++_token;
    return FutureBuilder<List<LocalNote>>(
      future: db.suggestNotesByTitlePrefix(query, limit: 8),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final items = snap.data ?? const <LocalNote>[];
        if (items.isEmpty) {
          return const Center(child: Text('No suggestions'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final n = items[i];
            return ListTile(
              title: Text(n.title.isEmpty ? '(Untitled)' : n.title),
              subtitle: Text(
                n.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => close(context, n),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final myToken = ++_token;
    return FutureBuilder<List<LocalNote>>(
      future: _doSearch(query, myToken),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <LocalNote>[];
        if (items.isEmpty) {
          return const Center(child: Text('No results'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final n = items[i];
            return ListTile(
              title: Text(n.title.isEmpty ? '(Untitled)' : n.title),
              subtitle: Text(
                n.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => close(context, n),
            );
          },
        );
      },
    );
  }
}
