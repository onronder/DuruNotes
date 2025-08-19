import 'dart:async';

import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
  late final TextEditingController _title = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.initialBody ?? '',
  );

  final FocusNode _bodyFocus = FocusNode();
  final LayerLink _bodyLink = LayerLink();
  final GlobalKey _bodyFieldKey = GlobalKey();

  OverlayEntry? _overlay;
  bool _preview = false;

  // Öneriler ve durum
  List<LocalNote> _suggestions = <LocalNote>[];
  Timer? _debounce;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();

    _bodyFocus.addListener(() {
      if (!_bodyFocus.hasFocus) {
        _removeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _bodyFocus.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  // ---------- Autocomplete ----------

  // İmlecin öncesine bakıp aktif '@' token’ını çıkarır.
  // Örn: "Merhaba @pro" -> "pro"; eğer uygun değilse null.
  String? _extractAtQuery() {
    final sel = _body.selection;
    if (!sel.isValid || !sel.isCollapsed) return null;

    final text = _body.text;
    final caret = sel.baseOffset;
    if (caret <= 0 || caret > text.length) return null;

    final before = text.substring(0, caret);
    final atIndex = before.lastIndexOf('@');
    if (atIndex == -1) return null;

    // '@' ile imleç arasında boşluk/yeni satır varsa aktif token değil.
    final segment = before.substring(atIndex + 1);
    if (segment.contains(' ') || segment.contains('\n')) return null;

    // '@' öncesi bir sınır olmalı (başlangıç, boşluk veya noktalama gibi)
    if (atIndex > 0) {
      final prev = before[atIndex - 1];
      const boundaries = ' \t\n([{,-.;:\'"“”‘’`';
      if (!boundaries.contains(prev)) return null;
    }

    // segment boş olabilir — bu durumda popülerleri göster.
    return segment; // "" | "pro" | "Pro"
  }

  void _onBodyChanged(String _) {
    if (_preview || !_bodyFocus.hasFocus) {
      _removeOverlay();
      return;
    }

    final query = _extractAtQuery();
    if (query == null) {
      _removeOverlay();
      return;
    }

    // Aynı sorguysa gereksiz çalıştırma
    if (query == _lastQuery && _overlay != null) return;
    _lastQuery = query;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      final db = ref.read(dbProvider);
      final results = await db.suggestNotesByTitlePrefix(
        query,
      ); // DB çağrısı
      if (!mounted) return;

      setState(() {
        _suggestions = results;
      });
      _showOverlay(); // her seferinde güncelle
    });
  }

  void _showOverlay() {
    if (_suggestions.isEmpty) {
      _removeOverlay();
      return;
    }

    final overlay = Overlay.of(context);

    // Eğer hâlihazırda overlay varsa yeniden çizdir.
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }

    _overlay = OverlayEntry(
      builder: (context) {
        final box =
            _bodyFieldKey.currentContext?.findRenderObject() as RenderBox?;
        final width = box?.size.width ?? 320.0;

        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: CompositedTransformFollower(
              link: _bodyLink,
              // showWhenUnlinked varsayılan olarak false; belirtmeye gerek yok.
              offset: const Offset(0, 8), // textfield’ın hemen altı
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width,
                    maxHeight: 240,
                    minWidth: 240,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, i) {
                      final n = _suggestions[i];
                      final title = (n.title.trim().isEmpty)
                          ? '(untitled)'
                          : n.title.trim();
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(title),
                        onTap: () => _insertAtToken(title),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  // '@...' yerini '@Başlık ' ile değiştirir.
  void _insertAtToken(String title) {
    final sel = _body.selection;
    if (!sel.isValid || !sel.isCollapsed) return;

    final text = _body.text;
    final caret = sel.baseOffset;
    final before = text.substring(0, caret);
    final after = text.substring(caret);

    final atIndex = before.lastIndexOf('@');
    if (atIndex < 0) return;

    final newBefore = '${before.substring(0, atIndex)}@$title ';
    final newText = newBefore + after;

    _body.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newBefore.length),
    );

    _removeOverlay();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final sync = ref.read(syncProvider);
    final db = ref.read(dbProvider);

    final effectiveTitle = _title.text.trim().isEmpty
        ? '(untitled)'
        : _title.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'New note' : 'Edit note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.noteId == null
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await repo.delete(widget.noteId!); // local-first
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true); // anında kapan
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
                  },
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
                      if (v) _removeOverlay();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Gövde editörü + anchor
              CompositedTransformTarget(
                link: _bodyLink,
                child: Container(
                  key: _bodyFieldKey,
                  constraints: const BoxConstraints(minHeight: 200),
                  child: _preview
                      ? Markdown(
                          data: _body.text,
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
                      : TextField(
                          controller: _body,
                          focusNode: _bodyFocus,
                          maxLines: null,
                          onChanged: _onBodyChanged,
                          decoration: const InputDecoration(
                            labelText:
                                'Body (Markdown supported, #tags and [[Links]] / @Links)',
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await repo.createOrUpdate(
                        title: _title.text.trim(),
                        body: _body.text,
                        id: widget.noteId,
                      ); // local-first
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
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
                  },
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
