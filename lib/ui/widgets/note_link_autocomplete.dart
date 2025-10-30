import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/services/note_link_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Production-grade @ sign autocomplete widget for note linking
///
/// Features:
/// - Detects @ character followed by text
/// - Shows overlay with matching notes
/// - Fuzzy search as user types
/// - Keyboard navigation (up/down arrows)
/// - Inserts @[note-title] on selection
/// - Handles edge cases (cursor position, overlay bounds)
class NoteLinkAutocomplete extends ConsumerStatefulWidget {
  const NoteLinkAutocomplete({
    super.key,
    required this.textEditingController,
    required this.focusNode,
    required this.child,
    required this.linkParser,
    required this.notesRepository,
    this.maxSuggestions = 5,
  });

  final TextEditingController textEditingController;
  final FocusNode focusNode;
  final Widget child;
  final NoteLinkParser linkParser;
  final INotesRepository notesRepository;
  final int maxSuggestions;

  @override
  ConsumerState<NoteLinkAutocomplete> createState() =>
      _NoteLinkAutocompleteState();
}

class _NoteLinkAutocompleteState extends ConsumerState<NoteLinkAutocomplete> {
  OverlayEntry? _overlayEntry;
  List<domain.Note> _suggestions = [];
  int _selectedIndex = 0;
  String? _currentQuery;
  int? _atSignPosition;

  // Overlay configuration
  static const double _overlayMaxHeight = 200;
  static const double _itemHeight = 56;

  AppLogger get _logger => ref.read(loggerProvider);

  @override
  void initState() {
    super.initState();
    widget.textEditingController.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.textEditingController.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _hideOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onTextChanged() {
    final text = widget.textEditingController.text;
    final selection = widget.textEditingController.selection;

    // Only process if cursor is valid
    if (!selection.isValid || selection.baseOffset <= 0) {
      _hideOverlay();
      return;
    }

    final cursorPosition = selection.baseOffset;

    // Find @ sign before cursor
    int? atPos;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      final char = text[i];
      if (char == '@') {
        atPos = i;
        break;
      } else if (char == ' ' || char == '\n') {
        // Stop searching if we hit whitespace
        break;
      }
    }

    // No @ sign found, hide overlay
    if (atPos == null) {
      _hideOverlay();
      return;
    }

    // Extract query after @ sign
    final query = text.substring(atPos + 1, cursorPosition);

    // Query must be at least 1 character to trigger search
    if (query.isEmpty) {
      _hideOverlay();
      return;
    }

    // Check if query contains spaces (invalid for note links)
    if (query.contains(' ')) {
      _hideOverlay();
      return;
    }

    // Trigger search
    _atSignPosition = atPos;
    _currentQuery = query;
    _searchNotes(query);
  }

  Future<void> _searchNotes(String query) async {
    try {
      final results = await widget.linkParser.searchNotesByTitle(
        query,
        widget.notesRepository,
        limit: widget.maxSuggestions,
      );

      if (mounted && _currentQuery == query) {
        setState(() {
          _suggestions = results;
          _selectedIndex = 0;
        });

        if (results.isNotEmpty) {
          _logger.debug(
            'Note link autocomplete populated',
            data: {'query': query, 'results': results.length},
          );
        }

        if (_suggestions.isNotEmpty) {
          _showOverlay();
        } else {
          _hideOverlay();
        }
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Note link autocomplete search failed',
        error: error,
        stackTrace: stackTrace,
        data: {'query': query, 'maxSuggestions': widget.maxSuggestions},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      _hideOverlay();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Link suggestions failed. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_searchNotes(query)),
            ),
          ),
        );
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _suggestions = [];
    _currentQuery = null;
    _atSignPosition = null;
  }

  OverlayEntry _createOverlayEntry() {
    // Get text field render box for positioning
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return OverlayEntry(builder: (context) => const SizedBox.shrink());
    }

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx + 20, // Add padding
        top: offset.dy + size.height - 100, // Position above keyboard
        width: size.width - 40, // Account for padding
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: _overlayMaxHeight),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: _buildSuggestionsList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final note = _suggestions[index];
        final isSelected = index == _selectedIndex;

        return InkWell(
          onTap: () => _insertNoteLink(note),
          child: Container(
            height: _itemHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isSelected
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
            child: Row(
              children: [
                Icon(
                  Icons.note_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        note.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (note.body.isNotEmpty)
                        Text(
                          note.body,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_return,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _insertNoteLink(domain.Note note) {
    if (_atSignPosition == null) return;

    final text = widget.textEditingController.text;
    final cursorPos = widget.textEditingController.selection.baseOffset;

    // Replace @query with @[note-title]
    final beforeAt = text.substring(0, _atSignPosition!);
    final afterQuery = text.substring(cursorPos);
    final linkText = '@[${note.title}]';
    final newText = beforeAt + linkText + afterQuery;

    // Update text field
    widget.textEditingController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: beforeAt.length + linkText.length,
      ),
    );

    // Hide overlay
    _hideOverlay();

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Only handle key down events when overlay is visible
    if (_overlayEntry == null || _suggestions.isEmpty) {
      return false;
    }

    if (event is! KeyDownEvent) {
      return false;
    }

    // Handle arrow keys for navigation
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
      });
      _overlayEntry?.markNeedsBuild();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex =
            (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
      });
      _overlayEntry?.markNeedsBuild();
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      // Insert selected note link
      if (_selectedIndex < _suggestions.length) {
        _insertNoteLink(_suggestions[_selectedIndex]);
      }
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      // Hide overlay on escape
      _hideOverlay();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
