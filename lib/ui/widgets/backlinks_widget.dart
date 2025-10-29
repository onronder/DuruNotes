import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/services/note_link_parser.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Production-grade backlinks display widget
///
/// Shows all notes that link to the current note with:
/// - Expandable/collapsible section
/// - Note title and preview
/// - Context snippet showing where link appears
/// - Tap to navigate to linking note
/// - Material 3 design
class BacklinksWidget extends ConsumerStatefulWidget {
  const BacklinksWidget({
    super.key,
    required this.currentNoteId,
    required this.linkParser,
    required this.notesRepository,
    required this.onNavigateToNote,
    this.initiallyExpanded = false,
  });

  final String currentNoteId;
  final NoteLinkParser linkParser;
  final INotesRepository notesRepository;
  final void Function(String noteId) onNavigateToNote;
  final bool initiallyExpanded;

  @override
  ConsumerState<BacklinksWidget> createState() => _BacklinksWidgetState();
}

class _BacklinksWidgetState extends ConsumerState<BacklinksWidget> {
  bool _isExpanded = false;
  bool _isLoading = false;
  List<domain.Note> _backlinks = [];
  String? _error;

  AppLogger get _logger => ref.read(loggerProvider);

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _loadBacklinks();
  }

  @override
  void didUpdateWidget(BacklinksWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if note ID changed
    if (oldWidget.currentNoteId != widget.currentNoteId) {
      _loadBacklinks();
    }
  }

  Future<void> _loadBacklinks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final backlinks = await widget.linkParser.getBacklinks(
        widget.currentNoteId,
        widget.notesRepository,
      );

      if (mounted) {
        setState(() {
          _backlinks = backlinks;
          _isLoading = false;
        });

        _logger.debug(
          'Loaded backlinks for note',
          data: {'noteId': widget.currentNoteId, 'count': backlinks.length},
        );
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load backlinks',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': widget.currentNoteId},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        setState(() {
          _error = 'Failed to load backlinks';
          _isLoading = false;
        });
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to load backlinks. Please try again.'),
            backgroundColor: theme.colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_loadBacklinks()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Don't show widget if there are no backlinks and not loading
    if (_backlinks.isEmpty && !_isLoading && _error == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Header with expand/collapse
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.link,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backlinks',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isLoading
                              ? 'Loading...'
                              : _error != null
                                  ? _error!
                                  : '${_backlinks.length} ${_backlinks.length == 1 ? 'note links' : 'notes link'} here',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _error != null
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    )
                  else
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),

          // Backlinks list (when expanded)
          if (_isExpanded && !_isLoading && _error == null)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _buildBacklinksList(theme, colorScheme),
            ),

          // Error state with retry
          if (_isExpanded && _error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: colorScheme.error,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadBacklinks,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBacklinksList(ThemeData theme, ColorScheme colorScheme) {
    if (_backlinks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No backlinks found',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _backlinks.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
      itemBuilder: (context, index) {
        final note = _backlinks[index];
        return _buildBacklinkItem(note, theme, colorScheme);
      },
    );
  }

  Widget _buildBacklinkItem(
    domain.Note note,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Extract context snippet (first 100 chars of body)
    final snippet = note.body.length > 100
        ? '${note.body.substring(0, 100)}...'
        : note.body;

    return InkWell(
      onTap: () => widget.onNavigateToNote(note.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.note_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),

            // Note content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Note title
                  Text(
                    note.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Context snippet
                  if (snippet.isNotEmpty)
                    Text(
                      snippet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Metadata
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(note.updatedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation arrow
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }
}
