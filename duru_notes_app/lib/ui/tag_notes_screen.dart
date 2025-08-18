import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/ui/edit_note_screen.dart';
import 'package:duru_notes_app/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TagNotesScreen extends ConsumerWidget {
  const TagNotesScreen({required this.tag, super.key});
  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(dbProvider);
    return Scaffold(
      appBar: AppBar(title: Text('#$tag')),
      body: FutureBuilder<List<LocalNote>>(
        future: db.notesWithTag(tag),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snap.data!;
          if (notes.isEmpty) {
            return const Center(child: Text('No notes'));
          }
          return ListView.separated(
            itemCount: notes.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = notes[i];
              return ListTile(
                title: Text(n.title.isEmpty ? '(untitled)' : n.title),
                subtitle: Text(
                  n.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditNoteScreen(
                      noteId: n.id,
                      initialTitle: n.title,
                      initialBody: n.body,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
