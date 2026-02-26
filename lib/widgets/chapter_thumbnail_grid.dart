// lib/widgets/chapter_thumbnail_grid.dart
import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../theme/app_theme.dart';
import 'chapter_card.dart';

enum GridDisplayMode { collapsed, expanded, all }

class ChapterThumbnailGrid extends StatefulWidget {
  final List<Chapter> chapters;
  final Set<String> loadingChapterIds;
  final int initialCount;
  final int expandStep;
  final void Function(Chapter chapter) onChapterTap;

  const ChapterThumbnailGrid({
    super.key,
    required this.chapters,
    required this.onChapterTap,
    this.loadingChapterIds = const {},
    this.initialCount = 6,
    this.expandStep = 12,
  });

  @override
  State<ChapterThumbnailGrid> createState() => _ChapterThumbnailGridState();
}

class _ChapterThumbnailGridState extends State<ChapterThumbnailGrid>
    with SingleTickerProviderStateMixin {
  GridDisplayMode _mode = GridDisplayMode.collapsed;
  int _visibleCount = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.initialCount;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int get _displayCount {
    switch (_mode) {
      case GridDisplayMode.collapsed:
        return _visibleCount.clamp(0, widget.chapters.length);
      case GridDisplayMode.expanded:
        return (_visibleCount).clamp(0, widget.chapters.length);
      case GridDisplayMode.all:
        return widget.chapters.length;
    }
  }

  bool get _canShowMore =>
      _displayCount < widget.chapters.length &&
      _mode != GridDisplayMode.all;

  bool get _canShowAll =>
      widget.chapters.length > _visibleCount &&
      _mode != GridDisplayMode.all;

  void _showMore() {
    setState(() {
      _visibleCount =
          (_visibleCount + widget.expandStep).clamp(0, widget.chapters.length);
      _mode = GridDisplayMode.expanded;
    });
    _animController.forward(from: 0.6);
  }

  void _showAll() {
    setState(() {
      _mode = GridDisplayMode.all;
      _visibleCount = widget.chapters.length;
    });
    _animController.forward(from: 0.6);
  }

  void _collapse() {
    setState(() {
      _mode = GridDisplayMode.collapsed;
      _visibleCount = widget.initialCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) {
      return _buildEmpty();
    }

    final displayedChapters =
        widget.chapters.take(_displayCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                'Chapters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.chapters.length}',
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (_mode != GridDisplayMode.collapsed)
                GestureDetector(
                  onTap: _collapse,
                  child: Row(
                    children: [
                      Icon(Icons.expand_less_rounded,
                          color: AppTheme.onSurfaceMuted, size: 18),
                      Text(
                        'Collapse',
                        style: TextStyle(
                          color: AppTheme.onSurfaceMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Thumbnail grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: displayedChapters.length,
              itemBuilder: (context, index) {
                final chapter = displayedChapters[index];
                return FadeTransition(
                  opacity: _fadeAnim,
                  child: ChapterCard(
                    chapter: chapter,
                    isLoading: widget.loadingChapterIds
                        .contains(chapter.id),
                    onTap: () => widget.onChapterTap(chapter),
                  ),
                );
              },
            ),
          ),
        ),

        // Action buttons row
        if (_canShowMore || _canShowAll) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (_canShowMore)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.expand_more_rounded,
                      label:
                          'Show more  (${(widget.chapters.length - _displayCount).clamp(0, widget.expandStep)} more)',
                      isPrimary: true,
                      onTap: _showMore,
                    ),
                  ),
                if (_canShowMore && _canShowAll)
                  const SizedBox(width: 8),
                if (_canShowAll)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.grid_view_rounded,
                      label:
                          'Show all  (${widget.chapters.length})',
                      isPrimary: false,
                      onTap: _showAll,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.folder_off_rounded,
                color: AppTheme.onSurfaceMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'No chapters found',
              style: TextStyle(color: AppTheme.onSurfaceMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppTheme.accent
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: isPrimary
              ? null
              : Border.all(
                  color: AppTheme.divider,
                  width: 1,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary
                  ? Colors.white
                  : AppTheme.onSurfaceMuted,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    isPrimary ? Colors.white : AppTheme.onSurfaceMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
