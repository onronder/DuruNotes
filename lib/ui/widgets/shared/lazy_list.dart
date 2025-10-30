import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A performant lazy loading list widget that handles large datasets gracefully
class LazyList<T> extends ConsumerStatefulWidget {
  const LazyList({
    required this.items,
    required this.itemBuilder,
    super.key,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoading = false,
    this.emptyWidget,
    this.errorWidget,
    this.separatorBuilder,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.scrollController,
    this.gridDelegate,
    this.isGrid = false,
    this.cacheExtent,
    this.semanticChildCount,
    this.onRefresh,
    this.header,
    this.footer,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool isLoading;
  final Widget? emptyWidget;
  final Widget? errorWidget;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final ScrollController? scrollController;
  final SliverGridDelegate? gridDelegate;
  final bool isGrid;
  final double? cacheExtent;
  final int? semanticChildCount;
  final Future<void> Function()? onRefresh;
  final Widget? header;
  final Widget? footer;

  @override
  ConsumerState<LazyList<T>> createState() => _LazyListState<T>();
}

class _LazyListState<T> extends ConsumerState<LazyList<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || _isLoadingMore || widget.onLoadMore == null) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 200.0; // Load more when 200px from bottom

    if (currentScroll >= maxScroll - threshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      widget.onLoadMore?.call();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty state
    if (widget.items.isEmpty && !widget.isLoading) {
      return widget.emptyWidget ?? _buildDefaultEmptyWidget(context);
    }

    // Handle error state
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    // Build the list content
    Widget content;

    if (widget.isGrid) {
      content = _buildGrid();
    } else {
      content = _buildList();
    }

    // Wrap with RefreshIndicator if onRefresh is provided
    if (widget.onRefresh != null) {
      content = RefreshIndicator(onRefresh: widget.onRefresh!, child: content);
    }

    return content;
  }

  Widget _buildList() {
    final itemCount =
        widget.items.length +
        (widget.header != null ? 1 : 0) +
        (widget.footer != null ? 1 : 0) +
        (widget.hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      shrinkWrap: widget.shrinkWrap,
      cacheExtent: widget.cacheExtent,
      semanticChildCount: widget.semanticChildCount ?? widget.items.length,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Header
        if (widget.header != null && index == 0) {
          return widget.header!;
        }

        // Adjust index for header
        var adjustedIndex = index;
        if (widget.header != null) {
          adjustedIndex--;
        }

        // Footer
        if (widget.footer != null && adjustedIndex == widget.items.length) {
          return widget.footer!;
        }

        // Loading indicator
        if (adjustedIndex >= widget.items.length) {
          return _buildLoadingIndicator();
        }

        // Regular item
        final item = widget.items[adjustedIndex];

        // With separator
        if (widget.separatorBuilder != null &&
            adjustedIndex < widget.items.length - 1) {
          return Column(
            children: [
              widget.itemBuilder(context, item, adjustedIndex),
              widget.separatorBuilder!(context, adjustedIndex),
            ],
          );
        }

        // Without separator
        return widget.itemBuilder(context, item, adjustedIndex);
      },
    );
  }

  Widget _buildGrid() {
    final itemCount = widget.items.length + (widget.hasMore ? 1 : 0);

    return GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      shrinkWrap: widget.shrinkWrap,
      cacheExtent: widget.cacheExtent,
      semanticChildCount: widget.semanticChildCount ?? widget.items.length,
      gridDelegate:
          widget.gridDelegate ??
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Loading indicator
        if (index >= widget.items.length) {
          return _buildLoadingIndicator();
        }

        // Regular item
        final item = widget.items[index];
        return widget.itemBuilder(context, item, index);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Loading more...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultEmptyWidget(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No items',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Items will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sliver version of LazyList for use in CustomScrollView
class SliverLazyList<T> extends StatelessWidget {
  const SliverLazyList({
    required this.items,
    required this.itemBuilder,
    super.key,
    this.separatorBuilder,
    this.gridDelegate,
    this.isGrid = false,
    this.semanticChildCount,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final SliverGridDelegate? gridDelegate;
  final bool isGrid;
  final int? semanticChildCount;

  @override
  Widget build(BuildContext context) {
    if (isGrid) {
      return SliverGrid(
        gridDelegate:
            gridDelegate ??
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => itemBuilder(context, items[index], index),
          childCount: items.length,
          semanticIndexCallback: (widget, localIndex) => localIndex,
        ),
      );
    }

    if (separatorBuilder != null) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final itemIndex = index ~/ 2;
            if (index.isEven) {
              return itemBuilder(context, items[itemIndex], itemIndex);
            }
            return separatorBuilder!(context, itemIndex);
          },
          childCount: items.length * 2 - 1,
          semanticIndexCallback: (widget, localIndex) {
            if (localIndex.isEven) {
              return localIndex ~/ 2;
            }
            return null;
          },
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => itemBuilder(context, items[index], index),
        childCount: items.length,
        semanticIndexCallback: (widget, localIndex) => localIndex,
      ),
    );
  }
}
