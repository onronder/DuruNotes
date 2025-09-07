import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/material3_theme.dart';

import '../data/local/app_db.dart';
import '../providers.dart';

/// Modern Material 3 Note Editor with Enhanced UX
class ModernEditNoteScreen extends ConsumerStatefulWidget {
  const ModernEditNoteScreen({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialBody,
    this.initialFolder,
  });

  final String? noteId;
  final String? initialTitle;
  final String? initialBody;
  final LocalFolder? initialFolder;

  @override
  ConsumerState<ModernEditNoteScreen> createState() => _ModernEditNoteScreenState();
}

class _ModernEditNoteScreenState extends ConsumerState<ModernEditNoteScreen>
    with TickerProviderStateMixin {
  // Controllers
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _bodyFocusNode = FocusNode();
  
  // State
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isPreviewMode = false;
  bool _showFormattingToolbar = false;

  // Theme helpers
  ColorScheme get colorScheme => Theme.of(context).colorScheme;
  bool _titleHasFocus = false;
  bool _bodyHasFocus = false;
  
  // Animation Controllers
  late AnimationController _saveButtonController;
  late AnimationController _toolbarSlideController;
  late Animation<Offset> _toolbarSlideAnimation;
  late Animation<double> _saveButtonScale;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _bodyController = TextEditingController(text: widget.initialBody ?? '');
    
    // Setup animations
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _saveButtonScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _saveButtonController,
      curve: Curves.easeInOut,
    ));
    
    _toolbarSlideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _toolbarSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolbarSlideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Listen for changes
    _titleController.addListener(_onContentChanged);
    _bodyController.addListener(_onContentChanged);
    
    // Focus listeners
    _titleFocusNode.addListener(() {
        setState(() {
        _titleHasFocus = _titleFocusNode.hasFocus;
      });
    });
    
    _bodyFocusNode.addListener(() {
      setState(() {
        _bodyHasFocus = _bodyFocusNode.hasFocus;
        _showFormattingToolbar = _bodyFocusNode.hasFocus;
        if (_bodyFocusNode.hasFocus) {
          _toolbarSlideController.forward();
        } else {
          _toolbarSlideController.reverse();
        }
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _saveButtonController.dispose();
    _toolbarSlideController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
      _saveButtonController.forward();
    }
  }

  Future<void> _saveNote() async {
    if (_isLoading) return;
    
    if (_titleController.text.trim().isEmpty && 
        _bodyController.text.trim().isEmpty) {
      _showCustomSnackBar(
        'Add some content first',
        icon: Icons.info_outline_rounded,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(notesRepositoryProvider);
      
      String title = _titleController.text.trim();
      if (title.isEmpty) {
        final bodyLines = _bodyController.text.trim().split('\n');
        final firstLine = bodyLines.first.replaceAll(RegExp(r'^#+\s*'), '');
        title = firstLine.isEmpty ? 'Untitled Note' : firstLine;
        if (title.length > 50) title = '${title.substring(0, 47)}...';
      }
      
      await repo.createOrUpdate(
        title: title,
        body: _bodyController.text,
        id: widget.noteId,
      );

      // Immediately push to remote so it isn't lost on logout
      await ref.read(syncModeProvider.notifier).manualSync();

      ref.read(notesPageProvider.notifier).refresh();
      
      setState(() => _hasChanges = false);
      _saveButtonController.reverse();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showCustomSnackBar(
        'Error: ${e.toString()}',
        icon: Icons.error_outline_rounded,
        backgroundColor: Theme.of(context).colorScheme.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCustomSnackBar(String message, {required IconData icon, required Color backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: colorScheme.onPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Theme(
      data: theme.copyWith(
        // Apply Material 3 elevation tints
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: colorScheme.shadow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
              child: Column(
                children: [
              // Modern Header with blur effect
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ColorFilter.mode(
                      colorScheme.surface.withOpacity(0.95),
                      BlendMode.srcOver,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Enhanced Back Button
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: colorScheme.onSurface,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Animated Title
                  Expanded(
                      child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                                Text(
                                  widget.noteId != null ? 'Edit Note' : 'New Note',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                if (_hasChanges)
                                  Text(
                                    'Editing...',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                        ],
                      ),
                    ),
                          
                          // Action Buttons Group
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Preview Toggle
                                _buildHeaderAction(
                                  icon: _isPreviewMode 
                                      ? Icons.edit_note_rounded 
                                      : Icons.preview_rounded,
                                  onPressed: () {
                                    setState(() => _isPreviewMode = !_isPreviewMode);
                                    HapticFeedback.lightImpact();
                                  },
                                  isActive: _isPreviewMode,
                                  colorScheme: colorScheme,
                                ),
                                
                                // Save Button
                                AnimatedBuilder(
                                  animation: _saveButtonScale,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _saveButtonScale.value,
                                      child: _buildSaveButton(colorScheme),
                                    );
                                  },
                                ),
          ],
        ),
      ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Enhanced Formatting Toolbar with slide animation
              if (_showFormattingToolbar && !_isPreviewMode)
                SlideTransition(
                  position: _toolbarSlideAnimation,
                  child: Container(
      decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.5),
        boxShadow: [
          BoxShadow(
                          color: colorScheme.shadow.withOpacity(0.05),
                          blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
                          _buildToolSection([
                            _buildModernToolButton(Icons.format_bold_rounded, 'Bold', 
                                () => _insertMarkdown('**', '**'), colorScheme),
                            _buildModernToolButton(Icons.format_italic_rounded, 'Italic', 
                                () => _insertMarkdown('*', '*'), colorScheme),
                            _buildModernToolButton(Icons.format_size_rounded, 'Heading', 
                                () => _insertMarkdown('## ', ''), colorScheme),
                          ]),
                          _buildToolDivider(colorScheme),
                          _buildToolSection([
                            _buildModernToolButton(Icons.format_list_bulleted_rounded, 'Bullets', 
                                () => _insertList('bullet'), colorScheme),
                            _buildModernToolButton(Icons.format_list_numbered_rounded, 'Numbers', 
                                () => _insertList('numbered'), colorScheme),
                            _buildModernToolButton(Icons.checklist_rounded, 'Tasks', 
                                () => _insertList('checkbox'), colorScheme),
                          ]),
                          _buildToolDivider(colorScheme),
                          _buildToolSection([
                            _buildModernToolButton(Icons.code_rounded, 'Code', 
                                () => _insertMarkdown('`', '`'), colorScheme),
                            _buildModernToolButton(Icons.format_quote_rounded, 'Quote', 
                                () => _insertMarkdown('\n> ', ''), colorScheme),
                            _buildModernToolButton(Icons.link_rounded, 'Link', 
                                () => _insertMarkdown('[', '](url)'), colorScheme),
                            _buildModernToolButton(Icons.image_rounded, 'Image', 
                                () => _insertMarkdown('![alt](', ')'), colorScheme),
                          ]),
                        ],
                ),
              ),
            ),
          ),
          
              // Content Area with better styling
          Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isPreviewMode 
                      ? _buildModernPreview(theme, colorScheme)
                      : _buildModernEditor(theme, colorScheme, isDark),
                ),
              ),
              
              // Modern Bottom Bar
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      // Stats with better design
                      _buildStatChip(
                        icon: Icons.abc_rounded,
                        value: '${_wordCount}',
                        label: 'words',
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(width: 12),
                      _buildStatChip(
                        icon: Icons.text_fields_rounded,
                        value: '${_bodyController.text.length}',
                        label: 'chars',
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(width: 12),
                      _buildStatChip(
                        icon: Icons.timer_outlined,
                        value: '$_readingTime',
                        label: 'min',
                        colorScheme: colorScheme,
                      ),

                      const SizedBox(width: 12),
                      
                      // Save status indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                          color: _hasChanges 
                              ? colorScheme.errorContainer.withOpacity(0.3)
                              : colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _hasChanges 
                                  ? Icons.edit_note_rounded
                                  : Icons.cloud_done_rounded,
                              size: 16,
                              color: _hasChanges 
                                  ? colorScheme.error
                                  : colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                        Text(
                              _hasChanges ? 'Unsaved' : 'Saved',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _hasChanges 
                                    ? colorScheme.error
                                    : colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Floating Quick Actions
        floatingActionButton: _buildFloatingActions(colorScheme),
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
    required ColorScheme colorScheme,
  }) {
    return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isActive 
            ? colorScheme.primaryContainer
                  : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        color: isActive 
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    if (_isLoading) {
      return Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(10),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(colorScheme.primary),
        ),
      );
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: _hasChanges ? LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        color: !_hasChanges ? colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(20),
      ),
          child: Material(
        color: Colors.transparent,
            child: InkWell(
          onTap: _hasChanges ? _saveNote : null,
              borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                Icon(
                  _hasChanges ? Icons.save_rounded : Icons.check_rounded,
                  size: 18,
                  color: _hasChanges 
                      ? colorScheme.onPrimary
                      : colorScheme.onPrimaryContainer,
                ),
                      const SizedBox(width: 6),
                      Text(
                  _hasChanges ? 'Save' : 'Done',
                        style: TextStyle(
                    color: _hasChanges 
                        ? colorScheme.onPrimary
                        : colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                    fontSize: 14,
                        ),
                      ),
                    ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildToolSection(List<Widget> tools) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: tools),
    );
  }

  Widget _buildModernToolButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
    ColorScheme colorScheme,
  ) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolDivider(ColorScheme colorScheme) {
    return Container(
      height: 20,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.outlineVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildModernEditor(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      color: colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Enhanced Title Field
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(_titleHasFocus ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(16),
                // No border when focused or unfocused to avoid outlines
                boxShadow: _titleHasFocus ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ] : [],
              ),
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Note title',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    fontWeight: FontWeight.normal,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                  border: InputBorder.none,
                ),
                maxLines: null,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _bodyFocusNode.requestFocus(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Enhanced Body Field (remove visible outer border when unfocused)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(_bodyHasFocus ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(16),
                // No border even when focused
                boxShadow: _bodyHasFocus ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ] : [],
              ),
              clipBehavior: Clip.antiAlias,
              child: TextField(
                controller: _bodyController,
                focusNode: _bodyFocusNode,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Start writing your thoughts...\n\n'
                      '💡 Tip: Use the toolbar for rich formatting\n'
                      '⌘ + B for bold, ⌘ + I for italic',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    fontSize: 15,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                  border: InputBorder.none,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPreview(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surface.withOpacity(0.95),
          ],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_titleController.text.isNotEmpty) ...[
            Text(
              _titleController.text,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.3),
                    colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: Markdown(
              data: _bodyController.text.isEmpty 
                  ? '*No content to preview*' 
                  : _bodyController.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                  color: colorScheme.onSurface,
          ),
          code: TextStyle(
                  backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
            fontFamily: 'monospace',
            fontSize: 14,
                  color: colorScheme.onPrimaryContainer,
          ),
                blockquote: theme.textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
                  color: colorScheme.onSurfaceVariant,
          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
            icon,
            size: 14,
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActions(ColorScheme colorScheme) {
    if (_isPreviewMode) return null;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
              children: [
        // AI Assistant
        FloatingActionButton.small(
          heroTag: 'ai',
          onPressed: () {
            HapticFeedback.lightImpact();
            _showCustomSnackBar(
              'AI Assistant coming soon!',
              icon: Icons.auto_awesome_rounded,
              backgroundColor: colorScheme.tertiary,
            );
          },
          backgroundColor: colorScheme.tertiaryContainer,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: colorScheme.onTertiaryContainer,
          ),
        ),
        const SizedBox(height: 8),
        // Voice Note
        FloatingActionButton.small(
          heroTag: 'voice',
          onPressed: () {
            HapticFeedback.lightImpact();
            _showCustomSnackBar(
              'Voice recording coming soon!',
              icon: Icons.mic_rounded,
              backgroundColor: colorScheme.secondary,
            );
          },
          backgroundColor: colorScheme.secondaryContainer,
          child: Icon(
            Icons.mic_rounded,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 8),
        // Add attachment
        FloatingActionButton(
          heroTag: 'attach',
          onPressed: () {
            HapticFeedback.lightImpact();
            _showAttachmentOptions(colorScheme);
          },
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.add_rounded,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  void _showAttachmentOptions(ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
                Text(
                'Add to note',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                  _buildAttachmentOption(
                    icon: Icons.photo_camera_rounded,
                    label: 'Camera',
                    color: colorScheme.primary,
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildAttachmentOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: colorScheme.secondary,
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildAttachmentOption(
                    icon: Icons.draw_rounded,
                    label: 'Draw',
                    color: colorScheme.tertiary,
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildAttachmentOption(
                    icon: Icons.attach_file_rounded,
                    label: 'File',
                    color: colorScheme.error,
                    onTap: () => Navigator.pop(context),
                ),
              ],
            ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
            child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
                  Text(
              label,
                    style: TextStyle(
                      fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Helper methods
  void _insertMarkdown(String prefix, String suffix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final selectedText = selection.start != selection.end
        ? text.substring(selection.start, selection.end)
        : '';
    
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$prefix$selectedText$suffix',
    );
    
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + prefix.length + selectedText.length,
      ),
    );
    
    HapticFeedback.lightImpact();
  }

  void _insertList(String listType) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    
    final beforeCursor = text.substring(0, selection.start);
    final afterCursor = text.substring(selection.start);
    
    final lines = beforeCursor.split('\n');
    final currentLine = lines.last;
    
    String prefix;
    switch (listType) {
      case 'bullet':
        prefix = '\n• ';
        break;
      case 'numbered':
        prefix = '\n1. ';
        break;
      case 'checkbox':
        prefix = '\n- [ ] ';
        break;
      default:
        prefix = '\n• ';
    }
    
    final insertText = currentLine.isEmpty ? prefix.substring(1) : prefix;
    final newText = beforeCursor + insertText + afterCursor;
    final newPosition = beforeCursor.length + insertText.length;
    
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newPosition),
    );

    HapticFeedback.lightImpact();
  }

  int get _wordCount {
    final text = _bodyController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }
  
  int get _readingTime {
    return (_wordCount / 200).ceil();
  }
}