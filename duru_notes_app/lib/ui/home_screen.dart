// lib/ui/home_screen.dart
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

/// --------------------
/// Providers
/// --------------------
final dbProvider = Provider<AppDb>((ref) => AppDb());

final keyManagerProvider = Provider<KeyManager>((ref) => KeyManager());

final cryptoBoxProvider = Provider<CryptoBox>(
  (ref) => CryptoBox(ref.read(keyManagerProvider)),
);

/// Repo: Oturum yoksa bile local-only modda çalışır.
/// (userId olarak 'local-only' atanır; push denemeleri SyncService yoksa zaten yapılmaz.)
final repoProvider = Provider<NotesRepository>((ref) {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id ?? 'local-only';
  return NotesRepository(
    db: ref.read(dbProvider),
    crypto: ref.read(cryptoBoxProvider),
    client: client,
    userId: userId,
  );
});

/// Sync: Yalnızca aktif Supabase oturumu varken oluşturulur, aksi halde null.
final syncProvider = Provider<SyncService?>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  // Projenizdeki SyncService yapıcısı repo alıyorsa aşağıdaki satır yeterli:
  return SyncService(ref.read(repoProvider));
  // Eğer sizin SyncService farklı imza istiyorsa (örn. client/db/userId),
  // burada ona uygun şekilde oluşturun.
});

/// SyncService'ten sinyal alan stream provider (UI invalidation için).
/// Oturum yoksa boş stream dönülür.
final syncChangesProvider = StreamProvider<void>((ref) {
  final sync = ref.watch(syncProvider);
  return sync?.changes ?? const Stream<void>.empty();
});

/// Not listesi: her zaman lokal notları döndürür.
/// SyncService varsa arka planda senkronizasyonu tetikler.
final AutoDisposeFutureProvider<List<LocalNote>> notesListProvider =
    FutureProvider.autoDispose<List<LocalNote>>((ref) async {
  final sync = ref.read(syncProvider);
  final f = sync?.syncNow();
  if (f != null) unawaited(f);
  return ref.read(repoProvider).list();
});

/// --------------------
/// UI
/// --------------------
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ProviderSubscription<AsyncValue<void>>? _syncSub;

  @override
  void initState() {
    super.initState();

    // Widget ağacı kurulduktan sonra varsa realtime + ilk sync başlat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sync = ref.read(syncProvider);
      sync?.startRealtime();
      final f = sync?.syncNow();
      if (f != null) unawaited(f);
    });

    // Sync event geldikçe listeyi invalidate et.
    _syncSub = ref.listenManual<AsyncValue<void>>(
      syncChangesProvider,
      (prev, next) => ref.invalidate(notesListProvider),
    );
  }

  @override
  void dispose() {
    _syncSub?.close();
    ref.read(syncProvider)?.stopRealtime();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(notesListProvider);
    try {
      final f = ref.read(syncProvider)?.syncNow();
      if (f != null) await f;
    } on Object {
      // sessizce yut
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final hasSession = Supabase.instance.client.auth.currentUser != null;

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
                  // Oturum yoksa bile local DB'yi temizleyebilmek için fallback
                  final sync = ref.read(syncProvider);
                  if (sync != null) {
                    await sync.reset();
                  } else {
                    await ref.read(dbProvider).clearAll();
                  }
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
                  final client = Supabase.instance.client;
                  final userId = client.auth.currentUser?.id;
                  
                  // Stop realtime sync
                  ref.read(syncProvider)?.stopRealtime();
                  
                  // Clear encryption keys (enforce E2EE)
                  if (userId != null) {
                    await ref.read(keyManagerProvider).deleteMasterKey(userId);
                  }
                  
                  // Sign out from Supabase
                  await client.auth.signOut();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out')),
                    );
                  }
                  ref.invalidate(notesListProvider);
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
      body: Column(
        children: [
          if (!hasSession)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Offline mode — Supabase oturumu yok. Senkronizasyon devre dışı.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
          Expanded(
            child: notesAsync.when(
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
                } else {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      itemCount: notes.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
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
                }
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
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
