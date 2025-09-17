import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget to display and manage tags for a note
class NoteTagChips extends ConsumerStatefulWidget {
  const NoteTagChips({
    required this.noteId,
    super.key,
    this.initialTags = const [],
    this.onTagsChanged,
    this.editable = true,
  });
  final String noteId;
  final List<String> initialTags;
  final Function(List<String>)? onTagsChanged;
  final bool editable;

  @override
  ConsumerState<NoteTagChips> createState() => _NoteTagChipsState();
}

class _NoteTagChipsState extends ConsumerState<NoteTagChips> {
  late List<String> _tags;
  bool _isAddingTag = false;
  final _tagController = TextEditingController();
  final _tagFocusNode = FocusNode();
  List<String> _availableTags = [];
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.initialTags);
    _loadAvailableTags();
    _tagController.addListener(_updateSuggestions);
  }

  @override
  void dispose() {
    _tagController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTags() async {
    final repo = ref.read(notesRepositoryProvider);
    final tagCounts = await repo.listTagsWithCounts();
    if (mounted) {
      setState(() {
        _availableTags = tagCounts.map((tc) => tc.tag).toList();
      });
    }
  }

  void _updateSuggestions() {
    final input = _tagController.text.trim().toLowerCase();
    if (input.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() {
      _suggestions = _availableTags
          .where(
            (tag) => tag.toLowerCase().contains(input) && !_tags.contains(tag),
          )
          .take(5)
          .toList();
    });
  }

  Future<void> _addTag(String tag) async {
    final normalizedTag = tag.trim().toLowerCase();
    if (normalizedTag.isEmpty || _tags.contains(normalizedTag)) {
      return;
    }

    setState(() {
      _tags.add(normalizedTag);
      _isAddingTag = false;
      _tagController.clear();
      _suggestions = [];
    });

    // Update in database
    final repo = ref.read(notesRepositoryProvider);
    await repo.addTag(noteId: widget.noteId, tag: normalizedTag);

    widget.onTagsChanged?.call(_tags);
    HapticFeedback.lightImpact();

    // Reload available tags to include new one
    _loadAvailableTags();
  }

  Future<void> _removeTag(String tag) async {
    setState(() {
      _tags.remove(tag);
    });

    // Update in database
    final repo = ref.read(notesRepositoryProvider);
    await repo.removeTag(noteId: widget.noteId, tag: tag);

    widget.onTagsChanged?.call(_tags);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Existing tags
            ..._tags.map((tag) => _buildTagChip(tag, colorScheme)),
            // Add tag button or input
            if (widget.editable)
              _isAddingTag
                  ? _buildAddTagInput(colorScheme)
                  : _buildAddTagButton(colorScheme),
          ],
        ),
        // Suggestions
        if (_suggestions.isNotEmpty && _isAddingTag)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _suggestions.map((suggestion) {
                return InkWell(
                  onTap: () => _addTag(suggestion),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tag,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          suggestion,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTagChip(String tag, ColorScheme colorScheme) {
    return Chip(
      label: Text(tag),
      deleteIcon: widget.editable
          ? Icon(Icons.close, size: 18, color: colorScheme.onSecondaryContainer)
          : null,
      onDeleted: widget.editable ? () => _removeTag(tag) : null,
      backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.7),
      labelStyle: TextStyle(
        color: colorScheme.onSecondaryContainer,
        fontSize: 13,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAddTagButton(ColorScheme colorScheme) {
    return ActionChip(
      avatar: Icon(Icons.add, size: 18, color: colorScheme.primary),
      label: Text(
        'Tag',
        style: TextStyle(color: colorScheme.primary, fontSize: 13),
      ),
      onPressed: () {
        setState(() => _isAddingTag = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _tagFocusNode.requestFocus();
        });
      },
      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
      side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAddTagInput(ColorScheme colorScheme) {
    return Container(
      width: 120,
      height: 32,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _tagController,
              focusNode: _tagFocusNode,
              decoration: const InputDecoration(
                hintText: 'Add tag',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _addTag(value);
                } else {
                  setState(() {
                    _isAddingTag = false;
                    _tagController.clear();
                  });
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () {
              setState(() {
                _isAddingTag = false;
                _tagController.clear();
                _suggestions = [];
              });
            },
          ),
        ],
      ),
    );
  }
}

/// Compact version of tag chips for list views
class CompactTagChips extends StatelessWidget {
  const CompactTagChips({
    required this.tags,
    super.key,
    this.maxTags = 3,
    this.onTagTap,
  });
  final List<String> tags;
  final int maxTags;
  final Function(String)? onTagTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayTags = tags.take(maxTags).toList();
    final remaining = tags.length - displayTags.length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...displayTags.map(
          (tag) => GestureDetector(
            onTap: onTagTap != null ? () => onTagTap!(tag) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '#$tag',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$remaining',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
