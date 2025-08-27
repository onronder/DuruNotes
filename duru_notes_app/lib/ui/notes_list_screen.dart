import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers.dart';
import 'edit_note_screen_simple.dart';

/// Main notes list screen showing user's notes
class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Listen for scroll to implement infinite loading
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // User is near the bottom, load more if available
      final hasMore = ref.read(hasMoreNotesProvider);
      final isLoading = ref.read(notesLoadingProvider);
      
      if (hasMore && !isLoading) {
        ref.read(notesPageProvider.notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final notesAsync = ref.watch(notesPageProvider);
    final currentNotes = ref.watch(currentNotesProvider);
    final isLoading = ref.watch(notesLoadingProvider);
    final hasMore = ref.watch(hasMoreNotesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search feature temporarily disabled'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
          // Menu with import and other options
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _showImportDialog(context);
                  break;
                case 'export':
                  _showExportDialog(context);
                  break;
                case 'settings':
                  _showSettingsDialog(context);
                  break;
                case 'logout':
                  _confirmLogout(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Import Notes'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Notes'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // User info banner
          if (user != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      (user.email?.substring(0, 1).toUpperCase() ?? 'U'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back!',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          user.email ?? 'User',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Online',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Notes list
          Expanded(
            child: notesAsync.when(
              data: (notesPage) {
                final notes = notesPage.items;
                if (notes.isEmpty) {
                  return _buildEmptyState();
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.read(notesPageProvider.notifier).refresh();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= notes.length) {
                        // Loading indicator at the bottom
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      final note = notes[index];
                      return _buildNoteCard(note);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading notes: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(notesPageProvider.notifier).refresh();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewNote(context),
        tooltip: 'Create New Note',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.note_add,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No notes yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to create your first note',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _createNewNote(context),
            icon: const Icon(Icons.add),
            label: const Text('Create First Note'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(LocalNote note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          note.title.isNotEmpty ? note.title : 'Untitled',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              _generatePreview(note.body),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(note.updatedAt),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editNote(note);
                break;
              case 'delete':
                _deleteNote(note);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => _editNote(note),
      ),
    );
  }

  String _generatePreview(String body) {
    if (body.trim().isEmpty) return 'No content';
    
    // Remove markdown formatting for preview
    String preview = body
        .replaceAll(RegExp(r'#+ '), '') // Remove headers
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Remove bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Remove italic
        .replaceAll(RegExp(r'`(.*?)`'), r'$1') // Remove code
        .replaceAll(RegExp(r'\n+'), ' ') // Replace newlines with spaces
        .trim();
    
    return preview.length > 100 ? '${preview.substring(0, 97)}...' : preview;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  void _createNewNote(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditNoteScreen(),
      ),
    );
  }

  void _editNote(LocalNote note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditNoteScreen(
          noteId: note.id,
          initialTitle: note.title,
          initialBody: note.body,
        ),
      ),
    );
  }

  void _deleteNote(LocalNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title.isNotEmpty ? note.title : 'Untitled'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                final repo = ref.read(notesRepositoryProvider);
                await repo.delete(note.id);
                
                // Refresh the notes list
                ref.read(notesPageProvider.notifier).refresh();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Note deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting note: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Notes'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Production-grade import system ready!'),
            SizedBox(height: 16),
            Text('Supported formats:'),
            SizedBox(height: 8),
            Text('• Markdown (.md, .markdown)'),
            Text('• Evernote (.enex)'),
            Text('• Obsidian vaults (folders)'),
            SizedBox(height: 16),
            Text('Features:'),
            Text('• Security validation'),
            Text('• Progress tracking'),
            Text('• Error recovery'),
            Text('• Content sanitization'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Import service integration ready - full UI coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            child: const Text('Select Files'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings screen coming soon'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth.signOut();
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}