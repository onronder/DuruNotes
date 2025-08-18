import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/ui/edit_note_screen.dart';
import 'package:flutter/material.dart';

/// Basit SearchDelegate: query değiştikçe DB'den sonuç çeker.
/// - 'once' gibi bir metin: başlık + gövdede arar
/// - '#tag' ile başlarsa: tag tablosunda arar
class NoteSearchDelegate extends SearchDelegate<void> {
  NoteSearchDelegate(this.db);

  final AppDb db;

  @override
  String get searchFieldLabel => 'Search notes or #tags';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
          tooltip: 'Clear',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
      tooltip: 'Back',
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildBody(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    return FutureBuilder<List<LocalNote>>(
      future: db.searchNotes(query),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notes = snap.data!;
        if (notes.isEmpty) {
          return const Center(child: Text('No results'));
        }
        return ListView.separated(
          itemCount: notes.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final n = notes[i];
            final subtitle = n.body.split('\n').firstOrNull ?? '';
            return ListTile(
              title: Text(n.title.isEmpty ? '(untitled)' : n.title),
              subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1),
              onTap: () async {
                // Arama ekranını kapatmadan detay açıyoruz
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditNoteScreen(
                      noteId: n.id,
                      initialTitle: n.title,
                      initialBody: n.body,
                    ),
                  ),
                );
                // Dönüşte sonuçları güncel görünsün
                showSuggestions(context);
              },
            );
          },
        );
      },
    );
  }
}

// Küçük yardımcı: firstOrNull (Dart 3'te List extension yoksa)
extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
