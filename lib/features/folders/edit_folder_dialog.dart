import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/features/folders/folder_icon_helpers.dart';
import 'package:duru_notes/features/folders/folder_picker_sheet.dart';
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_state_providers.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Material 3 dialog for editing folder properties
class EditFolderDialog extends ConsumerStatefulWidget {
  const EditFolderDialog({required this.folder, super.key});

  final domain.Folder folder;

  @override
  ConsumerState<EditFolderDialog> createState() => _EditFolderDialogState();
}

class _EditFolderDialogState extends ConsumerState<EditFolderDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final _nameFocusNode = FocusNode();

  late AnimationController _scaleController;
  late AnimationController _slideController;

  domain.Folder? _selectedParent;
  late Color _selectedColor;
  late IconData _selectedIcon;
  bool _isUpdating = false;

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

    // Initialize controllers with current folder values
    _nameController = TextEditingController(text: widget.folder.name);
    _descriptionController = TextEditingController(
      text: widget.folder.description ?? '',
    );

    // Initialize color
    if (widget.folder.color != null) {
      try {
        _selectedColor = Color(int.parse(widget.folder.color!, radix: 16));
      } catch (e) {
        _selectedColor = Colors.blue;
      }
    } else {
      _selectedColor = Colors.blue;
    }

    // Initialize icon using helper for tree-shaking compatibility
    if (widget.folder.icon != null) {
      final parsedIcon = FolderIconHelpers.parseIcon(widget.folder.icon);
      _selectedIcon = parsedIcon ?? Icons.folder;
    } else {
      _selectedIcon = Icons.folder;
    }

    // Load parent folder if exists
    _loadParentFolder();

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
  }

  Future<void> _loadParentFolder() async {
    if (widget.folder.parentId != null) {
      final parent = await ref
          .read(folderRepositoryProvider)
          ?.getFolder(widget.folder.parentId!);
      if (mounted) {
        setState(() {
          _selectedParent = parent;
        });
      }
    }
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

  Future<void> _updateFolder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final success = await ref
          .read(folderProvider.notifier)
          .updateFolder(
            id: widget.folder.id,
            name: _nameController.text.trim(),
            parentId: _selectedParent?.id,
            color: _selectedColor.toARGB32().toRadixString(16),
            icon: _selectedIcon.codePoint.toString(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update folder: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
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
      // Prevent circular references
      if (selectedFolder?.id == widget.folder.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cannot move folder into itself'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      // Check if the selected folder is a descendant
      if (selectedFolder != null) {
        final isDescendant = await _isDescendant(
          selectedFolder.id,
          widget.folder.id,
        );
        if (isDescendant) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Cannot move folder into its own subfolder'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          return;
        }
      }

      setState(() {
        _selectedParent = selectedFolder;
      });
    }
  }

  Future<bool> _isDescendant(String potentialParentId, String folderId) async {
    final repository = ref.read(folderRepositoryProvider);
    String? currentId = potentialParentId;

    while (currentId != null) {
      if (currentId == folderId) {
        return true;
      }
      final folder = await repository?.getFolder(currentId);
      currentId = folder?.parentId;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ScaleTransition(
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
                  l10n.editFolder,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 300, maxWidth: 400),
            child: Form(
              key: _formKey,
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
                      prefixIcon: const Icon(Icons.drive_file_rename_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return l10n.folderNameRequired;
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _updateFolder(),
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
                  SizedBox(
                    height: 120,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: _folderIcons.length,
                      itemBuilder: (context, index) {
                        final icon = _folderIcons[index];
                        final isSelected = icon == _selectedIcon;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedIcon = icon),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _selectedColor.withValues(alpha: 0.2)
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: _selectedColor, width: 2)
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              color: isSelected
                                  ? _selectedColor
                                  : colorScheme.onSurfaceVariant,
                              size: 16,
                            ),
                          ),
                        );
                      },
                    ),
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

                  // Original path info
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.folder.parentId != null
                                ? 'Subfolder'
                                : 'Root folder',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isUpdating
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: _isUpdating ? null : _updateFolder,
              child: _isUpdating
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
