import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/ui/edit_note_screen.dart';
import 'package:flutter/material.dart';

/// Basit arama delegesi:
/// - `#tag` ile tag araması
/// - Düz metinle başlık/gövde LIKE araması
class NoteSearchDelegate extends SearchDelegate<LocalNote?> {
  NoteSearchDelegate({required this.db})
    : super(searchFieldLabel: 'Search notes (#tag or text)');

  final AppDb db;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return <Widget>[
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

  @override
  Widget buildResults(BuildContext context) {
    return _ResultsList(db: db, queryText: query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _ResultsList(db: db, queryText: query);
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.db, required this.queryText});

  final AppDb db;
  final String queryText;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LocalNote>>(
      future: db.searchNotes(queryText),
      builder: (context, snapshot) {
        final notes = snapshot.data;
        if (notes == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (notes.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              Center(child: Text('No results')),
            ],
          );
        }

        return ListView.separated(
          itemCount: notes.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final note = notes[index];
            return ListTile(
              title: Text(note.title),
              subtitle: Text(
                note.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                final navigator = Navigator.of(context);
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditNoteScreen(
                      noteId: note.id,
                      initialTitle: note.title,
                      initialBody: note.body,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
