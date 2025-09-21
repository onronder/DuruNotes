import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/folder_picker_sheet.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Material 3 dialog for creating new folders with customization options
///
/// This is the single source of truth for folder creation dialogs.
/// Supports multiple use cases:
/// - Creating root folders (parentFolder/parentId = null)
/// - Creating subfolders (with parent specified)
/// - Pre-filling folder name (initialName)
class CreateFolderDialog extends ConsumerStatefulWidget {
  const CreateFolderDialog({
    super.key,
    this.parentFolder,
    this.parentId,
    this.initialName = '',
  });

  /// Parent folder object (if available)
  final LocalFolder? parentFolder;

  /// Parent folder ID (alternative to parentFolder)
  final String? parentId;

  /// Initial name to pre-fill
  final String initialName;

  @override
  ConsumerState<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends ConsumerState<CreateFolderDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _nameFocusNode = FocusNode();

  late AnimationController _scaleController;
  late AnimationController _slideController;

  LocalFolder? _selectedParent;
  Color _selectedColor = Colors.blue;
  IconData _selectedIcon = Icons.folder;
  bool _isCreating = false;
  DateTime? _lastCreateAttempt;

  // Predefined folder colors
  static const List<Color> _folderColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
  ];

  // Predefined folder icons
  static const List<IconData> _folderIcons = [
    Icons.folder,
    Icons.work,
    Icons.school,
    Icons.home,
    Icons.favorite,
    Icons.star,
    Icons.lightbulb,
    Icons.build,
    Icons.shopping_cart,
    Icons.sports,
    Icons.travel_explore,
    Icons.music_note,
    Icons.photo,
    Icons.book,
    Icons.fitness_center,
    Icons.restaurant,
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _selectedParent = widget.parentFolder;

    // If parentId is provided but parentFolder is not, load the folder
    if (widget.parentId != null && widget.parentFolder == null) {
      _loadParentFolder(widget.parentId!);
    }

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleController.forward();
    _slideController.forward();

    // Auto-focus name field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadParentFolder(String parentId) async {
    try {
      final folder =
          await ref.read(notesRepositoryProvider).getFolder(parentId);
      if (mounted && folder != null) {
        setState(() {
          _selectedParent = folder;
        });
      }
    } catch (e) {
      // Silently fail - parent will remain null
    }
  }

  Future<void> _createFolder() async {
    // Prevent multiple simultaneous calls and debounce rapid taps
    final now = DateTime.now();
    if (_isCreating ||
        !_formKey.currentState!.validate() ||
        (_lastCreateAttempt != null &&
            now.difference(_lastCreateAttempt!).inMilliseconds < 1000)) {
      return;
    }

    // Set loading state and disable UI immediately
    setState(() {
      _isCreating = true;
      _lastCreateAttempt = now;
    });

    try {
      // Store the folder data
      final folderName = _nameController.text.trim();
      final parentId = _selectedParent?.id;
      final color = _selectedColor.value.toRadixString(16);
      final icon = _selectedIcon.codePoint.toString();
      final description = _descriptionController.text.trim();

      if (kDebugMode) {
        debugPrint('🔄 Creating folder: "$folderName" with parent: $parentId');
      }

      // Create the actual folder and wait for the real ID
      final realFolderId = await ref.read(folderProvider.notifier).createFolder(
            name: folderName,
            parentId: parentId,
            color: color,
            icon: icon,
            description: description,
          );

      // Only proceed if widget is still mounted
      if (!mounted) return;

      if (realFolderId != null) {
        if (kDebugMode) {
          debugPrint('✅ Folder created successfully with ID: $realFolderId');
        }

        // Get the actual folder from the repository to ensure we have the correct data
        final realFolder =
            await ref.read(notesRepositoryProvider).getFolder(realFolderId);

        final folderToReturn = realFolder ??
            LocalFolder(
              id: realFolderId,
              name: folderName,
              parentId: parentId,
              path: '',
              sortOrder: 0,
              color: color,
              icon: icon,
              description: description,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              deleted: false,
            );

        // Success: Provide haptic feedback and close dialog
        await HapticFeedback.lightImpact();

        // Add small delay for better UX (show success state briefly)
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          Navigator.of(context).pop(folderToReturn);
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ Failed to create folder - null ID returned');
        }

        // Failed to create folder - reset state and show error
        setState(() {
          _isCreating = false;
        });

        if (mounted) {
          await HapticFeedback.heavyImpact(); // Error feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to create folder'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Exception during folder creation: $e');
      }

      // Error occurred - reset state and show error
      if (mounted) {
        setState(() {
          _isCreating = false;
        });

        await HapticFeedback.heavyImpact(); // Error feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create folder: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _selectParentFolder() async {
    final selectedFolder = await showFolderPicker(
      context,
      selectedFolderId: _selectedParent?.id,
      title: AppLocalizations.of(context).selectParentFolder,
      showCreateOption: false,
    );

    if (mounted) {
      setState(() {
        _selectedParent = selectedFolder;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !_isCreating, // Prevent back navigation during creation
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: _scaleController,
          curve: Curves.easeOutBack,
        ),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
              .animate(
            CurvedAnimation(
              parent: _slideController,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: AlertDialog(
            backgroundColor: colorScheme.surface,
            surfaceTintColor: colorScheme.surfaceTint,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selectedColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_selectedIcon, color: _selectedColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.createNewFolder,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              height: 450,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Folder name
                      TextFormField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        decoration: InputDecoration(
                          labelText: l10n.folderName,
                          hintText: l10n.folderNameHint,
                          prefixIcon:
                              const Icon(Icons.drive_file_rename_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return l10n.folderNameRequired;
                          }

                          final trimmed = value!.trim();
                          if (trimmed.length > 50) {
                            return 'Folder name is too long (max 50 characters)';
                          }

                          // Check for invalid characters
                          final invalidChars = RegExp(r'[<>:"/\\|?*]');
                          if (invalidChars.hasMatch(trimmed)) {
                            return 'Folder name contains invalid characters';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!_isCreating) {
                            _createFolder();
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // Parent folder selection
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.folder_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: Text(l10n.parentFolder),
                        subtitle: Text(
                          _selectedParent?.name ?? l10n.rootLevel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _selectParentFolder,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Color selection
                      Text(
                        l10n.folderColor,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _folderColors.map((color) {
                          final isSelected = color == _selectedColor;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color: colorScheme.outline,
                                        width: 3,
                                      )
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Icon selection
                      Text(
                        l10n.folderIcon,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _folderIcons.map((icon) {
                          final isSelected = icon == _selectedIcon;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIcon = icon),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _selectedColor.withValues(alpha: 0.2)
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: _selectedColor, width: 2)
                                    : null,
                              ),
                              child: Icon(
                                icon,
                                color: isSelected
                                    ? _selectedColor
                                    : colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Description (optional)
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: '${l10n.description} (${l10n.optional})',
                          hintText: l10n.folderDescriptionHint,
                          prefixIcon: const Icon(Icons.notes),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    _isCreating ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: _isCreating ? null : _createFolder,
                child: _isCreating
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Creating...'),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 18),
                          const SizedBox(width: 4),
                          Text(l10n.create),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
