import 'dart:async';
import 'dart:convert';

import 'package:duru_notes/core/formatting/markdown_commands.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/monitoring/trace_context.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/l10n/app_localizations.dart';
// Sprint 1 Block Parsing Fix: Import block editor and parser
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/parser/note_block_parser.dart';
import 'package:duru_notes/models/note_block.dart';
import 'package:duru_notes/ui/widgets/blocks/unified_block_editor.dart'
    as unified;
import 'package:duru_notes/features/folders/folder_picker_sheet.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show noteLinkParserProvider, notesCoreRepositoryProvider;
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart'
    show noteFolderProvider;
import 'package:duru_notes/services/providers/services_providers.dart'
    show attachmentServiceProvider, quickCaptureServiceProvider, voiceTranscriptionServiceProvider;
import 'package:duru_notes/services/permission_manager.dart';
import 'package:duru_notes/services/voice_transcription_service.dart' show DictationLocale;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duru_notes/features/notes/providers/notes_pagination_providers.dart'
    show notesPageProvider;
import 'package:duru_notes/features/sync/providers/sync_providers.dart'
    show syncModeProvider;
// Phase 10: Migrated to organized provider imports
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show analyticsProvider, loggerProvider;
import 'package:duru_notes/features/search/providers/search_providers.dart'
    show tagRepositoryInterfaceProvider;
