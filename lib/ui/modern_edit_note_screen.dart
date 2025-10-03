import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:duru_notes/core/formatting/markdown_commands.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/features/folders/folder_picker_sheet.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/ui/widgets/email_attachments_section.dart';
import 'package:duru_notes/ui/widgets/note_tag_chips.dart';
import 'package:duru_notes/features/templates/template_gallery_screen.dart';
import 'package:duru_notes/features/templates/template_variable_dialog.dart';
import 'package:duru_notes/models/template_model.dart';
import 'package:duru_notes/services/template_variable_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../theme/cross_platform_tokens.dart';

/// Modern Material 3 Note Editor with Unified Field (E2.9)
/// Single text field design where first line becomes the title
class ModernEditNoteScreen extends ConsumerStatefulWidget {
  const ModernEditNoteScreen({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialBody,
    this.initialFolder,
    this.isEditingTemplate = false,
    this.highlightTaskId,
    this.highlightTaskContent,
  });

  final String? noteId;
  final String? initialTitle;
  final String? initialBody;
  final LocalFolder? initialFolder;
  final bool isEditingTemplate;
  final String? highlightTaskId;
  final String? highlightTaskContent;

  @override
  ConsumerState<ModernEditNoteScreen> createState() =>
      _ModernEditNoteScreenState();
}

