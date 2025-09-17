import 'dart:async';
import 'dart:collection';

import 'package:duru_notes/core/animation_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/folder_icon_helpers.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/performance/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Virtualized folder tree for handling large hierarchies efficiently
/// 
/// Features:
/// - Lazy loading of folder children
/// - Viewport-based rendering (only visible items)
/// - Smooth scrolling with large datasets
/// - Memory-efficient expansion state
/// - Progressive loading indicators
class VirtualizedFolderTree extends ConsumerStatefulWidget {
  const VirtualizedFolderTree({
    super.key,
    this.onFolderSelected,
    this.selectedFolderId,
    this.maxInitialItems = 50,
    this.itemHeight = 56.0,
    this.indentWidth = 24.0,
  });

  final Function(LocalFolder?)? onFolderSelected;
  final String? selectedFolderId;
  final int maxInitialItems;
  final double itemHeight;
  final double indentWidth;

  @override
  ConsumerState<VirtualizedFolderTree> createState() => _VirtualizedFolderTreeState();
}

class _VirtualizedFolderTreeState extends ConsumerState<VirtualizedFolderTree> {
  final _logger = LoggerFactory.instance;
  final _scrollController = ScrollController();
  
  // Virtualization state
  final _visibleItems = <String, VirtualFolderItem>{};
  final _expandedFolders = <String>{};
  final _loadingFolders = <String>{};
  final _folderCache = <String, List<LocalFolder>>{};
  
  // Performance tracking
  int _totalItemCount = 0;
  double _scrollOffset = 0;
  Timer? _scrollDebounce;
  
  // Lazy loading state
  final _lazyLoadQueue = Queue<String>();
  bool _isProcessingQueue = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadRootFolders();
    
    // Configure visibility detector
    VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 100);
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _scrollOffset = _scrollController.offset;
    
    // Debounce scroll updates for performance
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 50), () {
      _updateVisibleRange();
    });
  }

  void _updateVisibleRange() {
    if (!mounted) return;
    
    final viewportHeight = _scrollController.position.viewportDimension;
    final startIndex = (_scrollOffset / widget.itemHeight).floor();
    final endIndex = (((_scrollOffset + viewportHeight) / widget.itemHeight).ceil());
    
    // Calculate visible range with buffer
    final bufferSize = 5;
    final visibleStart = (startIndex - bufferSize).clamp(0, _totalItemCount);
    final visibleEnd = (endIndex + bufferSize).clamp(0, _totalItemCount);
    
    _logger.debug('Visible range: $visibleStart - $visibleEnd of $_totalItemCount items');
    
    // Trigger lazy loading for visible items
    _processLazyLoadQueue();
  }

  Future<void> _loadRootFolders() async {
    try {
      // Try cache first
      final cache = ref.read(folderHierarchyCacheProvider);
      var folders = await cache.getRootFolders();
      
      if (folders == null) {
        // Load from database
        final repository = ref.read(notesRepositoryProvider);
        folders = await repository.getRootFolders();
        
        // Cache the result
        await cache.setRootFolders(folders);
      }
      
      if (mounted) {
        setState(() {
          _folderCache['root'] = folders!;
          _totalItemCount = _calculateTotalItems();
        });
      }
    } catch (e, stack) {
      _logger.error('Failed to load root folders', error: e, stackTrace: stack);
    }
  }

  Future<void> _loadChildFolders(String parentId) async {
    if (_loadingFolders.contains(parentId) || _folderCache.containsKey(parentId)) {
      return;
    }
    
    setState(() {
      _loadingFolders.add(parentId);
    });
    
    try {
      // Try cache first
      final cache = ref.read(folderHierarchyCacheProvider);
      var children = await cache.getChildFolders(parentId);
      
      if (children == null) {
        // Load from database
        final repository = ref.read(notesRepositoryProvider);
        children = await repository.getChildFolders(parentId);
        
        // Cache the result
        await cache.setChildFolders(parentId, children);
      }
      
      if (mounted) {
        setState(() {
          _folderCache[parentId] = children!;
          _loadingFolders.remove(parentId);
          _totalItemCount = _calculateTotalItems();
        });
      }
    } catch (e, stack) {
      _logger.error('Failed to load child folders', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _loadingFolders.remove(parentId);
        });
      }
    }
  }

  void _toggleFolder(String folderId) {
    setState(() {
      if (_expandedFolders.contains(folderId)) {
        _expandedFolders.remove(folderId);
      } else {
        _expandedFolders.add(folderId);
        
        // Queue lazy loading of children
        if (!_folderCache.containsKey(folderId)) {
          _lazyLoadQueue.add(folderId);
          _processLazyLoadQueue();
        }
      }
      
      _totalItemCount = _calculateTotalItems();
    });
  }

  Future<void> _processLazyLoadQueue() async {
    if (_isProcessingQueue || _lazyLoadQueue.isEmpty) return;
    
    _isProcessingQueue = true;
    
    while (_lazyLoadQueue.isNotEmpty && mounted) {
      final folderId = _lazyLoadQueue.removeFirst();
      await _loadChildFolders(folderId);
      
      // Small delay to prevent overwhelming the system
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    _isProcessingQueue = false;
  }

  int _calculateTotalItems() {
    int count = 0;
    
    void countFolder(List<LocalFolder> folders, int level) {
      for (final folder in folders) {
        count++;
        
        if (_expandedFolders.contains(folder.id)) {
          final children = _folderCache[folder.id];
          if (children != null) {
            countFolder(children, level + 1);
          }
        }
      }
    }
    
    final rootFolders = _folderCache['root'] ?? [];
    countFolder(rootFolders, 0);
    
    return count;
  }

  List<VirtualFolderItem> _buildVisibleItems() {
    final items = <VirtualFolderItem>[];
    int currentIndex = 0;
    
    void buildFolder(List<LocalFolder> folders, int level) {
      for (final folder in folders) {
        items.add(VirtualFolderItem(
          folder: folder,
          level: level,
          index: currentIndex++,
          isExpanded: _expandedFolders.contains(folder.id),
          isLoading: _loadingFolders.contains(folder.id),
          hasChildren: true, // Will be determined by actual data
        ));
        
        if (_expandedFolders.contains(folder.id)) {
          final children = _folderCache[folder.id];
          if (children != null) {
            buildFolder(children, level + 1);
          }
        }
      }
    }
    
    final rootFolders = _folderCache['root'] ?? [];
    buildFolder(rootFolders, 0);
    
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _buildVisibleItems();
    
    if (items.isEmpty) {
      return _buildEmptyState(theme);
    }
    
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= items.length) return null;
              
              final item = items[index];
              return VirtualFolderTreeItem(
                key: ValueKey(item.folder.id),
                item: item,
                indentWidth: widget.indentWidth,
                isSelected: widget.selectedFolderId == item.folder.id,
                onTap: () => widget.onFolderSelected?.call(item.folder),
                onExpand: () => _toggleFolder(item.folder.id),
              );
            },
            childCount: items.length,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noFoldersFound,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Virtual folder item data