import 'package:duru_notes/ui/widgets/email_attachments_section.dart';
import 'package:duru_notes/ui/widgets/voice_recording_player.dart';
import 'package:duru_notes/ui/helpers/domain_note_helpers.dart';
import 'package:duru_notes/ui/widgets/note_tag_chips.dart';
import 'package:duru_notes/ui/widgets/note_link_autocomplete.dart';
import 'package:duru_notes/ui/widgets/backlinks_widget.dart';
import 'package:duru_notes/ui/widgets/interactive_note_preview.dart';
import 'package:duru_notes/ui/_link_dialog_screen.dart';
import 'package:duru_notes/features/templates/template_gallery_screen.dart';
import 'package:duru_notes/features/templates/template_variable_dialog.dart';
import 'package:duru_notes/models/template_model.dart';
import 'package:duru_notes/services/template_variable_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
    this.openInPreviewMode = false,
  });

  final String? noteId;
  final String? initialTitle;
  final String? initialBody;
  final domain.Folder? initialFolder;
  final bool isEditingTemplate;
  final String? highlightTaskId;
  final String? highlightTaskContent;
  final bool openInPreviewMode;

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

  // State
  bool _hasChanges = false;
  bool _isLoading = false;
  bool _contentHasFocus = false;
  bool _showFormattingToolbar = false;
  bool _isPreviewMode = false;
  bool _isPinned = false; // Track pin state
  domain.Folder? _selectedFolder;
  String? _initialText;
  late String _noteIdForTags; // Either real ID or temp ID for tags
  List<String> _currentTags = [];

  AppLogger get _logger => ref.read(loggerProvider);

  // AI Assistant State
  bool _showAISuggestions = false;
  String? _aiSuggestion;
  bool _isAIProcessing = false;

  // Sprint 1 Block Parsing Fix: Block editor state
  List<NoteBlock> _blocks = [];
  final FeatureFlags _featureFlags = FeatureFlags.instance;

  // Voice dictation state
  bool _isDictating = false;
  DictationLocale? _selectedDictationLocale;
  static const String _dictationLocaleKey = 'prefs.dictation.locale';

  // Material-3 Design Constants
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
    final initialText = initialTitle.isNotEmpty
        ? '$initialTitle\n$initialBody'
        : initialBody;

    _noteController = TextEditingController(text: initialText);
    _initialText = initialText;

    // Sprint 1 Block Parsing Fix: Initialize blocks from text
    if (_featureFlags.useBlockEditorForNotes) {
      if (initialText.isNotEmpty) {
        _blocks = parseMarkdownToBlocks(initialText);
      } else {
        // For new notes, start with an empty paragraph block
        _blocks = [NoteBlock(type: NoteBlockType.paragraph, data: '')];
      }
    }

    // Highlight task if specified
    if (widget.highlightTaskId != null || widget.highlightTaskContent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _highlightTask();
      });
    }

    // Domain tasks are now handled via controllers; no unified sync hook needed here

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

    // Legacy unified task sync removed; domain controller handles note/task lifecycle.

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

    // Animation controller for save button (reserved for future use)
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
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

    // Load saved dictation locale preference
    _loadDictationLocale();

    // Setup note ID for tags (real or temp)
    _noteIdForTags = widget.noteId ?? 'note_draft_${const Uuid().v4()}';

    // Load metadata for existing notes
    if (widget.noteId != null) {
      _loadNoteMetadata();

      // UX Enhancement: Open existing notes in preview mode by default
      // User can tap pencil icon to edit
      if (widget.openInPreviewMode) {
        _isPreviewMode = true;
      }
    }
  }

  Future<void> _loadNoteMetadata() async {
    if (widget.noteId == null) return;

    try {
      final note = await ref
          .read(notesCoreRepositoryProvider)
          .getNoteById(widget.noteId!);
      if (note != null && mounted) {
        // Load note content into editor
        final title = note.title.trimRight();
        final body = note.body;
        final noteText = title.isNotEmpty ? '$title\n$body' : body;

        _noteController.text = noteText;
        _initialText = noteText;

        // Sprint 1 Block Parsing Fix: Update blocks from loaded content
        if (_featureFlags.useBlockEditorForNotes && noteText.isNotEmpty) {
          _blocks = parseMarkdownToBlocks(noteText);
        }

        // Load pin state
        setState(() {
          _isPinned = note.isPinned;
        });

        // Load existing tags
        final tags = await ref
            .read(tagRepositoryInterfaceProvider)
            .getTagsForNote(widget.noteId!);
        if (mounted) {
          setState(() {
            _currentTags = tags;
          });
        }
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load note metadata',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': widget.noteId},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
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
      } on Exception catch (error, stackTrace) {
        _logger.error(
          'Failed to load folder for note',
          error: error,
          stackTrace: stackTrace,
          data: {'noteId': widget.noteId},
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
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
                const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('Opened from task reminder')),
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

    // Clean up temp tags if note was discarded
    if (widget.noteId == null && _noteIdForTags.startsWith('note_draft_')) {
      // Schedule cleanup for next frame to avoid ref usage during disposal
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _cleanupTempTags();
      });
    }

    super.dispose();
  }

  Future<void> _cleanupTempTags() async {
    // Skip cleanup - temp tags will be cleaned up by database maintenance
    // We can't use ref here as the widget might be disposed
    _logger.debug(
      'Skipping temp tag cleanup',
      data: {'draftNoteId': _noteIdForTags},
    );
  }

  Future<void> _remapTempTags(String realNoteId) async {
    try {
      // Re-save all tags with the real note ID
      for (final tag in _currentTags) {
        try {
          await ref
              .read(tagRepositoryInterfaceProvider)
              .addTag(noteId: realNoteId, tag: tag);
        } catch (error, stackTrace) {
          _logger.warning(
            'Failed to remap tag during note save',
            data: {'noteId': realNoteId, 'tag': tag},
          );
          unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        }
      }
      // Update our local reference
      _noteIdForTags = realNoteId;
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to remap temporary tags after note save',
        error: error,
        stackTrace: stackTrace,
        data: {'draftNoteId': _noteIdForTags, 'realNoteId': realNoteId},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
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
          title: Text(
            widget.isEditingTemplate
                ? AppLocalizations.of(context).editingTemplate
                : (widget.noteId == null ? 'New Note' : 'Edit Note'),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [DuruColors.primary, DuruColors.accent],
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
                icon: Icon(CupertinoIcons.doc_text, color: Colors.white),
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
                _isPreviewMode ? CupertinoIcons.pencil : CupertinoIcons.eye,
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: Colors.white,
                      ),
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
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.2,
                            ),
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
                          icon: Icon(CupertinoIcons.checkmark_circle, size: 16),
                          label: Text('Accept'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF9333EA),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _requestAISuggestion();
                          },
                          icon: Icon(CupertinoIcons.refresh, size: 16),
                          label: Text('Try Another'),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white70
                                : Colors.grey,
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

  // Legacy UI methods removed - replaced by AppBar actions and modern toolbar
  // (_buildHeaderAction, _buildQuickActionBar, _buildQuickAction, _buildSaveButton)

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
                      : (isDark ? Colors.white : Colors.grey).withValues(
                          alpha: 0.1,
                        ),
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
                // Sprint 1 Block Parsing Fix: Different layouts for BlockEditor vs TextField
                // BlockEditor has internal scrolling, TextField needs SingleChildScrollView
                child: _featureFlags.useBlockEditorForNotes
                    ? // BlockEditor mode: No ScrollView, let BlockEditor handle scrolling
                      Padding(
                        padding: const EdgeInsets.only(bottom: 100),
                        child: unified.UnifiedBlockEditor(
                          blocks: _blocks,
                          onBlocksChanged: (newBlocks) {
                            setState(() {
                              _blocks = newBlocks;
                              // Sync back to text controller for save
                              _noteController.text = blocksToMarkdown(
                                newBlocks,
                              );
                              _hasChanges = true;
                            });
                          },
                          noteId: widget.noteId,
                          config: const unified.BlockEditorConfig(
                            allowReordering: true,
                            showBlockSelector:
                                false, // Hide toolbar (we have our own)
                            enableMarkdown: true,
                            enableTaskSync: true,
                            useAdvancedFeatures: true,
                          ),
                        ),
                      )
                    : // TextField mode: Use SingleChildScrollView for traditional scrolling
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Legacy TextField for plain text editing
                            NoteLinkAutocomplete(
                              textEditingController: _noteController,
                              focusNode: _contentFocusNode,
                              linkParser: ref.read(noteLinkParserProvider),
                              notesRepository: ref.read(
                                notesCoreRepositoryProvider,
                              ),
                              child: TextField(
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
                                      'First line becomes the title\n\n'
                                      'Type @ to link to other notes',
                                  hintStyle: theme.textTheme.bodyLarge
                                      ?.copyWith(
                                        height: 1.7,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black87)
                                                .withValues(alpha: 0.4),
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
                            ),
                            // Add attachments section if available
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: kContentPadding,
                              ),
                              child: _buildAttachmentsIfAny(),
                            ),

                            // Add backlinks section for existing notes
                            if (widget.noteId != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: BacklinksWidget(
                                  currentNoteId: widget.noteId!,
                                  linkParser: ref.read(noteLinkParserProvider),
                                  notesRepository: ref.read(
                                    notesCoreRepositoryProvider,
                                  ),
                                  onNavigateToNote: (noteId) {
                                    // Navigate to the linked note
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (context) =>
                                            ModernEditNoteScreen(
                                              noteId: noteId,
                                            ),
                                      ),
                                    );
                                  },
                                  initiallyExpanded: false,
                                ),
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
    return FutureBuilder<domain.Note?>(
      future: ref.read(notesCoreRepositoryProvider).getNoteById(widget.noteId!),
      builder: (context, snapshot) {
        final note = snapshot.data;
        if (note == null) {
          return const SizedBox.shrink();
        }

        try {
          // Build voice recordings section
          final voiceRecordingsWidget = _buildVoiceRecordings(note);

          // Build email attachments section
          final attachmentsFromMeta = DomainNoteHelpers.getAttachments(note);
          final attachmentEntries = attachmentsFromMeta.isNotEmpty
              ? attachmentsFromMeta
              : _attachmentsFromMetadata(note.metadata);

          final files = attachmentEntries
              .map(
                (m) => EmailAttachmentRef(
                  path: (m['path'] as String?)?.trim() ?? '',
                  filename:
                      (m['filename'] as String?)?.trim() ??
                      _inferFilename((m['path'] as String?) ?? ''),
                  mimeType:
                      (m['type'] as String?)?.trim() ??
                      'application/octet-stream',
                  sizeBytes: (m['size'] as num?)?.toInt() ?? 0,
                  url: (m['url'] as String?)?.trim(),
                  urlExpiresAt: _parseDate(m['url_expires_at']),
                ),
              )
              .where((f) => f.path.isNotEmpty)
              .toList(growable: false);

          Widget? emailAttachmentsWidget;
          if (files.isNotEmpty) {
            // Determine correct bucket based on attachment paths
            final firstPath = files.first.path;
            final bucketId = firstPath.startsWith('temp/')
                ? 'inbound-attachments-temp'
                : 'inbound-attachments';

            emailAttachmentsWidget = EmailAttachmentsSection(
              files: files,
              bucketId: bucketId,
              signedUrlTtlSeconds: 86400,
            );
          }

          // Combine voice recordings and email attachments
          final widgets = <Widget>[];
          if (voiceRecordingsWidget != null) {
            widgets.add(voiceRecordingsWidget);
          }
          if (emailAttachmentsWidget != null) {
            if (widgets.isNotEmpty) {
              widgets.add(const SizedBox(height: 16));
            }
            widgets.add(emailAttachmentsWidget);
          }

          if (widgets.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widgets,
          );
        } catch (error, stackTrace) {
          _logger.error(
            'Failed to parse note attachments',
            error: error,
            stackTrace: stackTrace,
            data: {'noteId': widget.noteId},
          );
          unawaited(Sentry.captureException(error, stackTrace: stackTrace));
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget? _buildVoiceRecordings(domain.Note note) {
    if (note.attachmentMeta == null || note.attachmentMeta!.isEmpty) {
      return null;
    }

    try {
      final metaData = jsonDecode(note.attachmentMeta!) as Map<String, dynamic>;
      final voiceRecordings = metaData['voiceRecordings'] as List<dynamic>?;

      if (voiceRecordings == null || voiceRecordings.isEmpty) {
        return null;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Voice Recordings',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...voiceRecordings.map((recording) {
            final url = recording['url'] as String?;
            final filename = recording['filename'] as String?;
            final durationSeconds = recording['durationSeconds'] as int?;
            final createdAt = recording['createdAt'] as String?;

            if (url == null || durationSeconds == null) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: VoiceRecordingPlayer(
                audioUrl: url,
                durationSeconds: durationSeconds,
                title: filename,
              ),
            );
          }),
        ],
      );
    } catch (e) {
      _logger.warning('Failed to parse voice recordings', data: {'error': e.toString()});
      return null;
    }
  }

  List<Map<String, dynamic>> _attachmentsFromMetadata(String? metadataJson) {
    if (metadataJson == null || metadataJson.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(metadataJson);
      if (decoded is Map<String, dynamic>) {
        final attachments = decoded['attachments'];
        if (attachments is Map<String, dynamic>) {
          final files = attachments['files'];
          if (files is List) {
            return files
                .whereType<Map<dynamic, dynamic>>()
                .map((entry) {
                  final mapped = <String, dynamic>{};
                  entry.forEach((key, value) => mapped[key.toString()] = value);
                  return mapped;
                })
                .toList(growable: false);
          }
        }
      }
    } catch (error, stackTrace) {
      _logger.warn(
        'Failed to parse attachments from metadata',
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
    }
    return const [];
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title display in preview
          Padding(
            padding: const EdgeInsets.all(kScreenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),

          // Interactive preview with checkbox support
          Expanded(
            child: bodyContent.isNotEmpty
                ? InteractiveNotePreview(
                    content: bodyContent,
                    onContentChanged: (newContent) {
                      // Update the note controller with new content
                      final parts = _splitTitleBody(_noteController.text);
                      _noteController.text = '${parts.title}\n$newContent';
                      setState(() {
                        _hasChanges = true;
                      });
                    },
                    theme: theme,
                    colorScheme: colorScheme,
                  )
                : Padding(
                    padding: const EdgeInsets.all(kScreenPadding),
                    child: Text(
                      'No content',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
          ),

          if (widget.noteId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kContentPadding),
              child: _buildAttachmentsIfAny(),
            ),
          const SizedBox(height: 100),
        ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
        child: Row(
          children: [
            // Core formatting: Bold, Italic
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

            // Voice dictation button (core action)
            if (_featureFlags.voiceDictationEnabled) ...[
              _buildToolDivider(colorScheme),
              _buildToolButton(
                icon: _isDictating ? Icons.stop_rounded : Icons.mic_rounded,
                tooltip: _isDictating
                    ? 'Stop Dictation'
                    : _selectedDictationLocale != null
                        ? 'Dictate (${_selectedDictationLocale!.localeId}) • Long press for language'
                        : 'Dictate • Long press for language',
                onPressed: _toggleDictation,
                onLongPress: _isDictating ? null : _showDictationLocalePicker,
                colorScheme: colorScheme,
                isActive: _isDictating,
              ),
            ],

            _buildToolDivider(colorScheme),

            // Core lists: Bullet List, Checklist
            _buildToolButton(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Bullet List',
              onPressed: () =>
                  _executeCommand(ListCommand(type: ListType.bullet)),
              colorScheme: colorScheme,
            ),
            _buildToolButton(
              icon: Icons.checklist_rounded,
              tooltip: 'Checklist',
              onPressed: () =>
                  _executeCommand(ListCommand(type: ListType.checkbox)),
              colorScheme: colorScheme,
            ),

            const Spacer(),

            // More menu for advanced formatting
            _buildToolButton(
              icon: Icons.more_horiz_rounded,
              tooltip: 'More formatting options',
              onPressed: () => _showMoreFormattingMenu(colorScheme),
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreFormattingMenu(ColorScheme colorScheme) {
    HapticFeedback.lightImpact();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _buildMoreMenuItem(
                  icon: Icons.format_size_rounded,
                  label: 'Heading',
                  onTap: () {
                    Navigator.pop(context);
                    _showHeadingMenu();
                  },
                  colorScheme: colorScheme,
                ),
                _buildMoreMenuItem(
                  icon: Icons.format_list_numbered_rounded,
                  label: 'Numbered List',
                  onTap: () {
                    Navigator.pop(context);
                    _executeCommand(ListCommand(type: ListType.numbered));
                  },
                  colorScheme: colorScheme,
                ),
                _buildMoreMenuItem(
                  icon: Icons.code_rounded,
                  label: 'Code',
                  onTap: () {
                    Navigator.pop(context);
                    _showCodeMenu();
                  },
                  colorScheme: colorScheme,
                ),
                _buildMoreMenuItem(
                  icon: Icons.format_quote_rounded,
                  label: 'Quote',
                  onTap: () {
                    Navigator.pop(context);
                    _executeCommand(QuoteCommand());
                  },
                  colorScheme: colorScheme,
                ),
                _buildMoreMenuItem(
                  icon: Icons.link_rounded,
                  label: 'Insert Link',
                  onTap: () {
                    Navigator.pop(context);
                    _showLinkDialog();
                  },
                  colorScheme: colorScheme,
                ),
                _buildMoreMenuItem(
                  icon: Icons.image_rounded,
                  label: 'Insert Image',
                  onTap: () {
                    Navigator.pop(context);
                    _insertImage();
                  },
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return ListTile(
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: Text(label),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
    VoidCallback? onLongPress,
    bool isActive = false,
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
              color: isActive ? colorScheme.error : colorScheme.onSurfaceVariant,
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

  // Legacy formatting methods removed - replaced by MarkdownCommand system
  // (_insertMarkdown, _insertList)

  // PRODUCTION ENHANCEMENT: Execute formatting commands with undo support
  void _executeCommand(MarkdownCommand command) {
    // Track analytics
    ref
        .read(analyticsProvider)
        .event(
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

  // PRODUCTION ENHANCEMENT: Show link insertion dialog with note and web link support
  void _showLinkDialog() {
    final selectedText = _noteController.selection.isCollapsed
        ? ''
        : _noteController.text.substring(
            _noteController.selection.start,
            _noteController.selection.end,
          );

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => LinkDialogScreen(
          initialText: selectedText,
          linkParser: ref.read(noteLinkParserProvider),
          notesRepository: ref.read(notesCoreRepositoryProvider),
          onInsertLink: (linkMarkdown) {
            // Insert the link at cursor position
            final position = _noteController.selection.start;
            final text = _noteController.text;
            _noteController.value = TextEditingValue(
              text: text.replaceRange(position, position, linkMarkdown),
              selection: TextSelection.collapsed(
                offset: position + linkMarkdown.length,
              ),
            );
            _hasChanges = true;
            HapticFeedback.lightImpact();
          },
        ),
        fullscreenDialog: true,
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
        ref
            .read(analyticsProvider)
            .event(
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
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to insert image into note',
        error: error,
        stackTrace: stackTrace,
        data: {'noteId': widget.noteId},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to insert image. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_insertImage()),
            ),
          ),
        );
      }
    }
  }

  // ============================================================
  // Voice Dictation Methods
  // ============================================================

  Future<void> _loadDictationLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeId = prefs.getString(_dictationLocaleKey);
      if (localeId != null && mounted) {
        // We'll validate against available locales when user first uses dictation
        setState(() {
          _selectedDictationLocale = DictationLocale(
            localeId: localeId,
            name: localeId, // Will be replaced with actual name on picker open
          );
        });
      }
    } catch (e) {
      _logger.debug('Error loading dictation locale preference: $e');
    }
  }

  Future<void> _saveDictationLocale(DictationLocale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dictationLocaleKey, locale.localeId);
      setState(() => _selectedDictationLocale = locale);
    } catch (e) {
      _logger.debug('Error saving dictation locale preference: $e');
    }
  }

  Future<void> _showDictationLocalePicker() async {
    final stt = ref.read(voiceTranscriptionServiceProvider);

    // Show loading indicator
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final locales = await stt.getAvailableLocales();
      final systemLocale = await stt.getSystemLocale();

      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      if (locales.isEmpty) {
        _showDictationError('No speech recognition languages available');
        return;
      }

      // Show locale picker bottom sheet
      final selected = await showModalBottomSheet<DictationLocale>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _DictationLocalePickerSheet(
          locales: locales,
          selectedLocale: _selectedDictationLocale,
          systemLocale: systemLocale,
        ),
      );

      if (selected != null) {
        await _saveDictationLocale(selected);

        // Show confirmation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dictation language: ${selected.name}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        _showDictationError('Failed to load languages');
      }
    }
  }

  Future<void> _toggleDictation() async {
    if (_isDictating) {
      await _stopDictation();
    } else {
      await _startDictation();
    }
  }

  Future<void> _startDictation() async {
    final stt = ref.read(voiceTranscriptionServiceProvider);

    try {
      await stt.start(
        onFinal: _onDictationFinal,
        onPartial: null, // Ignore partials for MVP
        onError: _onDictationError,
        localeId: _selectedDictationLocale?.localeId, // Use selected locale or system default
      );
      setState(() => _isDictating = true);

      // Analytics
      ref.read(analyticsProvider).event(
        'editor.dictation_started',
        properties: {
          'noteId': widget.noteId ?? 'new',
          'locale': _selectedDictationLocale?.localeId ?? 'system_default',
        },
      );

      HapticFeedback.lightImpact();
    } catch (e) {
      _logger.error(
        'Failed to start voice dictation',
        error: e,
        data: {'noteId': widget.noteId},
      );
      _showDictationError('Speech recognition is not available on this device');
    }
  }

  Future<void> _stopDictation() async {
    final stt = ref.read(voiceTranscriptionServiceProvider);
    await stt.stop();
    setState(() => _isDictating = false);

    // Analytics
    ref.read(analyticsProvider).event(
      'editor.dictation_stopped',
      properties: {'noteId': widget.noteId ?? 'new'},
    );

    HapticFeedback.lightImpact();
  }

  void _onDictationFinal(String transcript) {
    if (transcript.isEmpty) return;

    final value = _noteController.value;
    final text = value.text;
    final selection = value.selection;

    // Determine insertion point (cursor or end of text)
    final start = selection.isValid && selection.start >= 0
        ? selection.start
        : text.length;
    final end = selection.isValid && selection.end >= 0
        ? selection.end
        : text.length;

    // Add space before if needed (auto-spacing)
    final needsLeadingSpace = start > 0 &&
        text.isNotEmpty &&
        !RegExp(r'\s').hasMatch(text[start - 1]);
    final insertText = needsLeadingSpace ? ' $transcript' : transcript;

    final newText = text.replaceRange(start, end, insertText);
    final newCursorPosition = start + insertText.length;

    _noteController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
      composing: TextRange.empty,
    );

    setState(() => _hasChanges = true);

    // Analytics
    ref.read(analyticsProvider).event(
      'editor.dictation_text_inserted',
      properties: {
        'noteId': widget.noteId ?? 'new',
        'textLength': transcript.length,
        'wordCount': transcript.split(RegExp(r'\s+')).length,
      },
    );
  }

  void _onDictationError(String error) {
    setState(() => _isDictating = false);
    _showDictationError(error);

    _logger.warning(
      'Voice dictation error',
      data: {'error': error, 'noteId': widget.noteId},
    );
  }

  void _showDictationError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.mic_off_rounded,
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
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => PermissionManager.instance.openAppSettings(),
        ),
      ),
    );
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

    final folder = await showModalBottomSheet<domain.Folder?>(
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

    final logger = ref.read(loggerProvider);

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    String? noteIdToUse;
    final traceId = const Uuid().v4();

    try {
      final repo = ref.read(notesCoreRepositoryProvider);

      logger.info(
        'Note save requested',
        data: {
          'existingNoteId': widget.noteId,
          'titleLength': cleanTitle.length,
          'bodyLength': cleanBody.length,
          'isPinned': _isPinned,
          'hasFolder': _selectedFolder != null,
          'traceId': traceId,
        },
      );
      debugPrint(
        '[ModernEditNote] save requested -> '
        'existing=${widget.noteId ?? "new"} '
        'titleLen=${cleanTitle.length} bodyLen=${cleanBody.length} '
        'pinned=$_isPinned folder=${_selectedFolder?.id} traceId=$traceId',
      );

      final savedNote = await TraceContext.runWithNoteSaveTrace(
        traceId,
        () => repo.createOrUpdate(
          id: widget.noteId,
          title: cleanTitle.isEmpty ? 'Untitled Note' : cleanTitle,
          body: cleanBody,
          isPinned:
              _isPinned, // CRITICAL FIX: Pass current pin state when saving
        ),
      );

      // handle folder assignment
      noteIdToUse = savedNote?.id ?? widget.noteId;

      if (noteIdToUse == null) {
        logger.error(
          'Repository returned null note after save',
          data: {
            'existingNoteId': widget.noteId,
            'titleLength': cleanTitle.length,
            'bodyLength': cleanBody.length,
            'traceId': traceId,
          },
        );
        debugPrint('[ModernEditNote] repository returned null note');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to create note. Please try again.'),
            ),
          );
        }
        return;
      }
      debugPrint('[ModernEditNote] repository saved noteId=$noteIdToUse');

      logger.info(
        'Note saved',
        data: {
          'noteId': noteIdToUse,
          'isNew': widget.noteId == null,
          'isPinned': _isPinned,
          'hasFolder': _selectedFolder != null,
          'traceId': traceId,
        },
      );

      try {
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
      } catch (error, stackTrace) {
        logger.error(
          'Folder assignment update failed after note save',
          error: error,
          stackTrace: stackTrace,
          data: {'noteId': noteIdToUse, 'selectedFolder': _selectedFolder?.id},
        );
        debugPrint(
          '[ModernEditNote] folder update failed for noteId=$noteIdToUse -> $error',
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      }

      // Remap temp tags to real note ID if this was a new note
      if (widget.noteId == null && _noteIdForTags.startsWith('note_draft_')) {
        try {
          await _remapTempTags(noteIdToUse);
        } catch (error, stackTrace) {
          logger.error(
            'Failed to remap temp tags after note save',
            error: error,
            stackTrace: stackTrace,
            data: {'tempId': _noteIdForTags, 'noteId': noteIdToUse},
          );
          debugPrint(
            '[ModernEditNote] tag remap failed for noteId=$noteIdToUse -> $error',
          );
          unawaited(Sentry.captureException(error, stackTrace: stackTrace));
        }
      }

      // refresh list & try sync; failures here must not block navigation
      try {
        await ref.read(notesPageProvider.notifier).refresh();
        logger.info(
          'Notes list refreshed after save',
          data: {'noteId': noteIdToUse},
        );
      } catch (error, stackTrace) {
        logger.error(
          'Notes refresh failed after save',
          error: error,
          stackTrace: stackTrace,
          data: {'noteId': noteIdToUse, 'traceId': traceId},
        );
        debugPrint(
          '[ModernEditNote] refresh after save failed for noteId=$noteIdToUse -> $error',
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      }
      try {
        await ref.read(syncModeProvider.notifier).manualSync();
      } catch (error, stackTrace) {
        logger.error(
          'Manual sync after note save failed',
          error: error,
          stackTrace: stackTrace,
          data: {'noteId': noteIdToUse},
        );
        unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      }

      // Sync widget cache to update iOS/Android quick capture widget
      try {
        final quickCaptureService = ref.read(quickCaptureServiceProvider);
        unawaited(quickCaptureService.updateWidgetCache());
        logger.info(
          'Widget cache sync triggered after note save',
          data: {'noteId': noteIdToUse},
        );
      } catch (error) {
        // Widget sync is optional - log but don't block or show error
        logger.warning(
          'Failed to sync widget cache after note save: $error',
          data: {'noteId': noteIdToUse},
        );
      }

      if (!mounted) return;
      setState(() {
        _hasChanges = false;
        _initialText = _noteController.text;
      });
      // UX Enhancement: Pop with result to trigger list refresh
      Navigator.of(context).pop(true); // Signal successful save
      debugPrint('[ModernEditNote] save completed, popping with success');
    } catch (error, stackTrace) {
      logger.error(
        'Failed to save note',
        error: error,
        stackTrace: stackTrace,
        data: {
          'noteId': noteIdToUse ?? widget.noteId,
          'isPinned': _isPinned,
          'isNew': widget.noteId == null,
          'traceId': traceId,
        },
      );
      debugPrint(
        '[ModernEditNote] save failed -> error=$error stack=${stackTrace.toString().split("\n").first}',
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save note. Please try again.'),
            backgroundColor: DuruColors.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                unawaited(_saveNote());
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Legacy template saving method removed - UI moved to separate template management screen
  // (_saveAsTemplate)

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
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to present template picker',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      _showErrorSnack('Failed to load templates. Please try again.');
    }
  }

  Future<void> _applyTemplate(Template template) async {
    try {
      _logger.debug(
        'Applying template to note',
        data: {'templateId': template.id},
      );
      final variableService = TemplateVariableService();

      // Extract variables from template
      final variables = variableService.extractVariables(template.body);
      _logger.debug(
        'Template variables extracted',
        data: {'templateId': template.id, 'variableCount': variables.length},
      );

      String processedContent = template.body;

      // If template has variables, show input dialog
      if (variables.isNotEmpty) {
        _logger.debug(
          'Showing template variable dialog',
          data: {'templateId': template.id, 'variableCount': variables.length},
        );
        final values = await TemplateVariableDialog.show(
          context,
          variables: variables,
          templateTitle: template.title,
        );

        if (values == null) {
          _logger.debug('Template variable dialog cancelled');
          return; // User cancelled
        }

        _logger.debug(
          'Template variable values provided',
          data: {'templateId': template.id, 'valueCount': values.keys.length},
        );
        // Replace variables with user values
        processedContent = variableService.replaceVariables(
          template.body,
          values,
        );
      } else {
        _logger.debug('Template has no variables, applying system defaults');
        // No variables, just replace system variables
        processedContent = variableService.replaceVariables(template.body, {});
      }

      // Apply template content to editor
      setState(() {
        // Combine template title and processed body
        final newContent = '${template.title}\n$processedContent';
        _noteController.text = newContent;
        _hasChanges = true;

        // Apply template tags if any
        if (template.tags.isNotEmpty) {
          _currentTags.addAll(template.tags);
        }

        // Set template category as folder if applicable
        // This could be enhanced to map template categories to folders
      });

      // Show success message
      _showInfoSnack('Template applied successfully');

      // Track analytics
      try {
        ref
            .read(analyticsProvider)
            .event(
              'template.applied',
              properties: {
                'template_id': template.id,
                'template_title': template.title,
                'has_variables': variables.isNotEmpty,
              },
            );
      } catch (analyticsError) {
        _logger.warning(
          'Failed to send template applied analytics',
          data: {'templateId': template.id},
        );
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to apply template to note',
        error: error,
        stackTrace: stackTrace,
        data: {'templateId': template.id},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      _showErrorSnack('Failed to apply template. Please try again.');
    }
  }
}

// ============================================================
// Dictation Locale Picker Bottom Sheet
// ============================================================

class _DictationLocalePickerSheet extends StatefulWidget {
  const _DictationLocalePickerSheet({
    required this.locales,
    required this.selectedLocale,
    required this.systemLocale,
  });

  final List<DictationLocale> locales;
  final DictationLocale? selectedLocale;
  final DictationLocale? systemLocale;

  @override
  State<_DictationLocalePickerSheet> createState() =>
      _DictationLocalePickerSheetState();
}

class _DictationLocalePickerSheetState
    extends State<_DictationLocalePickerSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<DictationLocale> get _filteredLocales {
    if (_searchQuery.isEmpty) return widget.locales;
    final query = _searchQuery.toLowerCase();
    return widget.locales
        .where((locale) =>
            locale.name.toLowerCase().contains(query) ||
            locale.localeId.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.translate_rounded, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Dictation Language',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the language you want to dictate in',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search languages...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 8),
          // System default option
          if (widget.systemLocale != null && _searchQuery.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _LocaleTile(
                locale: widget.systemLocale!,
                isSelected: widget.selectedLocale == null,
                isSystemDefault: true,
                onTap: () => Navigator.of(context).pop(widget.systemLocale),
              ),
            ),
            Divider(
              indent: 16,
              endIndent: 16,
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ],
          // Locale list
          Expanded(
            child: _filteredLocales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No languages found',
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredLocales.length,
                    itemBuilder: (context, index) {
                      final locale = _filteredLocales[index];
                      final isSelected =
                          locale.localeId == widget.selectedLocale?.localeId;
                      return _LocaleTile(
                        locale: locale,
                        isSelected: isSelected,
                        onTap: () => Navigator.of(context).pop(locale),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LocaleTile extends StatelessWidget {
  const _LocaleTile({
    required this.locale,
    required this.isSelected,
    required this.onTap,
    this.isSystemDefault = false,
  });

  final DictationLocale locale;
  final bool isSelected;
  final bool isSystemDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Flag or language icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _getLanguageEmoji(locale.localeId),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Language name and locale ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isSystemDefault
                                ? '${locale.name} (System Default)'
                                : locale.name,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      locale.localeId,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Checkmark for selected
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get an emoji flag for common locales, or a generic icon for others
  String _getLanguageEmoji(String localeId) {
    final Map<String, String> flagMap = {
      'en_US': '🇺🇸',
      'en_GB': '🇬🇧',
      'en_AU': '🇦🇺',
      'en_CA': '🇨🇦',
      'en_IN': '🇮🇳',
      'es_ES': '🇪🇸',
      'es_MX': '🇲🇽',
      'es_US': '🇺🇸',
      'fr_FR': '🇫🇷',
      'fr_CA': '🇨🇦',
      'de_DE': '🇩🇪',
      'de_AT': '🇦🇹',
      'de_CH': '🇨🇭',
      'it_IT': '🇮🇹',
      'pt_BR': '🇧🇷',
      'pt_PT': '🇵🇹',
      'nl_NL': '🇳🇱',
      'ru_RU': '🇷🇺',
      'zh_CN': '🇨🇳',
      'zh_TW': '🇹🇼',
      'zh_HK': '🇭🇰',
      'ja_JP': '🇯🇵',
      'ko_KR': '🇰🇷',
      'ar_SA': '🇸🇦',
      'hi_IN': '🇮🇳',
      'tr_TR': '🇹🇷',
      'pl_PL': '🇵🇱',
      'sv_SE': '🇸🇪',
      'da_DK': '🇩🇰',
      'no_NO': '🇳🇴',
      'fi_FI': '🇫🇮',
      'th_TH': '🇹🇭',
      'vi_VN': '🇻🇳',
      'id_ID': '🇮🇩',
      'ms_MY': '🇲🇾',
      'he_IL': '🇮🇱',
      'cs_CZ': '🇨🇿',
      'el_GR': '🇬🇷',
      'hu_HU': '🇭🇺',
      'ro_RO': '🇷🇴',
      'uk_UA': '🇺🇦',
    };

    // Try exact match
    if (flagMap.containsKey(localeId)) {
      return flagMap[localeId]!;
    }

    // Try language code match (e.g., 'en' from 'en_AU')
    final languageCode = localeId.split('_').first;
    for (final entry in flagMap.entries) {
      if (entry.key.startsWith('${languageCode}_')) {
        return entry.value;
      }
    }

    // Fallback to generic language icon
    return '🌐';
  }
}
