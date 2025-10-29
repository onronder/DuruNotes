import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
// Phase 3: Migrated to organized provider imports
import 'package:duru_notes/features/notes/providers/notes_state_providers.dart'
    show filteredNotesProvider, currentNotesProvider, notesPageProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// A robust pin toggle button widget
class PinToggleButton extends ConsumerStatefulWidget {
  const PinToggleButton({
    required this.noteId,
    required this.isPinned,
    super.key,
    this.size = 20,
    this.onToggled,
  });

  final String noteId;
  final bool isPinned;
  final double size;
  final VoidCallback? onToggled;

  @override
  ConsumerState<PinToggleButton> createState() => _PinToggleButtonState();
}

class _PinToggleButtonState extends ConsumerState<PinToggleButton> {
  static final AppLogger _logger = LoggerFactory.instance;
  static final Map<String, DateTime> _lastToggle = {};
  static const _debounceMs = 500;

  bool _isToggling = false;
  late bool _currentPinState;

  @override
  void initState() {
    super.initState();
    _currentPinState = widget.isPinned;
  }

  @override
  void didUpdateWidget(PinToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPinned != widget.isPinned) {
      _currentPinState = widget.isPinned;
    }
  }

  Future<void> _togglePin() async {
    // Debounce check
    final lastToggle = _lastToggle[widget.noteId];
    if (lastToggle != null) {
      final elapsed = DateTime.now().difference(lastToggle).inMilliseconds;
      if (elapsed < _debounceMs) {
        _logger.debug('Pin toggle debounced for note: ${widget.noteId}');
        return;
      }
    }

    // Update debounce tracker
    _lastToggle[widget.noteId] = DateTime.now();

    // Prevent concurrent toggles
    if (_isToggling) {
      _logger.debug(
        'Pin toggle already in progress for note: ${widget.noteId}',
      );
      return;
    }

    setState(() => _isToggling = true);

    try {
      // Haptic feedback
      await HapticFeedback.mediumImpact();

      // Calculate new state BEFORE any updates
      final newPinState = !_currentPinState;

      _logger.info(
        'Toggling pin for note ${widget.noteId}: $_currentPinState -> $newPinState',
      );

      // Optimistically update UI
      setState(() {
        _currentPinState = newPinState;
      });

      // Update database
      final notesRepo = ref.read(notesCoreRepositoryProvider);
      await notesRepo.setNotePin(widget.noteId, newPinState);

      // Force refresh of notes providers
      await Future.wait([
        Future(() => ref.invalidate(filteredNotesProvider)),
        Future(() => ref.invalidate(currentNotesProvider)),
        Future(() => ref.read(notesPageProvider.notifier).refresh()),
      ]);

      // Call callback if provided
      widget.onToggled?.call();

      // Show snackbar with CORRECT new state message
      if (mounted) {
        final message = newPinState ? 'Note pinned' : 'Note unpinned';

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newPinState ? Icons.push_pin : Icons.push_pin_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(message),
              ],
            ),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: newPinState
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
          ),
        );
      }

      _logger.debug('Pin toggle completed successfully');
    } catch (e, stack) {
      _logger.error('Failed to toggle pin', error: e, stackTrace: stack);
      unawaited(Sentry.captureException(e, stackTrace: stack));

      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _currentPinState = !_currentPinState;
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update pin status'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use current state for icon display
    final isPinned = _currentPinState;

    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          key: ValueKey(isPinned),
          size: widget.size,
          color: isPinned
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
      onPressed: _isToggling ? null : _togglePin,
      tooltip: isPinned ? 'Unpin note' : 'Pin note',
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: widget.size + 12,
        minHeight: widget.size + 12,
      ),
      splashRadius: widget.size,
      visualDensity: VisualDensity.compact,
    );
  }
}