class VirtualFolderItem {
  const VirtualFolderItem({
    required this.folder,
    required this.level,
    required this.index,
    required this.isExpanded,
    required this.isLoading,
    required this.hasChildren,
  });

  final LocalFolder folder;
  final int level;
  final int index;
  final bool isExpanded;
  final bool isLoading;
  final bool hasChildren;
}

/// Individual tree item widget
class VirtualFolderTreeItem extends ConsumerStatefulWidget {
  const VirtualFolderTreeItem({
    super.key,
    required this.item,
    required this.indentWidth,
    required this.isSelected,
    required this.onTap,
    required this.onExpand,
  });

  final VirtualFolderItem item;
  final double indentWidth;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onExpand;

  @override
  ConsumerState<VirtualFolderTreeItem> createState() => _VirtualFolderTreeItemState();
}

class _VirtualFolderTreeItemState extends ConsumerState<VirtualFolderTreeItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  
  int? _noteCount;
  bool _isLoadingCount = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: AnimationConfig.fast,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    
    if (widget.item.isExpanded) {
      _expandController.value = 1.0;
    }
    
    _loadNoteCount();
  }

  @override
  void didUpdateWidget(VirtualFolderTreeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.item.isExpanded != oldWidget.item.isExpanded) {
      if (widget.item.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  Future<void> _loadNoteCount() async {
    if (_isLoadingCount) return;
    
    setState(() {
      _isLoadingCount = true;
    });
    
    try {
      // Try cache first
      final cache = ref.read(folderHierarchyCacheProvider);
      var count = await cache.getFolderNoteCount(widget.item.folder.id);
      
      if (count == null) {
        // Load from database
        final repository = ref.read(notesRepositoryProvider);
        count = await repository.db.countNotesInFolder(widget.item.folder.id);
        
        // Cache the result
        await cache.setFolderNoteCount(widget.item.folder.id, count);
      }
      
      if (mounted) {
        setState(() {
          _noteCount = count;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCount = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final indent = widget.item.level * widget.indentWidth;
    
    return VisibilityDetector(
      key: Key('folder_${widget.item.folder.id}'),
      onVisibilityChanged: (info) {
        // Load data when item becomes visible
        if (info.visibleFraction > 0 && _noteCount == null) {
          _loadNoteCount();
        }
      },
      child: Material(
        color: widget.isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            height: 56,
            padding: EdgeInsets.only(left: 16 + indent, right: 16),
            child: Row(
              children: [
                // Expand/collapse button
                if (widget.item.hasChildren)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      onPressed: widget.onExpand,
                      padding: EdgeInsets.zero,
                      icon: widget.item.isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                          : RotationTransition(
                              turns: Tween<double>(
                                begin: 0,
                                end: 0.25,
                              ).animate(_expandAnimation),
                              child: const Icon(Icons.chevron_right, size: 20),
                            ),
                    ),
                  )
                else
                  const SizedBox(width: 32),
                
                // Folder icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: FolderIconHelpers.getFolderColor(widget.item.folder.color)
                            ?.withValues(alpha: 0.2) ??
                        colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    FolderIconHelpers.getFolderIcon(widget.item.folder.icon),
                    size: 18,
                    color: FolderIconHelpers.getFolderColor(widget.item.folder.color) ??
                        colorScheme.primary,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Folder name
                Expanded(
                  child: Text(
                    widget.item.folder.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: widget.isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: widget.isSelected ? FontWeight.w600 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Note count badge
                if (_noteCount != null && _noteCount! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _noteCount.toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else if (_isLoadingCount)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Provider for virtualized folder tree configuration
final virtualizedFolderConfigProvider = Provider<VirtualizedFolderConfig>((ref) {
  return VirtualizedFolderConfig(
    maxInitialItems: 50,
    itemHeight: 56.0,
    indentWidth: 24.0,
    cacheSize: 500,
    lazyLoadDelay: const Duration(milliseconds: 50),
  );
});

/// Configuration for virtualized folder tree
class VirtualizedFolderConfig {
  const VirtualizedFolderConfig({
    required this.maxInitialItems,
    required this.itemHeight,
    required this.indentWidth,
    required this.cacheSize,
    required this.lazyLoadDelay,
  });

  final int maxInitialItems;
  final double itemHeight;
  final double indentWidth;
  final int cacheSize;
  final Duration lazyLoadDelay;
}
