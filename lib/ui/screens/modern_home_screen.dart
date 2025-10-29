import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modern home screen with improved visual design and UX
class ModernHomeScreen extends ConsumerStatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  ConsumerState<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends ConsumerState<ModernHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  bool _isFabExpanded = false;
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF8FAFB),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            snap: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      DuruColors.primary.withValues(alpha: 0.05),
                      DuruColors.accent.withValues(alpha: 0.03),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(DuruSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Compact header with search
                        Row(
                          children: [
                            Text(
                              'Notes',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: DuruColors.primary,
                              ),
                            ),
                            const Spacer(),
                            // Search button
                            _buildHeaderButton(
                              CupertinoIcons.search,
                              () => _showSearch(context),
                            ),
                            SizedBox(width: DuruSpacing.sm),
                            // View toggle
                            _buildHeaderButton(
                              CupertinoIcons.square_grid_2x2,
                              () => _toggleView(),
                            ),
                            SizedBox(width: DuruSpacing.sm),
                            // Menu
                            _buildHeaderButton(
                              CupertinoIcons.ellipsis_circle,
                              () => _showMenu(context),
                            ),
                          ],
                        ),
                        SizedBox(height: DuruSpacing.md),
                        // Smart filter chips
                        _buildFilterChips(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Quick stats bar
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: DuruSpacing.md),
              padding: EdgeInsets.all(DuruSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DuruColors.primary,
                    DuruColors.accent,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: DuruColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('20', 'Notes', CupertinoIcons.doc_text_fill),
                  _buildStatItem('8', 'Folders', CupertinoIcons.folder_fill),
                  _buildStatItem('5', 'Active', CupertinoIcons.bolt_fill),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(height: DuruSpacing.md),
          ),

          // Note list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Placeholder for note cards
                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: DuruSpacing.md,
                    vertical: DuruSpacing.sm,
                  ),
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                );
              },
              childCount: 10,
            ),
          ),
        ],
      ),
      floatingActionButton: _buildModernFAB(),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Recent', 'Pinned', 'Tasks', 'Archives'];

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedFilter == index;
          return Padding(
            padding: EdgeInsets.only(right: DuruSpacing.sm),
            child: FilterChip(
              label: Text(filters[index]),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = index;
                });
                HapticFeedback.lightImpact();
              },
              backgroundColor: Colors.transparent,
              selectedColor: DuruColors.primary.withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected
                    ? DuruColors.primary
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
              labelStyle: TextStyle(
                color: isSelected
                    ? DuruColors.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String count, String label, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.9),
          size: 20,
        ),
        SizedBox(height: DuruSpacing.xs),
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildModernFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded options
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _isFabExpanded ? 180 : 0,
          child: _isFabExpanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFabOption(
                      'Voice Note',
                      CupertinoIcons.mic_fill,
                      DuruColors.accent,
                      () => _createVoiceNote(),
                    ),
                    SizedBox(height: DuruSpacing.sm),
                    _buildFabOption(
                      'Checklist',
                      CupertinoIcons.checkmark_square_fill,
                      Colors.orange,
                      () => _createChecklist(),
                    ),
                    SizedBox(height: DuruSpacing.sm),
                    _buildFabOption(
                      'Text Note',
                      CupertinoIcons.doc_text_fill,
                      DuruColors.primary,
                      () => _createTextNote(),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        SizedBox(height: DuruSpacing.sm),
        // Main FAB
        FloatingActionButton(
          heroTag: 'modern_home_main_fab', // PRODUCTION FIX: Unique hero tag
          onPressed: _toggleFab,
          backgroundColor: _isFabExpanded
              ? Theme.of(context).colorScheme.surface
              : DuruColors.primary,
          elevation: 8,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 200),
            turns: _isFabExpanded ? 0.125 : 0,
            child: Icon(
              CupertinoIcons.add,
              color: _isFabExpanded
                  ? DuruColors.primary
                  : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFabOption(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: DuruSpacing.md,
            vertical: DuruSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(width: DuruSpacing.sm),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
    });
    HapticFeedback.lightImpact();
    if (_isFabExpanded) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  void _showSearch(BuildContext context) {
    // TODO: Implement modern search
  }

  void _toggleView() {
    // TODO: Implement view toggle
    HapticFeedback.lightImpact();
  }

  void _showMenu(BuildContext context) {
    // TODO: Implement menu
  }

  void _createVoiceNote() {
    _toggleFab();
    // TODO: Implement voice note creation
  }

  void _createChecklist() {
    _toggleFab();
    // TODO: Implement checklist creation
  }

  void _createTextNote() {
    _toggleFab();
    // TODO: Implement text note creation
  }
}