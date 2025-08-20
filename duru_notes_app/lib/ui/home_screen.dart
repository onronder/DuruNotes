import 'dart:async';

import 'package:duru_notes_app/core/crypto/crypto_box.dart';
import 'package:duru_notes_app/core/crypto/key_manager.dart';
import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/repository/notes_repository.dart';
import 'package:duru_notes_app/repository/sync_service.dart';
import 'package:duru_notes_app/ui/edit_note_screen.dart';
import 'package:duru_notes_app/ui/note_search_delegate.dart';
import 'package:duru_notes_app/ui/tags_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// --- Providers ---
final dbProvider = Provider<AppDb>((ref) => AppDb());
final keyManagerProvider = Provider<KeyManager>((ref) => KeyManager());
final cryptoBoxProvider = Provider<CryptoBox>(
  (ref) => CryptoBox(ref.read(keyManagerProvider)),
);

final repoProvider = Provider<NotesRepository>((ref) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    throw StateError('No active Supabase session');
  }
  return NotesRepository(
    db: ref.read(dbProvider),
    crypto: ref.read(cryptoBoxProvider),
    client: Supabase.instance.client,
    userId: session.user.id,
  );
});

final syncProvider = Provider<SyncService>(
  (ref) => SyncService(ref.read(repoProvider)),
);

/// SyncService'ten sinyal alan stream provider (UI invalidation için)
final syncChangesProvider = StreamProvider<void>(
  (ref) => ref.read(syncProvider).changes,
);

/// Not listesi: Önce lokali gösterir, ardından sync dener
final AutoDisposeFutureProvider<List<LocalNote>> notesListProvider =
    FutureProvider.autoDispose<List<LocalNote>>((ref) async {
  try {
    await ref.read(syncProvider).syncNow();
  } on Object {
    // sync hatalarını sessiz geç
  }
  return ref.read(repoProvider).list();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // listenManual için doğru generic: StreamProvider<void> -> AsyncValue<void>
  ProviderSubscription<AsyncValue<void>>? _syncSub;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();

    // Widget ağacı kurulduktan sonra Realtime başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider).startRealtime();
      // İlk açılışta bir kere sync
      unawaited(ref.read(syncProvider).syncNow());
    });

    // Realtime veya manuel sync bittiğinde listeyi güncelle
    _syncSub = ref.listenManual<AsyncValue<void>>(
      syncChangesProvider,
      (prev, next) {
        ref.invalidate(notesListProvider);
      },
    );
  }

  @override
  void dispose() {
    _syncSub?.close();
    ref.read(syncProvider).stopRealtime();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(notesListProvider);
    try {
      await ref.read(syncProvider).syncNow();
    } on Object {
      // sessiz geç
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duru Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () async {
              final db = ref.read(dbProvider);
              await showSearch<LocalNote?>(
                context: context,
                delegate: NoteSearchDelegate(db: db),
              );
              ref.invalidate(notesListProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'reset':
                  await ref.read(syncProvider).reset();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Local cache cleared')),
                    );
                  }
                  ref.invalidate(notesListProvider);
                  return;
                case 'tags':
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TagsScreen(),
                    ),
                  );
                  return;
                case 'logout':
                  // Realtime’ı kapat + Supabase oturumunu kapat
                  ref.read(syncProvider).stopRealtime();
                  await Supabase.instance.client.auth.signOut();
                  // Not: Auth guard/Router login ekranına yönlendirmelidir
                  return;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset local cache')),
              PopupMenuItem(value: 'tags', child: Text('Tags')),
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No notes yet')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: notes.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = notes[index];
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
          );
        },
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
