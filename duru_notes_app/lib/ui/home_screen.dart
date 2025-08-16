import 'package:duru_notes_app/core/crypto/crypto_box.dart';
import 'package:duru_notes_app/core/crypto/key_manager.dart';
import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/repository/notes_repository.dart';
import 'package:duru_notes_app/repository/sync_service.dart';
import 'package:duru_notes_app/ui/edit_note_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<AppDb> dbProvider = Provider<AppDb>((ref) => AppDb());
final Provider<KeyManager> keyManagerProvider = Provider<KeyManager>(
  (ref) => KeyManager(),
);
final Provider<CryptoBox> cryptoBoxProvider = Provider<CryptoBox>(
  (ref) => CryptoBox(ref.read(keyManagerProvider)),
);

final Provider<NotesRepository> repoProvider = Provider<NotesRepository>((ref) {
  final session = Supabase.instance.client.auth.currentSession!;
  final userId = session.user.id;
  return NotesRepository(
    db: ref.read(dbProvider),
    crypto: ref.read(cryptoBoxProvider),
    client: Supabase.instance.client,
    userId: userId,
  );
});

final Provider<SyncService> syncProvider = Provider<SyncService>(
  (ref) => SyncService(ref.read(repoProvider)),
);

final AutoDisposeFutureProvider<List<LocalNote>> notesListProvider =
    FutureProvider.autoDispose<List<LocalNote>>((ref) async {
      try {
        await ref.read(syncProvider).syncNow();
      } on Object {
        // ignore sync errors, show local notes
      }
      return ref.read(repoProvider).list();
    });

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duru Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(notesListProvider),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'reset') {
                await ref.read(syncProvider).reset();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local cache cleared')),
                  );
                }
                ref.invalidate(notesListProvider);
              } else if (v == 'logout') {
                await Supabase.instance.client.auth.signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset local cache')),
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: notesAsync.when(
        data: (notes) => notes.isEmpty
            ? const Center(child: Text('No notes yet'))
            : ListView.separated(
                itemCount: notes.length,
                separatorBuilder: (BuildContext _, int index) =>
                    const Divider(height: 1),
                itemBuilder: (BuildContext context, int i) {
                  final n = notes[i];
                  return ListTile(
                    title: Text(n.title),
                    subtitle: Text(
                      n.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EditNoteScreen(
                            noteId: n.id,
                            initialTitle: n.title,
                            initialBody: n.body,
                          ),
                        ),
                      );
                      ref.invalidate(notesListProvider);
                    },
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const EditNoteScreen(),
            ),
          );
          ref.invalidate(notesListProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
