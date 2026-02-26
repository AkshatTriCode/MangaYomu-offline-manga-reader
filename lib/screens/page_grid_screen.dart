// lib/screens/page_grid_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../models/manga.dart';
import '../services/cbz_service.dart';
import '../theme/app_theme.dart';
import 'reader_screen.dart';

class PageGridScreen extends StatefulWidget {
  final Manga manga;
  final List<Chapter> chapters;
  final int initialChapterIndex;
  final bool incognito;

  const PageGridScreen({
    super.key,
    required this.manga,
    required this.chapters,
    required this.initialChapterIndex,
    this.incognito = false,
  });

  @override
  State<PageGridScreen> createState() => _PageGridScreenState();
}

class _PageGridScreenState extends State<PageGridScreen> {
  List<Uint8List> _pages = [];
  bool _loading = true;
  String? _error;

  Chapter get _chapter => widget.chapters[widget.initialChapterIndex];

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    try {
      final pages = <Uint8List>[];
      await for (final pageBytes
          in CbzService.instance.streamPages(_chapter.cbzPath)) {
        pages.add(pageBytes);
        // Show pages progressively as they load
        if (mounted) setState(() => _pages = List.from(pages));
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _openReader(int pageIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          manga: widget.manga,
          chapters: widget.chapters,
          initialChapterIndex: widget.initialChapterIndex,
          initialPage: pageIndex,
          incognito: widget.incognito,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.manga.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              _chapter.title,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.onSurfaceMuted),
            ),
          ],
        ),
        actions: [
          // Incognito indicator
          if (widget.incognito)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.privacy_tip_rounded,
                  color: AppTheme.accent, size: 20),
            ),
          // Read from start shortcut
          TextButton.icon(
            onPressed: _pages.isEmpty ? null : () => _openReader(0),
            icon: const Icon(Icons.play_arrow_rounded,
                color: AppTheme.accent, size: 18),
            label: const Text(
              'Read',
              style: TextStyle(
                  color: AppTheme.accent, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _error != null
          ? _buildError()
          : _pages.isEmpty && _loading
              ? _buildInitialLoading()
              : _buildPageGrid(),
    );
  }

  Widget _buildPageGrid() {
    return CustomScrollView(
      slivers: [
        // Loading indicator when more pages are still streaming in
        if (_loading)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryLight),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading pages... ${_pages.length}',
                    style: const TextStyle(
                        color: AppTheme.onSurfaceMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

        // Page count header
        if (_pages.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    'Pages',
                    style: Theme.of(context).textTheme.titleMedium,
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
                      '${_pages.length}${_loading ? '+' : ''}',
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap a page to start reading',
                    style: const TextStyle(
                        color: AppTheme.onSurfaceMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

        // Grid of page thumbnails
        SliverPadding(
          padding: const EdgeInsets.all(10),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _PageThumb(
                pageBytes: _pages[index],
                pageNumber: index + 1,
                onTap: () => _openReader(index),
              ),
              childCount: _pages.length,
            ),
          ),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget _buildInitialLoading() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 7,
        mainAxisSpacing: 7,
      ),
      itemCount: 9,
      itemBuilder: (_, i) => _ShimmerPageCard(delay: i * 80),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_rounded,
                color: AppTheme.onSurfaceMuted, size: 48),
            const SizedBox(height: 12),
            const Text('Could not read chapter',
                style: TextStyle(
                    color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_error ?? '',
                style: const TextStyle(
                    color: AppTheme.onSurfaceMuted, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Individual page thumbnail ─────────────────────────────────────────────

class _PageThumb extends StatelessWidget {
  final Uint8List pageBytes;
  final int pageNumber;
  final VoidCallback onTap;

  const _PageThumb({
    required this.pageBytes,
    required this.pageNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: AppTheme.surfaceElevated,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Page image
            Image.memory(
              pageBytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_rounded,
                    color: AppTheme.onSurfaceMuted),
              ),
            ),

            // Page number badge (top-left)
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$pageNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // Ripple
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer placeholder ───────────────────────────────────────────────────

class _ShimmerPageCard extends StatefulWidget {
  final int delay;
  const _ShimmerPageCard({this.delay = 0});

  @override
  State<_ShimmerPageCard> createState() => _ShimmerPageCardState();
}

class _ShimmerPageCardState extends State<_ShimmerPageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: Color.lerp(
              AppTheme.surfaceElevated, AppTheme.surface, _a.value),
        ),
      ),
    );
  }
}
