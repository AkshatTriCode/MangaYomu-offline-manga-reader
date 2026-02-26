// lib/screens/reader_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/chapter.dart';
import '../models/manga.dart';
import '../services/cbz_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';

enum ReadingMode { paginated, longStrip }

class ReaderScreen extends StatefulWidget {
  final Manga manga;
  final List<Chapter> chapters;
  final int initialChapterIndex;
  final int initialPage;
  final bool incognito;

  const ReaderScreen({
    super.key,
    required this.manga,
    required this.chapters,
    required this.initialChapterIndex,
    this.initialPage = 0,
    this.incognito = false,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _currentChapterIndex;
  late PageController _pageController;
  final ScrollController _stripScrollController = ScrollController();
  List<Uint8List> _pages = [];
  bool _isLoading = true;
  bool _uiVisible = true;
  int _currentPage = 0;
  int _totalPages = 0;
  ReadingMode _readingMode = ReadingMode.paginated;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialChapterIndex;
    _pageController = PageController(initialPage: widget.initialPage);
    _currentPage = widget.initialPage;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadChapter(_currentChapterIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stripScrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Chapter get _currentChapter => widget.chapters[_currentChapterIndex];

  Future<void> _loadChapter(int index, {int startPage = 0}) async {
    setState(() {
      _isLoading = true;
      _pages = [];
      _currentPage = startPage;
    });

    final chapter = widget.chapters[index];
    final pages = <Uint8List>[];

    await for (final pageBytes in CbzService.instance.streamPages(chapter.cbzPath)) {
      pages.add(pageBytes);
      if (pages.length == 1 && mounted) {
        setState(() {
          _pages = List.from(pages);
          _isLoading = false;
        });
      }
    }

    if (mounted) {
      setState(() {
        _pages = pages;
        _totalPages = pages.length;
        _isLoading = false;
      });
    }

    if (startPage > 0 && startPage < pages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_readingMode == ReadingMode.paginated) {
          _pageController.jumpToPage(startPage);
        }
      });
    }

    if (!widget.incognito) {
      await LibraryService.instance.updateReadProgress(
        widget.manga.id,
        _currentChapter.chapterNumber,
        _currentPage,
      );
    }
  }

  void _toggleUI() {
    setState(() => _uiVisible = !_uiVisible);
    if (_uiVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _goToPrevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _goToPrevChapter();
    }
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _goToNextChapter();
    }
  }

  void _goToPrevChapter() {
    if (_currentChapterIndex > 0) {
      setState(() => _currentChapterIndex--);
      _pageController = PageController();
      _loadChapter(_currentChapterIndex);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No previous chapter')));
    }
  }

  void _goToNextChapter() {
    if (_currentChapterIndex < widget.chapters.length - 1) {
      setState(() => _currentChapterIndex++);
      _pageController = PageController();
      _loadChapter(_currentChapterIndex);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No next chapter')));
    }
  }

  void _toggleReadingMode() {
    setState(() {
      _readingMode = _readingMode == ReadingMode.paginated
          ? ReadingMode.longStrip
          : ReadingMode.paginated;
    });
    if (_readingMode == ReadingMode.paginated) {
      _pageController = PageController(initialPage: _currentPage);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main reader
          _readingMode == ReadingMode.paginated
              ? _buildPaginatedReader()
              : _buildLongStripReader(),

          // Tap zones — left/center/right (paginated only)
          if (_readingMode == ReadingMode.paginated)
            _buildTapZones(),

          // Top bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _uiVisible ? 0 : -120,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          // Bottom controls
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            bottom: _uiVisible ? 0 : -160,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  // ── Tap zones: left=prev, center=toggleUI, right=next ──────────────────

  Widget _buildTapZones() {
    return Positioned.fill(
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: _goToPrevPage,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: _toggleUI,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: _goToNextPage,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Paginated (swipe) reader ────────────────────────────────────────────

  Widget _buildPaginatedReader() {
    if (_isLoading && _pages.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    return PhotoViewGallery.builder(
      pageController: _pageController,
      itemCount: _pages.length,
      scrollPhysics: const BouncingScrollPhysics(),
      builder: (context, index) => PhotoViewGalleryPageOptions(
        imageProvider: MemoryImage(_pages[index]),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3.0,
        initialScale: PhotoViewComputedScale.contained,
        heroAttributes: PhotoViewHeroAttributes(tag: 'page_$index'),
      ),
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        if (!widget.incognito) {
          LibraryService.instance.updateReadProgress(
            widget.manga.id,
            _currentChapter.chapterNumber,
            index,
          );
        }
      },
      loadingBuilder: (_, __) => const Center(
        child: CircularProgressIndicator(
            color: AppTheme.primary, strokeWidth: 2),
      ),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
    );
  }

  // ── Long strip (vertical scroll) reader ────────────────────────────────

  Widget _buildLongStripReader() {
    if (_isLoading && _pages.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    return GestureDetector(
      onTap: _toggleUI,
      child: ListView.builder(
        controller: _stripScrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: _pages.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _pages.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2),
              ),
            );
          }
          return Image.memory(
            _pages[index],
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: AppTheme.surfaceElevated,
              child: const Center(
                child: Icon(Icons.broken_image_rounded,
                    color: AppTheme.onSurfaceMuted),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.manga.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (widget.incognito) ...[
                          const Icon(Icons.privacy_tip_rounded,
                              color: AppTheme.accent, size: 11),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          _currentChapter.title,
                          style: const TextStyle(
                              color: Color(0xAAFFFFFF), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Reading mode toggle button
              GestureDetector(
                onTap: _toggleReadingMode,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _readingMode == ReadingMode.longStrip
                        ? AppTheme.accent
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _readingMode == ReadingMode.longStrip
                          ? AppTheme.accent
                          : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _readingMode == ReadingMode.longStrip
                            ? Icons.view_day_rounded
                            : Icons.swipe_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _readingMode == ReadingMode.longStrip
                            ? 'Strip'
                            : 'Pages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom controls ──────────────────────────────────────────────────────

  Widget _buildBottomControls() {
    final hasPages = _totalPages > 0;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Page slider — paginated mode only
            if (hasPages && _readingMode == ReadingMode.paginated) ...[
              Row(
                children: [
                  Text(
                    '${_currentPage + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                  Expanded(
                    child: Slider(
                      value: _currentPage.toDouble(),
                      min: 0,
                      max: (_totalPages - 1).toDouble(),
                      divisions:
                          _totalPages > 1 ? _totalPages - 1 : null,
                      activeColor: AppTheme.accent,
                      inactiveColor: Colors.white24,
                      onChanged: (v) {
                        final page = v.round();
                        _pageController.jumpToPage(page);
                        setState(() => _currentPage = page);
                      },
                    ),
                  ),
                  Text(
                    '$_totalPages',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],

            // Strip mode page count hint
            if (_readingMode == ReadingMode.longStrip)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_pages.length} pages${_isLoading ? ' (loading…)' : ''}  •  scroll to read',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                ),
              ),

            // Chapter navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavButton(
                  icon: Icons.skip_previous_rounded,
                  label: 'Prev Ch',
                  onTap: _currentChapterIndex > 0
                      ? _goToPrevChapter
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentChapterIndex + 1} / ${widget.chapters.length}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ),
                _NavButton(
                  icon: Icons.skip_next_rounded,
                  label: 'Next Ch',
                  onTap: _currentChapterIndex < widget.chapters.length - 1
                      ? _goToNextChapter
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? AppTheme.primary : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: enabled ? Colors.white : Colors.white30,
                size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white30,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
