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
import 'package:duru_notes_app/ui/widgets/error_display.dart';
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

  /// Generate a clean preview from note body by stripping markdown
  String _generatePreview(String body) {
    if (body.trim().isEmpty) return '';
    
    // Strip markdown formatting for cleaner preview
    final preview = body
        .replaceAll(RegExp(r'^#{1,6}\s+'), '') // Remove headings
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Remove bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Remove italic
        .replaceAll(RegExp(r'`(.*?)`'), r'$1') // Remove inline code
        .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '') // Remove list markers
        .replaceAll(RegExp(r'^\s*>\s+', multiLine: true), '') // Remove quotes
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '[Image]') // Replace images
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // Remove links
        .replaceAll(RegExp(r'\n+'), ' ') // Replace newlines with spaces
        .trim();
    
    return preview;
  }

  /// Format date for display in note list
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes;
      
      if (hours == 0) {
        if (minutes <= 1) return 'Just now';
        return '${minutes}m ago';
      }
      return '${hours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Show actual date for older notes
      return '${date.day}/${date.month}/${date.year}';
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
                      children: [
                        const SizedBox(height: 120),
                        EmptyDisplay(
                          icon: Icons.note_outlined,
                          title: 'No notes yet',
                          subtitle: hasSession 
                            ? 'Tap the + button to create your first note'
                            : 'Sign in to sync your notes across devices',
                          action: hasSession ? null : TextButton(
                            onPressed: () {
                              // User is not signed in - this shouldn't happen in normal flow
                              // but provides helpful feedback
                            },
                            child: const Text('Sign In'),
                          ),
                        ),
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
                        final preview = _generatePreview(n.body);
                        return ListTile(
                          title: Text(
                            n.title.isEmpty ? '(Untitled)' : n.title,
                            style: n.title.isEmpty 
                              ? TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                )
                              : null,
                          ),
                          subtitle: preview.isNotEmpty ? Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ) : null,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatDate(n.updatedAt),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              if (!hasSession) 
                                Icon(
                                  Icons.offline_pin_outlined,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                            ],
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
              loading: () => const LoadingDisplay(message: 'Loading notes...'),
              error: (e, _) => ErrorDisplay(
                error: e,
                message: 'Failed to load notes',
                onRetry: () => ref.invalidate(notesListProvider),
              ),
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
