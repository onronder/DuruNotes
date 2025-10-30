import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/note.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Screen that displays notes filtered by a specific tag
class TagNotesScreen extends ConsumerStatefulWidget {
  const TagNotesScreen({required this.tag, super.key});
  final String tag;

  @override
  ConsumerState<TagNotesScreen> createState() => _TagNotesScreenState();
}

class _TagNotesScreenState extends ConsumerState<TagNotesScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;
  AppLogger get _logger => ref.read(loggerProvider);

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final tagRepo = ref.read(tagRepositoryProvider);
      final notes = await tagRepo.queryNotesByTags(anyTags: [widget.tag]);
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load notes for tag',
        error: error,
        stackTrace: stackTrace,
        data: {'tag': widget.tag},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load #${widget.tag} notes. Please retry.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_loadNotes()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.tag, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(widget.tag),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
          ? _buildEmptyState(context)
          : _buildNotesList(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isEmailTag = widget.tag.toLowerCase() == 'email';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEmailTag ? Icons.email_outlined : Icons.note_alt_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isEmailTag
                  ? 'No converted email notes yet'
                  : 'No notes with #${widget.tag}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isEmailTag
                  ? 'Emails that you convert to notes will appear here.\n\nTo convert an email:\n1. Check your Inbox for new emails\n2. Open an email\n3. Tap "Convert to Note"'
                  : 'Notes tagged with #${widget.tag} will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            if (isEmailTag) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to inbox - assuming inbox is a tab or route
                },
                icon: const Icon(Icons.inbox),
                label: const Text('Go to Inbox'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: note.isPinned
                ? Icon(
                    Icons.push_pin,
                    color: theme.colorScheme.primary,
                    size: 20,
                  )
                : null,
            title: Text(
              note.title.isEmpty ? '(Untitled)' : note.title,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDate(note.updatedAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () {
              // Navigate to note editor
              // TODO: Replace with actual navigation when NoteEditorScreen is available
              Navigator.of(context).pop(note);
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
