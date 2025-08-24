import 'package:duru_notes_app/data/local/app_db.dart';
import 'package:duru_notes_app/ui/home_screen.dart';
import 'package:duru_notes_app/ui/tag_notes_screen.dart';
import 'package:duru_notes_app/ui/widgets/error_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  final _searchController = TextEditingController();
  List<TagCount>? _allTags;
  List<TagCount> _filteredTags = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTags();
    _searchController.addListener(_filterTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = ref.read(dbProvider);
      final tags = await db.getTagsWithCounts();
      
      if (mounted) {
        setState(() {
          _allTags = tags;
          _filteredTags = tags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _filterTags() {
    final query = _searchController.text.toLowerCase().trim();
    if (_allTags == null) return;

    setState(() {
      if (query.isEmpty) {
        _filteredTags = _allTags!;
      } else {
        _filteredTags = _allTags!
            .where((tag) => tag.tag.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTags,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tags...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const LoadingDisplay();
    }

    if (_error != null) {
      return ErrorDisplay(
        error: _error!,
        message: 'Failed to load tags',
        onRetry: _loadTags,
      );
    }

    if (_filteredTags.isEmpty) {
      if (_searchController.text.isNotEmpty) {
        return EmptyDisplay(
          title: 'No tags found',
          subtitle: 'No tags match "${_searchController.text}"',
          icon: Icons.search_off,
        );
      } else {
        return const EmptyDisplay(
          title: 'No tags yet',
          subtitle: 'Create notes with #hashtags to see them here',
          icon: Icons.tag,
        );
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _filteredTags.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, i) {
        final tagCount = _filteredTags[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.tag,
              size: 20,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            '#${tagCount.tag}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${tagCount.count} ${tagCount.count == 1 ? 'note' : 'notes'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TagNotesScreen(tag: tagCount.tag),
            ),
          ),
        );
      },
    );
  }
}
