import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/parser/note_block_parser.dart';
import '../data/local/app_db.dart';
import '../features/folders/folder_picker_sheet.dart';
import '../models/note_block.dart';
import '../providers.dart';
import '../services/export_service.dart';
import '../theme/material3_theme.dart';
import 'widgets/blocks/block_editor.dart';

/// World-class note editor with gradient blue theme and premium UX
class EditNoteScreen extends ConsumerStatefulWidget {
  const EditNoteScreen({
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
  ConsumerState<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends ConsumerState<EditNoteScreen>
    with TickerProviderStateMixin {
  // Controllers
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final ScrollController _scrollController;
  
  // Animation controllers
  late AnimationController _fadeInController;
  late AnimationController _toolbarAnimationController;
  late AnimationController _saveAnimationController;
  late AnimationController _pulseAnimationController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  // late Animation<double> _toolbarSlideAnimation; // Currently unused
  late Animation<double> _saveScaleAnimation;
  late Animation<double> _pulseAnimation;
  
  // State variables
  bool _isLoading = false;
  bool _isPreviewMode = false;
  bool _useBlockEditor = false;
  bool _hasChanges = false;
  bool _isAutoSaving = false;
  bool _showFormattingToolbar = false;
  bool _isTyping = false;
  
  List<NoteBlock> _blocks = [];
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _bodyFocusNode = FocusNode();
  DateTime? _lastAutoSave;
  LocalFolder? _selectedFolder;
  
  // Undo/Redo stacks
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  String _lastSavedContent = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _initializeContent();
    _setupListeners();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _bodyController = TextEditingController(text: widget.initialBody ?? '');
    _scrollController = ScrollController();
    
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _toolbarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _saveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _initializeAnimations() {
    _fadeAnimation = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOutCubic,
    );
    
    // _toolbarSlideAnimation = CurvedAnimation(
    //   parent: _toolbarAnimationController,
    //   curve: Curves.easeInOutCubic,
    // );
    
    _saveScaleAnimation = CurvedAnimation(
      parent: _saveAnimationController,
      curve: Curves.elasticOut,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start initial animations
    _fadeInController.forward();
  }

  void _initializeContent() {
    if (widget.initialBody?.isNotEmpty == true) {
      _blocks = parseMarkdownToBlocks(widget.initialBody!);
      _lastSavedContent = widget.initialBody!;
    } else {
      _blocks = [createParagraphBlock('')];
      _lastSavedContent = '';
    }
    
    _selectedFolder = widget.initialFolder;
    
    if (widget.noteId != null) {
      _loadNoteFolder();
    }
  }

  void _setupListeners() {
    _titleController.addListener(_onContentChanged);
    _bodyController.addListener(_onContentChanged);
    
    _bodyFocusNode.addListener(() {
      if (_bodyFocusNode.hasFocus && !_showFormattingToolbar) {
        setState(() {
          _showFormattingToolbar = true;
        });
        _toolbarAnimationController.forward();
      }
    });
    
    // Auto-focus title for new notes
    if (widget.noteId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onContentChanged);
    _bodyController.removeListener(_onContentChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _scrollController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _fadeInController.dispose();
    _toolbarAnimationController.dispose();
    _saveAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
        _isTyping = true;
      });
      
      // Save to undo stack
      if (_bodyController.text != _lastSavedContent) {
        _undoStack.add(_lastSavedContent);
        _redoStack.clear();
        _lastSavedContent = _bodyController.text;
      }
    }
    
    // Reset typing indicator after delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    });
    
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    Future.delayed(const Duration(seconds: 2), () {
      if (_hasChanges && mounted && !_isLoading) {
        final now = DateTime.now();
        if (_lastAutoSave == null || 
            now.difference(_lastAutoSave!).inSeconds > 2) {
          _autoSave();
        }
      }
    });
  }

  Future<void> _autoSave() async {
    if (!_hasChanges || _isLoading) return;
    
    setState(() {
      _isAutoSaving = true;
    });
    
    _saveAnimationController.forward();
    
    try {
      final repo = ref.read(notesRepositoryProvider);
      final String bodyContent = _useBlockEditor 
          ? blocksToMarkdown(_blocks)
          : _bodyController.text;
      
      await repo.createOrUpdate(
        title: _titleController.text,
        body: bodyContent,
        id: widget.noteId,
      );
      
      _lastAutoSave = DateTime.now();
      _hasChanges = false;
      
      if (mounted) {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      // Silent fail for auto-save
    } finally {
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
        });
        _saveAnimationController.reverse();
      }
    }
  }

  Future<void> _saveNote() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(notesRepositoryProvider);
      final String bodyContent = _useBlockEditor
          ? blocksToMarkdown(_blocks)
          : _bodyController.text;
      
      final noteId = await repo.createOrUpdate(
        title: _titleController.text,
        body: bodyContent,
        id: widget.noteId,
      );

      // Handle folder assignment
      if (_selectedFolder != null) {
        await ref.read(noteFolderProvider.notifier).addNoteToFolder(noteId, _selectedFolder!.id);
      } else {
        await ref.read(noteFolderProvider.notifier).removeNoteFromFolder(noteId);
      }

      ref.read(notesPageProvider.notifier).refresh();
      ref.read(folderHierarchyProvider.notifier).loadFolders();

      if (mounted) {
        // Show success animation
        _showSaveSuccess();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error saving note: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNoteFolder() async {
    if (widget.noteId == null) return;
    
    try {
      final folder = await ref.read(noteFolderProvider.notifier).getFolderForNote(widget.noteId!);
      if (mounted) {
        setState(() {
          _selectedFolder = folder;
        });
      }
    } catch (e) {
      // Folder loading failed, note will be unfiled
    }
  }

  Future<void> _showFolderPicker() async {
    HapticFeedback.selectionClick();
    
    final selectedFolder = await showFolderPicker(
      context,
      selectedFolderId: _selectedFolder?.id,
      showCreateOption: true,
      showUnfiledOption: true,
      title: 'Choose folder for this note',
    );
    
    if (mounted) {
      setState(() {
        _selectedFolder = selectedFolder;
        _hasChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _showUnsavedChangesDialog();
          if (shouldPop == true && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Gradient background
            _buildGradientBackground(),
            
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Custom app bar with gradient
                  _buildCustomAppBar(),
                  
                  // Content area
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Title input with enhanced design
                          _buildTitleInput(),
                          
                          // Folder indicator
                          if (_selectedFolder != null) _buildFolderIndicator(),
                          
                          // Formatting toolbar (animated)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _showFormattingToolbar && !_isPreviewMode && !_useBlockEditor
                                ? _buildEnhancedFormattingToolbar()
                                : const SizedBox.shrink(),
                          ),
                          
                          // Main editor area
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.05, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: _useBlockEditor 
                                  ? _buildBlockEditor() 
                                  : (_isPreviewMode 
                                      ? _buildPreview() 
                                      : _buildPremiumEditor()),
                            ),
                          ),
                          
                          // Status bar with word count
                          _buildStatusBar(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Floating save indicator
            if (_isAutoSaving) _buildAutoSaveIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.03),
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surface,
            colorScheme.surface.withValues(alpha: 0.95),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Close button with ripple effect
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                HapticFeedback.lightImpact();
                if (_hasChanges) {
                  final shouldPop = await _showUnsavedChangesDialog();
                  if (shouldPop == true && mounted) {
                    Navigator.of(context).pop();
                  }
                } else {
                  Navigator.of(context).pop();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          
          // Title and status
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.noteId != null ? 'Edit Note' : 'New Note',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isTyping || _hasChanges) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        if (_isTyping) ...[
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              colorScheme.primary.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Typing...',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ] else if (_hasChanges) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Unsaved changes',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Preview toggle
        if (!_useBlockEditor)
          _buildAnimatedIconButton(
            icon: _isPreviewMode ? Icons.edit_note_rounded : Icons.visibility_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isPreviewMode = !_isPreviewMode;
              });
            },
            isActive: _isPreviewMode,
            tooltip: _isPreviewMode ? 'Edit' : 'Preview',
          ),
        
        // Block editor toggle
        _buildAnimatedIconButton(
          icon: _useBlockEditor ? Icons.dashboard_rounded : Icons.view_agenda_rounded,
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() {
              _useBlockEditor = !_useBlockEditor;
              if (_useBlockEditor) {
                _blocks = parseMarkdownToBlocks(_bodyController.text);
              } else {
                _bodyController.text = blocksToMarkdown(_blocks);
              }
            });
          },
          isActive: _useBlockEditor,
          tooltip: _useBlockEditor ? 'Simple Editor' : 'Block Editor',
        ),
        
        // Folder assignment
        _buildAnimatedIconButton(
          icon: _selectedFolder != null ? Icons.folder_rounded : Icons.create_new_folder_outlined,
          onPressed: _showFolderPicker,
          isActive: _selectedFolder != null,
          tooltip: _selectedFolder != null 
              ? 'In: ${_selectedFolder!.name}' 
              : 'Add to folder',
          color: _selectedFolder?.color != null 
              ? Color(int.parse(_selectedFolder!.color!))
              : null,
        ),
        
        // More options menu
        _buildMoreOptionsMenu(),
        
        // Save button
        const SizedBox(width: 8),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildAnimatedIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
    required String tooltip,
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonColor = color ?? (isActive ? colorScheme.primary : colorScheme.onSurfaceVariant);
    
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive 
                  ? buttonColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey(icon),
                color: buttonColor,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionsMenu() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      onSelected: _handleMenuAction,
      itemBuilder: (context) => [
        if (widget.noteId != null) ...[
          _buildMenuItem('export_markdown', Icons.code_rounded, 'Export as Markdown'),
          _buildMenuItem('export_pdf', Icons.picture_as_pdf_rounded, 'Export as PDF'),
          _buildMenuItem('export_html', Icons.web_rounded, 'Export as HTML'),
          const PopupMenuDivider(),
          _buildMenuItem('duplicate', Icons.content_copy_rounded, 'Duplicate'),
          const PopupMenuDivider(),
          _buildMenuItem('delete', Icons.delete_outline_rounded, 'Delete', isDestructive: true),
        ] else
          _buildMenuItem('discard', Icons.close_rounded, 'Discard Draft', isDestructive: true),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String title, {bool isDestructive = false}) {
    final color = isDestructive 
        ? Theme.of(context).colorScheme.error 
        : Theme.of(context).colorScheme.primary;
    
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isDestructive ? color : null,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _hasChanges ? _pulseAnimation.value : 1.0,
          child: Material(
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _isLoading ? null : _saveNote,
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: DuruMaterial3Theme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _hasChanges ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : [],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                          ),
                        )
                      else
                        Icon(Icons.save_rounded, size: 18, color: colorScheme.onPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Save',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleInput() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        decoration: InputDecoration(
          hintText: 'Title your masterpiece...',
          hintStyle: theme.textTheme.headlineMedium?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            fontWeight: FontWeight.w300,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        textInputAction: TextInputAction.next,
        maxLines: 2,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _bodyFocusNode.requestFocus(),
      ),
    );
  }

  Widget _buildFolderIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    final folderColor = _selectedFolder?.color != null
        ? Color(int.parse(_selectedFolder!.color!, radix: 16))
        : colorScheme.primary;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            folderColor.withValues(alpha: 0.1),
            folderColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: folderColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _selectedFolder?.icon != null
                ? IconData(int.parse(_selectedFolder!.icon!), fontFamily: 'MaterialIcons')
                : Icons.folder_rounded,
            size: 20,
            color: folderColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedFolder!.name,
              style: TextStyle(
                color: folderColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _showFolderPicker,
            style: TextButton.styleFrom(
              foregroundColor: folderColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFormattingToolbar() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainerHigh,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _buildFormattingButton(
              icon: Icons.format_bold_rounded,
              label: 'Bold',
              onTap: () => _insertMarkdown('**', '**'),
            ),
            _buildFormattingButton(
              icon: Icons.format_italic_rounded,
              label: 'Italic',
              onTap: () => _insertMarkdown('*', '*'),
            ),
            _buildFormattingButton(
              icon: Icons.format_underlined_rounded,
              label: 'Underline',
              onTap: () => _insertMarkdown('<u>', '</u>'),
            ),
            _buildDivider(),
            _buildFormattingButton(
              icon: Icons.title_rounded,
              label: 'Heading',
              onTap: () => _insertMarkdown('## ', ''),
            ),
            _buildFormattingButton(
              icon: Icons.format_list_bulleted_rounded,
              label: 'List',
              onTap: () => _insertMarkdown('\n- ', ''),
            ),
            _buildFormattingButton(
              icon: Icons.checklist_rounded,
              label: 'Checklist',
              onTap: () => _insertMarkdown('\n- [ ] ', ''),
            ),
            _buildDivider(),
            _buildFormattingButton(
              icon: Icons.code_rounded,
              label: 'Code',
              onTap: () => _insertMarkdown('`', '`'),
            ),
            _buildFormattingButton(
              icon: Icons.link_rounded,
              label: 'Link',
              onTap: () => _insertMarkdown('[', '](url)'),
            ),
            _buildFormattingButton(
              icon: Icons.format_quote_rounded,
              label: 'Quote',
              onTap: () => _insertMarkdown('\n> ', ''),
            ),
            _buildDivider(),
            _buildFormattingButton(
              icon: Icons.undo_rounded,
              label: 'Undo',
              onTap: _undo,
              enabled: _undoStack.isNotEmpty,
            ),
            _buildFormattingButton(
              icon: Icons.redo_rounded,
              label: 'Redo',
              onTap: _redo,
              enabled: _redoStack.isNotEmpty,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattingButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () {
            HapticFeedback.lightImpact();
            onTap();
          } : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Icon(
              icon,
              size: 22,
              color: enabled 
                  ? colorScheme.onSurfaceVariant 
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildPremiumEditor() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      key: const ValueKey('premium_editor'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: TextField(
        controller: _bodyController,
        focusNode: _bodyFocusNode,
        decoration: InputDecoration(
          hintText: 'Start writing your thoughts...',
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: theme.textTheme.bodyLarge?.copyWith(
          height: 1.8,
          fontSize: 16,
          color: colorScheme.onSurface,
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        scrollController: _scrollController,
        cursorColor: colorScheme.primary,
        cursorHeight: 24,
        cursorWidth: 2,
      ),
    );
  }

  Widget _buildPreview() {
    final content = _bodyController.text.isEmpty 
        ? '*No content to preview*' 
        : _bodyController.text;
    
    return Container(
      key: const ValueKey('preview'),
      padding: const EdgeInsets.all(24),
      child: Markdown(
        data: content,
        selectable: true,
        shrinkWrap: false,
        physics: const AlwaysScrollableScrollPhysics(),
        styleSheet: MarkdownStyleSheet(
          h1: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          h2: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          h3: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          p: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.8,
          ),
          code: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            fontFamily: 'monospace',
            fontSize: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          blockquote: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockEditor() {
    return Container(
      key: const ValueKey('block_editor'),
      child: BlockEditor(
        blocks: _blocks,
        onBlocksChanged: (blocks) {
          setState(() {
            _blocks = blocks;
            _hasChanges = true;
          });
          _scheduleAutoSave();
        },
        onBlockFocusChanged: (index) {
          // Handle block focus
        },
      ),
    );
  }

  Widget _buildStatusBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final text = _useBlockEditor 
        ? blocksToMarkdown(_blocks)
        : _bodyController.text;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = text.length;
    final readingTime = (words / 200).ceil(); // Average reading speed
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$words words',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.text_fields_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Text(
                  '$chars chars',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Text(
                  '$readingTime min read',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (!_hasChanges)
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  'All changes saved',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAutoSaveIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Positioned(
      bottom: 100,
      right: 24,
      child: AnimatedBuilder(
        animation: _saveScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _saveScaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: DuruMaterial3Theme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Saving...',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    
    HapticFeedback.lightImpact();
    final previousContent = _undoStack.removeLast();
    _redoStack.add(_bodyController.text);
    _bodyController.text = previousContent;
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    
    HapticFeedback.lightImpact();
    final nextContent = _redoStack.removeLast();
    _undoStack.add(_bodyController.text);
    _bodyController.text = nextContent;
  }

  void _showSaveSuccess() {
    final overlay = Overlay.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    
    final entry = OverlayEntry(
      builder: (context) => Center(
        child: AnimatedBuilder(
          animation: _saveScaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _saveScaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: DuruMaterial3Theme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: colorScheme.onPrimary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Note Saved Successfully',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    
    overlay.insert(entry);
    _saveAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 1), () {
        entry.remove();
      });
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 12),
              const Text('Unsaved Changes'),
            ],
          ),
          content: const Text(
            'You have unsaved changes. Would you like to save them before leaving?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await _saveNote();
                if (mounted) Navigator.pop(context, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'export_markdown':
        _exportNote('markdown');
        break;
      case 'export_pdf':
        _exportNote('pdf');
        break;
      case 'export_html':
        _exportNote('html');
        break;
      case 'duplicate':
        await _duplicateNote();
        break;
      case 'delete':
        await _deleteNote();
        break;
      case 'discard':
        await _discardDraft();
        break;
    }
  }

  Future<void> _duplicateNote() async {
    if (widget.noteId == null) return;
    
    HapticFeedback.mediumImpact();
    
    try {
      final repository = ref.read(notesRepositoryProvider);
      final note = await repository.getNote(widget.noteId!);
      if (note != null) {
        final duplicatedNoteId = await repository.createOrUpdate(
          title: '${note.title} (Copy)',
          body: note.body,
        );
        
        if (mounted) {
          _showSuccessMessage('Note duplicated successfully');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => EditNoteScreen(
                noteId: duplicatedNoteId,
                initialTitle: '${note.title} (Copy)',
                initialBody: note.body,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to duplicate note: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteNote() async {
    if (widget.noteId == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              const Text('Delete Note'),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete this note? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed == true && mounted) {
      HapticFeedback.heavyImpact();
      
      try {
        final repository = ref.read(notesRepositoryProvider);
        await repository.delete(widget.noteId!);
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar('Failed to delete note: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _discardDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              const Text('Discard Draft'),
            ],
          ),
          content: const Text(
            'Are you sure you want to discard this draft? Any unsaved changes will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Discard'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    }
  }

  Future<void> _exportNote(String format) async {
    if (widget.noteId == null) return;

    HapticFeedback.lightImpact();
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Exporting as ${format.toUpperCase()}...'),
              ],
            ),
          ),
        ),
      );

      final exportService = ref.read(exportServiceProvider);
      
      final currentNote = LocalNote(
        id: widget.noteId!,
        title: _titleController.text,
        body: _useBlockEditor ? blocksToMarkdown(_blocks) : _bodyController.text,
        updatedAt: DateTime.now(),
        deleted: false,
      );

      ExportResult result;

      switch (format) {
        case 'markdown':
          result = await exportService.exportToMarkdown(
            currentNote,
            onProgress: (progress) {},
          );
          break;
        case 'pdf':
          result = await exportService.exportToPdf(
            currentNote,
            onProgress: (progress) {},
          );
          break;
        case 'html':
          result = await exportService.exportToHtml(
            currentNote,
            onProgress: (progress) {},
          );
          break;
        default:
          throw UnsupportedError('Export format not supported: $format');
      }

      if (mounted) Navigator.of(context).pop();

      if (result.success && result.file != null) {
        _showExportSuccessDialog(result);
      } else {
        _showErrorSnackbar(result.error ?? 'Unknown error occurred');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorSnackbar(e.toString());
    }
  }

  void _showExportSuccessDialog(ExportResult result) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text('Export Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your note has been exported as ${result.format.displayName}.'),
              const SizedBox(height: 8),
              Text('File size: ${_formatFileSize(result.fileSize)}'),
              Text('Processing time: ${result.processingTime.inMilliseconds}ms'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final exportService = ref.read(exportServiceProvider);
                await exportService.openExportedFile(result.file!);
              },
              child: const Text('Open'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final exportService = ref.read(exportServiceProvider);
                await exportService.shareExportedFile(result.file!, result.format);
              },
              child: const Text('Share'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
