import 'package:duru_notes_app/ui/home_screen.dart';
import 'package:duru_notes_app/ui/tag_notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(dbProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: FutureBuilder<List<String>>(
        future: db.distinctTags(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tags = snap.data!;
          if (tags.isEmpty) {
            return const Center(child: Text('No tags yet'));
          }
          return ListView.separated(
            itemCount: tags.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = tags[i];
              return ListTile(
                title: Text('#$t'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TagNotesScreen(tag: t),
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