class _ModernEditNoteScreenState extends ConsumerState<ModernEditNoteScreen>
    with TickerProviderStateMixin {
  // EDITOR_V2: unified controller
  late final TextEditingController _noteController;
  final FocusNode _contentFocusNode = FocusNode();

  // Animation Controllers
  late AnimationController _toolbarSlideController;
  late Animation<Offset> _toolbarSlideAnimation;
  late AnimationController _saveButtonController;
  late Animation<double> _saveButtonScale;

  // State
  bool _hasChanges = false;
  bool _isLoading = false;
  bool _contentHasFocus = false;
  bool _showFormattingToolbar = false;
  bool _isPreviewMode = false;
  bool _isPinned = false; // Track pin state
  LocalFolder? _selectedFolder;
  String? _initialText;
  late String _noteIdForTags; // Either real ID or temp ID for tags
  List<String> _currentTags = [];

  // AI Assistant State
  bool _showAISuggestions = false;
  String? _aiSuggestion;
  bool _isAIProcessing = false;

  // Material-3 Design Constants
  static const double kHeaderHeight = 64;
  static const double kToolbarIconSize = 22;
  static const double kMinTapTarget = 44;
  static const double kScreenPadding = 20;
  static const double kContentPadding = 20;
  static const double kVerticalSpacingLarge = 16;
  static const double kVerticalSpacingMedium = 12;
  // static const double kVerticalSpacingSmall = 8; // Currently unused

  @override
  void initState() {
    super.initState();

    final initialTitle = widget.initialTitle?.trimRight() ?? '';
    final initialBody = widget.initialBody ?? '';
    final initialText =
        initialTitle.isNotEmpty ? '$initialTitle\n$initialBody' : initialBody;

    _noteController = TextEditingController(text: initialText);
    _initialText = initialText;

    // Highlight task if specified
    if (widget.highlightTaskId != null || widget.highlightTaskContent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _highlightTask();
      });
    }

    // Initialize bidirectional task sync for existing notes
    if (widget.noteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          try {
            // Use only bidirectional sync - legacy sync is deprecated
            ref
                .read(unifiedTaskServiceProvider)
                .startWatchingNote(widget.noteId!);
          } catch (e) {
            debugPrint('Could not start task sync: $e');
          }
        }
      });
    }

    _noteController.addListener(() {
      // mark dirty only on first mutation, still rebuild for stats
      final wasPristine = !_hasChanges;
      final becameDirty = _noteController.text != _initialText;
      if (wasPristine && becameDirty) {
        setState(() => _hasChanges = true);
      } else if (!becameDirty && _hasChanges) {
        setState(() => _hasChanges = false);
      } else {
        setState(() {}); // keep toolbar/stats reactive
      }
    });

    // REMOVED: Legacy task sync - now handled by bidirectional sync above
    // The unifiedTaskServiceProvider.startWatchingNote() call at line 95
    // already handles initial sync via initializeBidirectionalSync()

    // Animation setup for toolbar slide with Material-3 timing
    _toolbarSlideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _toolbarSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _toolbarSlideController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    // Animation for save button with Material-3 timing
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _saveButtonScale = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(parent: _saveButtonController, curve: Curves.easeInOut),
    );

    // Focus listener for animation triggers
    _contentFocusNode.addListener(() {
      setState(() {
        _contentHasFocus = _contentFocusNode.hasFocus;
        _showFormattingToolbar = _contentFocusNode.hasFocus;
        if (_contentFocusNode.hasFocus) {
          _toolbarSlideController.forward();
        } else {
          _toolbarSlideController.reverse();
        }
      });
    });

    // Initialize folder selection
    _initializeFolder();

    // Setup note ID for tags (real or temp)
    _noteIdForTags = widget.noteId ?? 'note_draft_${const Uuid().v4()}';

    // Load metadata for existing notes
    if (widget.noteId != null) {
      _loadNoteMetadata();
    }
  }

  Future<void> _loadNoteMetadata() async {
    if (widget.noteId == null) return;

    try {
      final note =
          await ref.read(notesRepositoryProvider).getNote(widget.noteId!);
      if (note != null && mounted) {
        // Load pin state
        setState(() {
          _isPinned = note.isPinned;
        });

        // Load existing tags
        final tags = await ref
            .read(notesRepositoryProvider)
            .getTagsForNote(widget.noteId!);
        if (mounted) {
          setState(() {
            _currentTags = tags.cast<String>();
          });
        }
      }
    } catch (e) {
      // Silently fail - metadata is not critical
    }
  }

  Future<void> _initializeFolder() async {
    // If initialFolder is provided, use it
    if (widget.initialFolder != null) {
      setState(() {
        _selectedFolder = widget.initialFolder;
      });
    }
    // For existing notes, fetch the folder
    else if (widget.noteId != null) {
      try {
        final folder = await ref
            .read(noteFolderProvider.notifier)
            .getFolderForNote(widget.noteId!);
        if (mounted) {
          setState(() {
            _selectedFolder = folder;
          });
        }
      } on Exception catch (e) {
        // If error fetching folder, treat as unfiled
        debugPrint('Error fetching folder for note: $e');
      }
    }
  }

  /// Highlight the specified task in the note
  void _highlightTask() {
    if (widget.highlightTaskContent == null) return;

    final text = _noteController.text;
    final searchPattern = widget.highlightTaskContent!;

    // Find the task in the text
    final taskIndex = text.indexOf(searchPattern);
    if (taskIndex != -1) {
      // Set selection to highlight the task
      _noteController.selection = TextSelection(
        baseOffset: taskIndex,
        extentOffset: taskIndex + searchPattern.length,
      );

      // Ensure the text field is focused
      _contentFocusNode.requestFocus();

      // Show a visual indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Opened from task reminder'),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Dispose controllers first
    _noteController.dispose();
    _contentFocusNode.dispose();
    _toolbarSlideController.dispose();
    _saveButtonController.dispose();

    // Stop watching note for task sync - do this after controllers but before super.dispose()
    if (widget.noteId != null) {
      // Schedule the cleanup for the next frame to avoid using ref during disposal
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          // Check if the widget is still mounted before using ref
          if (context.owner != null) {
            final coordinator = ref.read(unifiedTaskServiceProvider);
            coordinator.stopWatchingNote(widget.noteId!);
          }
        } catch (e) {
          // Widget already disposed or provider not available, ignore
          debugPrint('Could not stop watching note: $e');
        }
      });
    }

    // Clean up temp tags if note was discarded
    if (widget.noteId == null && _noteIdForTags.startsWith('note_draft_')) {
      // Schedule cleanup for next frame to avoid ref usage during disposal
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cleanupTempTags();
      });
    }

    super.dispose();
  }

  Future<void> _cleanupTempTags() async {
    // Skip cleanup - temp tags will be cleaned up by database maintenance
    // We can't use ref here as the widget might be disposed
    debugPrint('Skipping temp tag cleanup for $_noteIdForTags');
  }

  Future<void> _remapTempTags(String realNoteId) async {
    try {
      // Update all temp tags to use the real note ID
      final db = ref.read(notesRepositoryProvider).db;
      await (db.update(db.noteTags)
            ..where((t) => t.noteId.equals(_noteIdForTags)))
          .write(NoteTagsCompanion(noteId: Value(realNoteId)));

      // Update our local reference
      _noteIdForTags = realNoteId;
    } catch (e) {
      // If remapping fails, try to ensure tags are saved with the real ID
      for (final tag in _currentTags) {
        try {
          await ref
              .read(notesRepositoryProvider)
              .addTag(realNoteId, tag);
        } catch (_) {
          // Continue with other tags even if one fails
        }
      }
    }
  }

  ({String title, String body}) _splitTitleBody(String raw) {
    // do not trim leading spaces in body; trim only trailing for clean save
    final text = raw.trimRight();
    if (text.isEmpty) return (title: '', body: '');
    final nl = text.indexOf('\n');
    if (nl == -1) return (title: text, body: '');
    final title = text.substring(0, nl);
    final body = text.substring(nl + 1);
    return (title: title, body: body);
  }

  // keep your existing title sanitizer; if missing, provide a light one:
  String _stripMarkdownHeading(String input) {
    // remove leading markdown heading markers like "#", "##", "-" spaces
    return input.replaceFirst(RegExp(r'^\s{0,3}(#{1,6}\s+|-{1,}\s+)'), '');
  }

  // Get display title for preview mode
  String _getDisplayTitle() {
    final parts = _splitTitleBody(_noteController.text);
    final cleanTitle = _stripMarkdownHeading(parts.title).trim();
    return cleanTitle.isEmpty ? 'Untitled Note' : cleanTitle;
  }

  // Get body content for preview mode
  String _getBodyContent() {
    final parts = _splitTitleBody(_noteController.text);
    return parts.body;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: !_hasChanges && !_isLoading,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges && !_isLoading) {
          final shouldPop = await _showDiscardDialog();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text(widget.isEditingTemplate
              ? AppLocalizations.of(context).editingTemplate
              : (widget.noteId == null ? 'New Note' : 'Edit Note')),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  DuruColors.primary,
                  DuruColors.accent,
                ],
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.arrow_left, color: Colors.white),
            onPressed: () async {
              if (_hasChanges) {
                final shouldLeave = await _showDiscardDialog();
                if (shouldLeave && mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            // Template button - only for new notes
            if (widget.noteId == null && !widget.isEditingTemplate)
              IconButton(
                icon: Icon(
                  CupertinoIcons.doc_text,
                  color: Colors.white,
                ),
                onPressed: _showTemplatePicker,
                tooltip: 'Use Template',
              ),
            // AI Assistant Toggle
            IconButton(
              icon: Icon(
                CupertinoIcons.sparkles,
                color: _showAISuggestions
                    ? const Color(0xFF9333EA)
                    : Colors.white.withValues(alpha: 0.7),
              ),
              onPressed: () {
                setState(() {
                  _showAISuggestions = !_showAISuggestions;
                });
                HapticFeedback.lightImpact();
                if (_showAISuggestions) {
                  _requestAISuggestion();
                }
              },
              tooltip: 'AI Assistant',
            ),
            // Preview toggle
            IconButton(
              icon: Icon(
                _isPreviewMode
                    ? CupertinoIcons.pencil
                    : CupertinoIcons.eye,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() => _isPreviewMode = !_isPreviewMode);
                HapticFeedback.lightImpact();
              },
              tooltip: _isPreviewMode ? 'Edit' : 'Preview',
            ),
            // Save button
            if (_hasChanges)
              IconButton(
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white),
                onPressed: _isLoading ? null : () => _saveNote(),
                tooltip: 'Save',
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [

              // AI Suggestion Card
              _buildAISuggestionCard(theme, colorScheme),

              // Animated formatting toolbar with glass effect
              AnimatedBuilder(
                animation: _toolbarSlideAnimation,
                builder: (context, child) {
                  return SlideTransition(
                    position: _toolbarSlideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.9),
                        border: Border(
                          bottom: BorderSide(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: _buildFormattingToolbar(colorScheme),
                    ),
                  );
                },
              ),

              // Main content area with animation
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.02, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _isPreviewMode
                      ? _buildPreview(theme, colorScheme)
                      : _buildEditor(theme, colorScheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // AI Suggestion methods
  Future<void> _requestAISuggestion() async {
    if (_isAIProcessing || _noteController.text.isEmpty) return;

    setState(() {
      _isAIProcessing = true;
    });

    // Simulate AI processing (replace with actual AI service call)
    await Future<void>.delayed(const Duration(seconds: 1));

    setState(() {
      _aiSuggestion = _generateContextualSuggestion();
      _isAIProcessing = false;
    });
  }

  String _generateContextualSuggestion() {
    final text = _noteController.text.toLowerCase();

    // Context-aware suggestions based on content
    if (text.contains('meeting')) {
      return 'Add action items from the meeting?';
    } else if (text.contains('todo') || text.contains('task')) {
      return 'Convert to checklist format?';
    } else if (text.contains('idea')) {
      return 'Expand on this idea with more details?';
    } else if (text.length < 50) {
      return 'Add more context to your note?';
    } else {
      return 'Organize with headings and sections?';
    }
  }

  Widget _buildAISuggestionCard(ThemeData theme, ColorScheme colorScheme) {
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showAISuggestions ? null : 0,
      child: _showAISuggestions
          ? Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF9333EA).withValues(alpha: 0.1),
                    const Color(0xFF3B82F6).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9333EA).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.sparkles,
                          size: 16,
                          color: const Color(0xFF9333EA),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Suggestion',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF9333EA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_isAIProcessing)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF9333EA),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_aiSuggestion != null && !_isAIProcessing) ...[
                    Text(
                      _aiSuggestion!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            // Apply AI suggestion
                            HapticFeedback.lightImpact();
                            _applyAISuggestion();
                          },
                          icon: Icon(
                            CupertinoIcons.checkmark_circle,
                            size: 16,
                          ),
                          label: Text('Accept'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF9333EA),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _requestAISuggestion();
                          },
                          icon: Icon(
                            CupertinoIcons.refresh,
                            size: 16,
                          ),
                          label: Text('Try Another'),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  void _applyAISuggestion() {
    // Implement suggestion application logic
    final text = _noteController.text;

    if (_aiSuggestion?.contains('checklist') == true) {
      // Convert to checklist
      final lines = text.split('\n');
      final checklist = lines.map((line) => '- [ ] $line').join('\n');
      _noteController.text = checklist;
    } else if (_aiSuggestion?.contains('headings') == true) {
      // Add structure
      final parts = _splitTitleBody(text);
      _noteController.text = '# ${parts.title}\n\n## Overview\n${parts.body}';
    }

    setState(() {
      _showAISuggestions = false;
      _aiSuggestion = null;
    });
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: isActive
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: const BoxConstraints(
          minWidth: kMinTapTarget,
          minHeight: kMinTapTarget,
        ),
      ),
    );
  }

  Widget _buildQuickActionBar(ThemeData theme, ColorScheme colorScheme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DuruColors.primary.withValues(alpha: 0.05),
            DuruColors.accent.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Row(
        children: [
          // Folder selector
          _buildQuickAction(
            icon: CupertinoIcons.folder,
            label: _selectedFolder?.name ?? 'No Folder',
            onTap: () => _showFolderPicker(context),
            color: DuruColors.primary,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          // Pin toggle (for existing notes)
          if (widget.noteId != null)
            _buildQuickAction(
              icon: _isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
              label: _isPinned ? 'Pinned' : 'Pin',
              onTap: () {
                setState(() => _isPinned = !_isPinned);
                HapticFeedback.lightImpact();
              },
              color: _isPinned ? DuruColors.accent : Colors.grey,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
      );
    }

    final isEnabled = _hasChanges;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? _saveNote : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: isEnabled
                ? LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isEnabled ? null : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnabled ? Icons.save_rounded : Icons.check_rounded,
                size: 18,
                color: isEnabled
                    ? colorScheme.onPrimary
                    : colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                isEnabled ? 'Save' : 'Done',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isEnabled
                      ? colorScheme.onPrimary
                      : colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(ThemeData theme, ColorScheme colorScheme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: const Key('editor'),
      padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
      child: Column(
        children: [
          const SizedBox(height: kVerticalSpacingMedium),

          // Folder and tag section side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Folder indicator chip
              _buildFolderIndicator(colorScheme),
              const SizedBox(width: 12),
              // Tag chips (expanded to fill remaining space)
              Expanded(
                child: NoteTagChips(
                  noteId: _noteIdForTags,
                  initialTags: _currentTags,
                  onTagsChanged: (tags) {
                    setState(() {
                      _currentTags = tags;
                      // Mark as changed if tags differ from initial
                      if (widget.noteId != null) {
                        _hasChanges = true;
                      }
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Unified text field with glass morphism
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _contentHasFocus
                      ? [
                          DuruColors.primary.withValues(alpha: 0.05),
                          DuruColors.accent.withValues(alpha: 0.02),
                        ]
                      : [
                          Colors.white.withValues(alpha: isDark ? 0.05 : 0.95),
                          Colors.white.withValues(alpha: isDark ? 0.03 : 0.9),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _contentHasFocus
                      ? DuruColors.primary.withValues(alpha: 0.3)
                      : (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.1),
                  width: _contentHasFocus ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _noteController,
                        focusNode: _contentFocusNode,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.7,
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Note title\n\nStart writing your thoughts...\n\n'
                              'First line becomes the title',
                          hintStyle: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.7,
                            color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.4),
                            fontSize: 16,
                          ),
                          contentPadding: const EdgeInsets.all(24),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                      ),
                      // Add attachments section if available
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kContentPadding,
                        ),
                        child: _buildAttachmentsIfAny(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsIfAny() {
    // Check if this note has persistent metadata with attachments
    if (widget.noteId == null) {
      return const SizedBox.shrink();
    }

    // Get note from repository to access persistent metadata
    return FutureBuilder<LocalNote?>(
      future: ref.read(notesRepositoryProvider).getNote(widget.noteId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.encryptedMetadata == null) {
          return const SizedBox.shrink();
        }

        try {
          final meta = jsonDecode(snapshot.data!.encryptedMetadata!);

          final raw = (meta['attachments']?['files'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              const [];

          final files = raw
              .map(
                (m) => EmailAttachmentRef(
                  path: (m['path'] as String?) ?? '',
                  filename: (m['filename'] as String?) ??
                      _inferFilename((m['path'] as String?) ?? ''),
                  mimeType:
                      (m['type'] as String?) ?? 'application/octet-stream',
                  sizeBytes: (m['size'] as num?)?.toInt() ?? 0,
                ),
              )
              .where((f) => f.path.isNotEmpty)
              .toList(growable: false);

          if (files.isEmpty) {
            return const SizedBox.shrink();
          }

          return EmailAttachmentsSection(files: files);
        } catch (e) {
          // Error parsing metadata
          return const SizedBox.shrink();
        }
      },
    );
  }

  String _inferFilename(String path) {
    final i = path.lastIndexOf('/');
    if (i >= 0 && i < path.length - 1) {
      return path.substring(i + 1);
    }
    return path;
  }

  Widget _buildPreview(ThemeData theme, ColorScheme colorScheme) {
    final displayTitle = _getDisplayTitle();
    final bodyContent = _getBodyContent();

    return DecoratedBox(
      key: const Key('preview'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surface.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(kScreenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title display in preview
            Text(
              displayTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: kVerticalSpacingLarge),

            // Gradient separator
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.3),
                    colorScheme.secondary.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: kVerticalSpacingLarge),

            // Body content rendered as Markdown
            if (bodyContent.isNotEmpty)
              MarkdownBody(
                data: bodyContent,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.7,
                    color: colorScheme.onSurface,
                  ),
                  code: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    backgroundColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    color: colorScheme.onPrimaryContainer,
                  ),
                  blockquote: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Text(
                'No content',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattingToolbar(ColorScheme colorScheme) {
    if (!_showFormattingToolbar || _isPreviewMode) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
        child: Row(
          children: [
            // Text formatting group
            _buildToolButton(
              icon: Icons.format_bold_rounded,
              tooltip: 'Bold (⌘B)',
              onPressed: () => _executeCommand(BoldCommand()),
              colorScheme: colorScheme,
            ),
            _buildToolButton(
              icon: Icons.format_italic_rounded,
              tooltip: 'Italic (⌘I)',
              onPressed: () => _executeCommand(ItalicCommand()),
              colorScheme: colorScheme,
            ),
            _buildToolButton(
              icon: Icons.format_size_rounded,
              tooltip: 'Heading',
              onPressed: _showHeadingMenu,
              onLongPress: () => _executeCommand(HeadingCommand()),
              colorScheme: colorScheme,
            ),

            _buildToolDivider(colorScheme),

            // List formatting group
            _buildToolButton(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Bullet List',
              onPressed: () =>
                  _executeCommand(ListCommand(type: ListType.bullet)),
              colorScheme: colorScheme,
            ),
            _buildToolButton(
              icon: Icons.format_list_numbered_rounded,
              tooltip: 'Numbered List',
              onPressed: () =>
                  _executeCommand(ListCommand(type: ListType.numbered)),
              colorScheme: colorScheme,
            ),
            _buildToolButton(
              icon: Icons.checklist_rounded,
              tooltip: 'Checklist',
              onPressed: () =>
                  _executeCommand(ListCommand(type: ListType.checkbox)),
              colorScheme: colorScheme,
            ),

            _buildToolDivider(colorScheme),

            // Advanced formatting group
            _buildToolButton(
              icon: Icons.code_rounded,
              tooltip: 'Code',
              onPressed: _showCodeMenu,
              onLongPress: () => _executeCommand(CodeCommand(isBlock: true)),
              colorScheme: colorScheme,
            ),
            _buildToolButton(
              icon: Icons.format_quote_rounded,
              tooltip: 'Quote',
              onPressed: () => _executeCommand(QuoteCommand()),
              colorScheme: colorScheme,
            ),
            _buildToolButton(
              icon: Icons.link_rounded,
              tooltip: 'Insert Link',
              onPressed: _showLinkDialog,
              colorScheme: colorScheme,
            ),
            _buildToolButton(
              icon: Icons.image_rounded,
              tooltip: 'Insert Image',
              onPressed: _insertImage,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    VoidCallback? onLongPress,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: kMinTapTarget,
              minHeight: kMinTapTarget,
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: kToolbarIconSize,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolDivider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: colorScheme.outlineVariant,
    );
  }

  void _insertMarkdown(String prefix, String suffix) {
    final text = _noteController.text;
    final selection = _noteController.selection;
    final start = selection.start;
    final end = selection.end;

    if (start >= 0 && end >= 0) {
      final selectedText = text.substring(start, end);
      final newText = text.replaceRange(
        start,
        end,
        '$prefix$selectedText$suffix',
      );

      _noteController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: start + prefix.length + selectedText.length,
        ),
      );

      HapticFeedback.lightImpact();
    }
  }

  void _insertList(String listType) {
    final text = _noteController.text;
    final selection = _noteController.selection;
    final position = selection.start;

    String prefix;
    switch (listType) {
      case 'bullet':
        prefix = '- '; // PRODUCTION FIX: Use standard Markdown bullet
      case 'numbered':
        prefix = '1. ';
      case 'checkbox':
        prefix = '- [ ] ';
      default:
        prefix = '- ';
    }

    // Find line start
    var lineStart = position;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final newText = text.replaceRange(lineStart, lineStart, prefix);

    _noteController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: position + prefix.length),
    );

    HapticFeedback.lightImpact();
  }

  // PRODUCTION ENHANCEMENT: Execute formatting commands with undo support
  void _executeCommand(MarkdownCommand command) {
    // Track analytics
    ref.read(analyticsProvider).event(
      'editor.formatting',
      properties: {
        'command': command.analyticsName,
        'selection_length':
            _noteController.selection.end - _noteController.selection.start,
      },
    );

    // Execute command
    command.execute(_noteController);

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Mark as modified
    _hasChanges = true;
  }

  // PRODUCTION ENHANCEMENT: Show heading level menu
  void _showHeadingMenu() {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        for (int level = 1; level <= 6; level++)
          PopupMenuItem(
            value: level,
            child: Text('Heading $level (${'#' * level})'),
          ),
      ],
    ).then((level) {
      if (level != null) {
        _executeCommand(HeadingCommand(level: level));
      }
    });
  }

  // PRODUCTION ENHANCEMENT: Show code type menu
  void _showCodeMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Inline Code'),
              subtitle: const Text('For short code snippets'),
              onTap: () {
                Navigator.pop(context);
                _executeCommand(CodeCommand());
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_off),
              title: const Text('Code Block'),
              subtitle: const Text('For multiple lines of code'),
              onTap: () {
                Navigator.pop(context);
                _executeCommand(CodeCommand(isBlock: true));
              },
            ),
          ],
        ),
      ),
    );
  }

  // PRODUCTION ENHANCEMENT: Show link insertion dialog
  void _showLinkDialog() {
    final selectedText = _noteController.selection.isCollapsed
        ? ''
        : _noteController.text.substring(
            _noteController.selection.start,
            _noteController.selection.end,
          );

    final urlController = TextEditingController();
    final textController = TextEditingController(text: selectedText);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Link Text',
                hintText: 'Enter link text',
              ),
              autofocus: selectedText.isEmpty,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://',
              ),
              keyboardType: TextInputType.url,
              autofocus: selectedText.isNotEmpty,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _executeCommand(
                LinkCommand(url: urlController.text, text: textController.text),
              );
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  // PRODUCTION ENHANCEMENT: Insert image from device
  Future<void> _insertImage() async {
    try {
      final attachmentService = ref.read(attachmentServiceProvider);

      // Pick and upload image
      final result = await attachmentService.pickAndUpload();

      if (result != null && result.url != null) {
        final url = result.url!;
        final filename = result.fileName;

        // Insert markdown image
        final markdown = '![$filename]($url)';
        final position = _noteController.selection.start;
        final text = _noteController.text;

        _noteController.value = TextEditingValue(
          text: text.replaceRange(position, position, markdown),
          selection: TextSelection.collapsed(
            offset: position + markdown.length,
          ),
        );

        // Track analytics
        ref.read(analyticsProvider).event(
          'editor.image_inserted',
          properties: {'source': 'toolbar', 'size': result.fileSize},
        );

        // Mark as modified
        _hasChanges = true;

        // Show success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error inserting image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to insert image: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildFolderIndicator(ColorScheme colorScheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showFolderPicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _selectedFolder != null ? Icons.folder : Icons.folder_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                _selectedFolder?.name ?? 'Select folder',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFolderPicker(BuildContext context) async {
    HapticFeedback.lightImpact();

    final folder = await showModalBottomSheet<LocalFolder?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          FolderPickerSheet(selectedFolderId: _selectedFolder?.id),
    );

    if (folder != null && mounted) {
      setState(() {
        _selectedFolder = folder;
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveNote() async {
    if (_isLoading) return;

    final raw = _noteController.text;
    final parts = _splitTitleBody(raw);

    final cleanTitle = _stripMarkdownHeading(parts.title).trim();
    final cleanBody = parts.body;

    final isCompletelyEmpty = cleanTitle.isEmpty && cleanBody.trim().isEmpty;
    if (isCompletelyEmpty) {
      _showInfoSnack('Add some content first');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(notesRepositoryProvider);

      final savedNote = await repo.createOrUpdate(
        id: widget.noteId,
        title: cleanTitle.isEmpty ? 'Untitled Note' : cleanTitle,
        body: cleanBody,
        isPinned: _isPinned, // CRITICAL FIX: Pass current pin state when saving
      );

      // handle folder assignment
      final noteIdToUse = savedNote?.id ?? widget.noteId;
      if (noteIdToUse != null) {
        // Initialize task sync for newly saved notes
        if (widget.noteId == null && mounted) {
          try {
            // Use only bidirectional sync - legacy sync is deprecated
            ref
                .read(unifiedTaskServiceProvider)
                .startWatchingNote(noteIdToUse);
          } catch (e) {
            debugPrint('Could not start task sync for new note: $e');
          }
        }
        if (_selectedFolder != null) {
          await ref
              .read(noteFolderProvider.notifier)
              .addNoteToFolder(noteIdToUse, _selectedFolder!.id);
        } else if (widget.noteId == null) {
          // ensure brand-new notes are not left with stale mapping
          await ref
              .read(noteFolderProvider.notifier)
              .removeNoteFromFolder(noteIdToUse);
        }

        // Remap temp tags to real note ID if this was a new note
        if (widget.noteId == null && _noteIdForTags.startsWith('note_draft_')) {
          await _remapTempTags(noteIdToUse);
        }
      }

      // refresh list & try sync; failures here must not block navigation
      await ref.read(notesPageProvider.notifier).refresh();
      try {
        await ref.read(syncModeProvider.notifier).manualSync();
      } catch (_) {
        // sync failures are non-critical
      }

      if (!mounted) return;
      setState(() {
        _hasChanges = false;
        _initialText = _noteController.text;
      });
      Navigator.of(context).pop(); // go back to list
    } catch (e) {
      _showErrorSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_isLoading) return;

    final raw = _noteController.text;
    final parts = _splitTitleBody(raw);

    final cleanTitle = _stripMarkdownHeading(parts.title).trim();
    final cleanBody = parts.body;

    if (cleanTitle.isEmpty && cleanBody.trim().isEmpty) {
      _showErrorSnack(AppLocalizations.of(context).cannotSaveEmptyTemplate);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the template repository
      final templateRepository = ref.read(templateRepositoryProvider);

      // Create the user template
      final template = await templateRepository.createUserTemplate(
        cleanTitle.isEmpty ? 'Untitled Template' : cleanTitle,
        cleanBody,
        metadata: {
          'tags': _currentTags,
          'category': 'personal',
          'description': 'Template created from note',
          'icon': 'description',
          'createdFrom': widget.noteId ?? 'new_note',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      if (template.isEmpty) {
        throw Exception('Failed to create template');
      }

      // Track analytics event
      final analytics = ref.read(analyticsProvider);
      analytics.event('template_saved', properties: {
        'template_id': template,
        'source_note_id': widget.noteId ?? 'new_note',
        'tags_count': _currentTags.length,
        'has_body': cleanBody.isNotEmpty,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      // Show success message
      _showInfoSnack(
          AppLocalizations.of(context).templateSaved(cleanTitle.isEmpty ? 'Untitled Template' : cleanTitle));

      // Optional: Navigate back or stay for further editing
      // Navigator.of(context).pop();
    } catch (e, stackTrace) {
      // Log error to monitoring
      final logger = LoggerFactory.instance;
      logger.error('Failed to save template',
          error: e,
          stackTrace: stackTrace,
          data: {
            'noteId': widget.noteId,
            'title': cleanTitle,
            'bodyLength': cleanBody.length,
          });

      _showErrorSnack(AppLocalizations.of(context).failedToSaveTemplate);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInfoSnack(String message) {
    if (!mounted) return;

    // Clear any existing snackbars first
    ScaffoldMessenger.of(context).clearSnackBars();

    // Use a slight delay to ensure the UI is ready
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<bool> _showDiscardDialog() async {
    HapticFeedback.lightImpact();

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
              'You have unsaved changes. Are you sure you want to leave?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Discard',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Template picker and application
  Future<void> _showTemplatePicker() async {
    try {
      // Navigate to template gallery screen
      final Template? selectedTemplate = await Navigator.push<Template>(
        context,
        MaterialPageRoute<Template>(
          builder: (context) => const TemplateGalleryScreen(
            selectMode: true, // Enable selection mode
          ),
        ),
      );

      if (selectedTemplate != null && mounted) {
        // Apply the template
        await _applyTemplate(selectedTemplate);
      }
    } catch (e) {
      debugPrint('Error showing template picker: $e');
      _showErrorSnack('Failed to load templates');
    }
  }

  Future<void> _applyTemplate(Template template) async {
    try {
      debugPrint('🔧 Applying template: ${template.title}');
      final variableService = TemplateVariableService();

      // Extract variables from template
      final variables = variableService.extractVariables(template.body);
      debugPrint('🔧 Extracted ${variables.length} variables');

      String processedContent = template.body;

      // If template has variables, show input dialog
      if (variables.isNotEmpty) {
        debugPrint('🔧 Showing variable dialog for ${variables.length} variables');
        final values = await TemplateVariableDialog.show(
          context,
          variables: variables,
          templateTitle: template.title,
        );

        if (values == null) {
          debugPrint('🔧 User cancelled variable dialog');
          return; // User cancelled
        }

        debugPrint('🔧 User provided values: ${values.keys.length}');
        // Replace variables with user values
        processedContent = variableService.replaceVariables(template.body, values);
      } else {
        debugPrint('🔧 No variables, replacing system variables only');
        // No variables, just replace system variables
        processedContent = variableService.replaceVariables(template.body, {});
      }

      debugPrint('🔧 Processed content ready, applying to editor');
      // Apply template content to editor
      setState(() {
        // Combine template title and processed body
        final newContent = '${template.title}\n${processedContent}';
        _noteController.text = newContent;
        _hasChanges = true;

        // Apply template tags if any
        if (template.tags.isNotEmpty) {
          _currentTags.addAll(template.tags);
        }

        // Set template category as folder if applicable
        // This could be enhanced to map template categories to folders
      });

      debugPrint('🔧 Template applied to editor successfully');
      // Show success message
      _showInfoSnack('Template applied successfully');

      // Track analytics
      try {
        ref.read(analyticsProvider).event(
          'template.applied',
          properties: {
            'template_id': template.id,
            'template_title': template.title,
            'has_variables': variables.isNotEmpty,
          },
        );
      } catch (analyticsError) {
        debugPrint('Analytics error: $analyticsError');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error applying template: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _showErrorSnack('Failed to apply template: ${e.toString()}');
    }
  }
}
