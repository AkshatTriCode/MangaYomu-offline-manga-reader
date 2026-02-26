// lib/screens/manga_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chapter_thumbnail_grid.dart';
import 'reader_screen.dart';
import 'page_grid_screen.dart';

class MangaScreen extends StatefulWidget {
  final Manga manga;

  const MangaScreen({super.key, required this.manga});

  @override
  State<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends State<MangaScreen> {
  List<Chapter> _chapters = [];
  Set<String> _loadingChapterIds = {};
  bool _loadingChapters = true;
  late Manga _manga;
  bool _generatingThumbs = false;
  int _thumbProgress = 0;
  bool _incognito = false;

  @override
  void initState() {
    super.initState();
    _manga = widget.manga;
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    final chapters =
        await LibraryService.instance.getChaptersByManga(_manga.id);
    setState(() {
      _chapters = chapters;
      _loadingChapters = false;
    });

    // Check if thumbnails need generating
    final missingThumbs =
        chapters.where((c) => c.thumbnailCachePath == null).length;
    if (missingThumbs > 0) {
      _generateThumbnails();
    }
  }

  Future<void> _generateThumbnails() async {
    setState(() {
      _generatingThumbs = true;
      _thumbProgress = 0;
      // Mark all as loading
      _loadingChapterIds =
          _chapters.where((c) => c.thumbnailCachePath == null)
              .map((c) => c.id)
              .toSet();
    });

    await LibraryService.instance.generateThumbnailsForManga(
      _manga.id,
      onProgress: (done, total) async {
        // Reload chapters to get updated thumbnails
        final updated = await LibraryService.instance
            .getChaptersByManga(_manga.id);
        if (mounted) {
          setState(() {
            _chapters = updated;
            _thumbProgress = done;
            // Remove loaded ones from loading set
            _loadingChapterIds = updated
                .where((c) => c.thumbnailCachePath == null)
                .map((c) => c.id)
                .toSet();
          });
        }
      },
    );

    // Final reload
    final finalChapters =
        await LibraryService.instance.getChaptersByManga(_manga.id);
    final updatedManga =
        await LibraryService.instance.getMangaById(_manga.id);
    if (mounted) {
      setState(() {
        _chapters = finalChapters;
        _loadingChapterIds = {};
        _generatingThumbs = false;
        if (updatedManga != null) _manga = updatedManga;
      });
    }
  }

  void _openChapter(Chapter chapter) {
    final chapterIndex =
        _chapters.indexWhere((c) => c.id == chapter.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PageGridScreen(
          manga: _manga,
          chapters: _chapters,
          initialChapterIndex: chapterIndex,
          incognito: _incognito,
        ),
      ),
    );
  }

  Future<void> _rescanChapters() async {
    setState(() => _loadingChapters = true);
    await LibraryService.instance.scanMangaFolder(_manga.folderPath);
    await _loadChapters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsible header with cover art
          _buildSliverAppBar(),

          // Manga info
          SliverToBoxAdapter(child: _buildMangaInfo()),

          // Chapter thumbnail grid (THE MAIN FEATURE)
          SliverToBoxAdapter(
            child: _loadingChapters
                ? _buildChaptersLoading()
                : ChapterThumbnailGrid(
                    chapters: _chapters,
                    loadingChapterIds: _loadingChapterIds,
                    onChapterTap: _openChapter,
                    initialCount: 6,
                    expandStep: 12,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppTheme.background,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black38,
          foregroundColor: Colors.white,
        ),
      ),
      actions: [
        // Incognito toggle
        IconButton(
          onPressed: () => setState(() => _incognito = !_incognito),
          icon: Icon(
            _incognito
                ? Icons.privacy_tip_rounded
                : Icons.privacy_tip_outlined,
          ),
          style: IconButton.styleFrom(
            backgroundColor:
                _incognito ? AppTheme.accent.withOpacity(0.85) : Colors.black38,
            foregroundColor: Colors.white,
          ),
          tooltip: _incognito ? 'Incognito ON' : 'Incognito OFF',
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: _rescanChapters,
          icon: const Icon(Icons.refresh_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black38,
            foregroundColor: Colors.white,
          ),
          tooltip: 'Rescan chapters',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred cover background
            if (_manga.coverPath != null &&
                File(_manga.coverPath!).existsSync())
              Image.file(
                File(_manga.coverPath!),
                fit: BoxFit.cover,
              )
            else
              Container(color: AppTheme.surface),

            // Gradient overlay
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xCC000000),
                    AppTheme.background,
                  ],
                  stops: [0.3, 0.8, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMangaInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _manga.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamilyFallback: const ['sans-serif'],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _InfoChip(
                icon: Icons.auto_stories_rounded,
                label: '${_manga.chapterCount} Chapters',
              ),
              const SizedBox(width: 8),
              if (_manga.lastReadChapter != null)
                _InfoChip(
                  icon: Icons.bookmark_rounded,
                  label: 'Last: Ch ${_manga.lastReadChapter}',
                  color: AppTheme.accent,
                ),
            ],
          ),

          // Incognito banner
          if (_incognito) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.accent.withOpacity(0.35), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_rounded,
                      color: AppTheme.accent, size: 15),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Incognito mode — reading progress will not be saved',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Thumbnail generation progress
          if (_generatingThumbs) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryLight,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Generating previews... $_thumbProgress/${_chapters.length}',
                  style: const TextStyle(
                    color: AppTheme.onSurfaceMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          // Continue reading button
          if (_manga.lastReadChapter != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final idx = _chapters.indexWhere(
                      (c) => c.chapterNumber == _manga.lastReadChapter);
                  if (idx != -1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReaderScreen(
                          manga: _manga,
                          chapters: _chapters,
                          initialChapterIndex: idx,
                          initialPage: _manga.lastReadPage ?? 0,
                          incognito: _incognito,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label:
                    Text('Continue Ch ${_manga.lastReadChapter}'),
              ),
            ),
          ] else if (_chapters.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openChapter(_chapters.first),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Reading'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: AppTheme.divider),
        ],
      ),
    );
  }

  Widget _buildChaptersLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => _ShimmerCard(),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Color.lerp(
            AppTheme.surfaceElevated,
            AppTheme.surface,
            _a.value,
          ),
        ),
      ),
    );
  }
}
