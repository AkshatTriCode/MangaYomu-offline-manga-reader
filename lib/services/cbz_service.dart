// lib/services/cbz_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CbzService {
  static CbzService? _instance;
  static CbzService get instance => _instance ??= CbzService._();
  CbzService._();

  static const List<String> _imageExtensions = [
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'
  ];

  /// Returns sorted list of image file names inside the CBZ archive
  Future<List<String>> getPageNames(String cbzPath) async {
    try {
      final bytes = File(cbzPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final imageFiles = archive.files
          .where((f) =>
              !f.isFile == false &&
              _isImage(f.name) &&
              !p.basename(f.name).startsWith('.'))
          .map((f) => f.name)
          .toList();
      imageFiles.sort(_naturalSort);
      return imageFiles;
    } catch (e) {
      return [];
    }
  }

  /// Returns image bytes for a specific page index
  Future<Uint8List?> getPageBytes(String cbzPath, int pageIndex) async {
    try {
      final bytes = File(cbzPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final imageFiles = archive.files
          .where((f) => f.isFile && _isImage(f.name))
          .toList();
      imageFiles.sort((a, b) => _naturalSort(a.name, b.name));

      if (pageIndex >= imageFiles.length) return null;
      final file = imageFiles[pageIndex];
      return Uint8List.fromList(file.content as List<int>);
    } catch (e) {
      return null;
    }
  }

  /// Returns ALL pages as bytes list — lazy loaded via stream
  Stream<Uint8List> streamPages(String cbzPath) async* {
    try {
      final bytes = File(cbzPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final imageFiles = archive.files
          .where((f) => f.isFile && _isImage(f.name))
          .toList();
      imageFiles.sort((a, b) => _naturalSort(a.name, b.name));

      for (final file in imageFiles) {
        yield Uint8List.fromList(file.content as List<int>);
      }
    } catch (e) {
      return;
    }
  }

  /// Extracts and caches thumbnail (first page) for a chapter.
  /// Returns path to cached thumbnail file, or null if failed.
  Future<String?> extractThumbnail(
      String cbzPath, String chapterId) async {
    try {
      // Check cache first
      final cacheDir = await _getThumbnailCacheDir();
      final cachePath = p.join(cacheDir.path, '$chapterId.jpg');
      if (File(cachePath).existsSync()) return cachePath;

      // Extract first image from CBZ
      final bytes = File(cbzPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final imageFiles = archive.files
          .where((f) => f.isFile && _isImage(f.name))
          .toList();

      if (imageFiles.isEmpty) return null;
      imageFiles.sort((a, b) => _naturalSort(a.name, b.name));

      final firstPage = imageFiles.first;
      final imageBytes = Uint8List.fromList(firstPage.content as List<int>);

      // Save to cache
      await File(cachePath).writeAsBytes(imageBytes);
      return cachePath;
    } catch (e) {
      return null;
    }
  }

  /// Returns page count of a CBZ file
  Future<int> getPageCount(String cbzPath) async {
    try {
      final bytes = File(cbzPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      return archive.files.where((f) => f.isFile && _isImage(f.name)).length;
    } catch (e) {
      return 0;
    }
  }

  Future<Directory> _getThumbnailCacheDir() async {
    final cacheDir = await getApplicationCacheDirectory();
    final thumbDir = Directory(p.join(cacheDir.path, 'thumbnails'));
    if (!thumbDir.existsSync()) thumbDir.createSync(recursive: true);
    return thumbDir;
  }

  bool _isImage(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  /// Natural sort: "ch2" < "ch10"
  int _naturalSort(String a, String b) {
    final aBase = p.basename(a).toLowerCase();
    final bBase = p.basename(b).toLowerCase();

    final RegExp numRegex = RegExp(r'(\d+)');
    final aMatches = numRegex.allMatches(aBase).toList();
    final bMatches = numRegex.allMatches(bBase).toList();

    if (aMatches.isNotEmpty && bMatches.isNotEmpty) {
      final aNum = int.tryParse(aMatches.last.group(0) ?? '') ?? 0;
      final bNum = int.tryParse(bMatches.last.group(0) ?? '') ?? 0;
      if (aNum != bNum) return aNum.compareTo(bNum);
    }
    return aBase.compareTo(bBase);
  }

  /// Clear thumbnail cache
  Future<void> clearCache() async {
    final cacheDir = await _getThumbnailCacheDir();
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
    }
  }
}
