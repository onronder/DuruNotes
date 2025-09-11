import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:duru_notes/providers.dart';

/// Widget to display and manage tags for a note
class NoteTagChips extends ConsumerStatefulWidget {
  const NoteTagChips({
    required this.noteId,
    super.key,
    this.onTagsChanged,
  });

  final String noteId;
  final VoidCallback? onTagsChanged;

  @override
  ConsumerState<NoteTagChips> createState() => _NoteTagChipsState();
}

class _NoteTagChipsState extends ConsumerState<NoteTagChips> {
  List<String> _tags = [];
  bool _isLoading = true;
  
  // Remember recently added tags for display casing (visual only)
  final Map<String, String> _displayCasing = {};

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    if (!mounted) return;
    
    final repo = ref.read(notesRepositoryProvider);
    final tags = await repo.getTagsForNote(widget.noteId);
    
    if (mounted) {
      setState(() {
        _tags = tags;
        _isLoading = false;
      });
    }
  }

  Future<void> _addTag(String tag) async {
    if (tag.trim().isEmpty) return;
    
    final normalizedTag = tag.trim().toLowerCase();
    if (_tags.contains(normalizedTag)) return;
    
    // Remember display casing for this session
    _displayCasing[normalizedTag] = tag.trim();
    
    setState(() {
      _tags.add(normalizedTag);
    });
    
    final repo = ref.read(notesRepositoryProvider);
    await repo.addTag(noteId: widget.noteId, tag: tag);
    
    widget.onTagsChanged?.call();
  }

  Future<void> _removeTag(String tag) async {
    setState(() {
      _tags.remove(tag);
      _displayCasing.remove(tag);
    });
    
    final repo = ref.read(notesRepositoryProvider);
    await repo.removeTag(noteId: widget.noteId, tag: tag);
    
    widget.onTagsChanged?.call();
  }

  void _showAddTagDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => _AddTagDialog(
        existingTags: _tags,
        onTagSelected: _addTag,
      ),
    );
  }

  String _getDisplayTag(String tag) {
    // Use remembered casing if available, otherwise use the normalized form
    return _displayCasing[tag] ?? tag;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._tags.map((tag) => Chip(
          label: Text('#${_getDisplayTag(tag)}'),
          deleteIcon: const Icon(Icons.close, size: 18),
          onDeleted: () => _removeTag(tag),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          deleteIconColor: Theme.of(context).colorScheme.onSecondaryContainer,
        )),
        ActionChip(
          label: const Text('+ Tag'),
          onPressed: _showAddTagDialog,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.primary,
          ),
          avatar: Icon(
            Icons.add,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Dialog for adding tags with autocomplete
class _AddTagDialog extends ConsumerStatefulWidget {
  const _AddTagDialog({
    required this.existingTags,
    required this.onTagSelected,
  });

  final List<String> existingTags;
  final void Function(String) onTagSelected;

  @override
  ConsumerState<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends ConsumerState<_AddTagDialog> {
  final _controller = TextEditingController();
  List<String> _suggestions = [];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateSuggestions);
    _loadPopularTags();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPopularTags() async {
    if (!mounted) return;
    
    final repo = ref.read(notesRepositoryProvider);
    final tags = await repo.listTagsWithCounts();
    
    if (mounted) {
      setState(() {
        // Show top 10 tags that aren't already on the note
        _suggestions = tags
            .where((t) => !widget.existingTags.contains(t.tag))
            .take(10)
            .map((t) => t.tag)
            .toList();
      });
    }
  }

  Future<void> _updateSuggestions() async {
    final query = _controller.text.trim();
    
    if (query.isEmpty) {
      await _loadPopularTags();
      return;
    }
    
    setState(() {
      _isLoadingSuggestions = true;
    });
    
    final repo = ref.read(notesRepositoryProvider);
    final suggestions = await repo.searchTags(query);
    
    if (mounted) {
      setState(() {
        _suggestions = suggestions
            .where((t) => !widget.existingTags.contains(t))
            .toList();
        _isLoadingSuggestions = false;
      });
    }
  }

  void _selectTag(String tag) {
    widget.onTagSelected(tag);
    Navigator.of(context).pop();
  }

  void _addCustomTag() {
    final tag = _controller.text.trim();
    if (tag.isNotEmpty) {
      _selectTag(tag);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Tag'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter tag name',
                prefixText: '#',
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _controller.clear,
                      )
                    : null,
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addCustomTag(),
            ),
            const SizedBox(height: 16),
            if (_isLoadingSuggestions)
              const LinearProgressIndicator()
            else if (_suggestions.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _controller.text.isEmpty ? 'Popular tags:' : 'Suggestions:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((tag) => InputChip(
                  label: Text('#$tag'),
                  onPressed: () => _selectTag(tag),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                )).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isNotEmpty ? _addCustomTag : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
