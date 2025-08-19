import 'dart:async';

import 'package:duru_notes_app/core/parser/note_block_parser.dart';
import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/models/note_block.dart';
import 'package:duru_notes_app/repository/notes_repository.dart';
import 'package:duru_notes_app/repository/sync_service.dart';
import 'package:duru_notes_app/ui/home_screen.dart';
import 'package:duru_notes_app/ui/widgets/block_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// A note editing screen that uses a block-based editor for the note body.
/// This widget supports both editing and preview modes. It uses Riverpod
/// providers to access the notes repository, sync service and local
/// database. The note body is stored in Markdown form; internally the
/// block editor works with [NoteBlock] objects and converts back to
/// Markdown when saving.
class EditNoteScreen extends ConsumerStatefulWidget {
  const EditNoteScreen({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialBody,
  });

  final String? noteId;
  final String? initialTitle;
  final String? initialBody;

  @override
  ConsumerState<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends ConsumerState<EditNoteScreen> {
  late final TextEditingController _title;
  late List<NoteBlock> _blocks;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle ?? '');
    final body = widget.initialBody ?? '';
    final parsed = parseMarkdownToBlocks(body);
    _blocks = parsed.isNotEmpty
        ? parsed
        : [const NoteBlock(type: NoteBlockType.paragraph, data: '')];
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _saveOrUpdate(BuildContext context) async {
    final repo = ref.read(repoProvider);
    final sync = ref.read(syncProvider);
    final messenger = ScaffoldMessenger.of(context);
    final bodyMarkdown = blocksToMarkdown(_blocks);

    try {
      await repo.createOrUpdate(
        title: _title.text.trim(),
        body: bodyMarkdown,
        id: widget.noteId,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop(true);

      // Trigger a background sync after save.
      unawaited(
        sync.syncNow().catchError((Object e, _) {
          debugPrint('Sync error after save: $e');
        }),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _deleteNote(BuildContext context) async {
    final repo = ref.read(repoProvider);
    final sync = ref.read(syncProvider);
    final messenger = ScaffoldMessenger.of(context);
    final noteId = widget.noteId;
    if (noteId == null) return;

    try {
      await repo.delete(noteId);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);

      unawaited(
        sync.syncNow().catchError((Object e, _) {
          debugPrint('Sync error after delete: $e');
        }),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(dbProvider);
    final effectiveTitle =
        _title.text.trim().isEmpty ? '(untitled)' : _title.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'New note' : 'Edit note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.noteId == null ? null : () => _deleteNote(context),
          ),
        ],
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Preview'),
                  Switch(
                    value: _preview,
                    onChanged: (v) {
                      setState(() => _preview = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(minHeight: 200),
                child: _preview
                    // Use MarkdownBody (non-scrollable) to avoid nested scrollables.
                    ? MarkdownBody(
                        data: blocksToMarkdown(_blocks),
                        onTapLink: (text, href, title) async {
                          if (href == null || href.isEmpty) return;
                          final uri = Uri.tryParse(href);
                          if (uri == null) return;
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await launchUrl(uri);
                          if (!ok) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Could not open $href')),
                            );
                          }
                        },
                      )
                    : BlockEditor(
                        blocks: _blocks,
                        // We pass the same list reference back to avoid controller rebuilds.
                        onChanged: (blocks) => setState(() => _blocks = blocks),
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _saveOrUpdate(context),
                  child: const Text('Save'),
                ),
              ),
              if (widget.noteId != null) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Backlinks',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<BacklinkPair>>(
                  future: db.backlinksWithSources(effectiveTitle),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final items = snap.data!;
                    if (items.isEmpty) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No backlinks'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (context, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final l = item.link;
                        final src = item.source;
                        final title = (src == null || src.title.trim().isEmpty)
                            ? l.sourceId
                            : src.title.trim();
                        return ListTile(
                          dense: true,
                          title: Text(title),
                          subtitle: Text('links to: ${l.targetTitle}'),
                          onTap: () async {
                            final existing =
                                src ?? await db.findNote(l.sourceId);
                            if (!context.mounted) return;
                            if (existing != null) {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EditNoteScreen(
                                    noteId: existing.id,
                                    initialTitle: existing.title,
                                    initialBody: existing.body,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
