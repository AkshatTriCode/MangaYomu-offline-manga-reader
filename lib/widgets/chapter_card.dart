// lib/widgets/chapter_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../theme/app_theme.dart';

class ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final VoidCallback onTap;
  final bool isLoading;

  const ChapterCard({
    super.key,
    required this.chapter,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppTheme.surfaceElevated,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail image
            _buildThumbnail(),

            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xDD000000),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chapter.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (chapter.pageCount != null)
                      Text(
                        '${chapter.pageCount} pages',
                        style: const TextStyle(
                          color: Color(0xAAFFFFFF),
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Loading shimmer
            if (isLoading) _buildShimmer(),

            // Ripple effect
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (chapter.thumbnailCachePath != null &&
        File(chapter.thumbnailCachePath!).existsSync()) {
      return Image.file(
        File(chapter.thumbnailCachePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    if (isLoading) return _buildShimmerPlaceholder();
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            color: AppTheme.primary.withOpacity(0.4),
            size: 32,
          ),
          const SizedBox(height: 6),
          Text(
            chapter.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.onSurfaceMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceElevated,
            AppTheme.surfaceElevated.withOpacity(0.5),
            AppTheme.surfaceElevated,
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryLight,
          ),
        ),
      ),
    );
  }
}
