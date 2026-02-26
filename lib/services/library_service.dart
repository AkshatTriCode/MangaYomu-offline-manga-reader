// lib/services/library_service.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import 'cbz_service.dart';

class LibraryService {
  static LibraryService? _instance;
  static LibraryService get instance => _instance ??= LibraryService._();
  LibraryService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'manga_library.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE manga (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            folderPath TEXT NOT NULL,
            coverPath TEXT,
            chapterCount INTEGER DEFAULT 0,
            lastRead INTEGER,
            lastReadChapter INTEGER,
            lastReadPage INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE chapters (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            cbzPath TEXT NOT NULL,
            mangaId TEXT NOT NULL,
            chapterNumber INTEGER NOT NULL,
            thumbnailCachePath TEXT,
            pageCount INTEGER,
            FOREIGN KEY(mangaId) REFERENCES manga(id)
          )
        ''');
      },
    );
  }

  // ─── Manga CRUD ────────────────────────────────────────────────────────────

  Future<List<Manga>> getAllManga() async {
    final db = await database;
    final maps = await db.query('manga', orderBy: 'title ASC');
    return maps.map(Manga.fromMap).toList();
  }

  Future<Manga?> getMangaById(String id) async {
    final db = await database;
    final maps = await db.query('manga', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Manga.fromMap(maps.first);
  }

  Future<void> insertManga(Manga manga) async {
    final db = await database;
    await db.insert('manga', manga.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateManga(Manga manga) async {
    final db = await database;
    await db.update('manga', manga.toMap(),
        where: 'id = ?', whereArgs: [manga.id]);
  }

  Future<void> deleteManga(String mangaId) async {
    final db = await database;
    await db.delete('manga', where: 'id = ?', whereArgs: [mangaId]);
    await db.delete('chapters', where: 'mangaId = ?', whereArgs: [mangaId]);
  }

  // ─── Chapter CRUD ──────────────────────────────────────────────────────────

  Future<List<Chapter>> getChaptersByManga(String mangaId) async {
    final db = await database;
    final maps = await db.query(
      'chapters',
      where: 'mangaId = ?',
      whereArgs: [mangaId],
      orderBy: 'chapterNumber ASC',
    );
    return maps.map(Chapter.fromMap).toList();
  }

  Future<void> insertChapter(Chapter chapter) async {
    final db = await database;
    await db.insert('chapters', chapter.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateChapterThumbnail(
      String chapterId, String thumbnailPath, int pageCount) async {
    final db = await database;
    await db.update(
      'chapters',
      {'thumbnailCachePath': thumbnailPath, 'pageCount': pageCount},
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  Future<void> updateReadProgress(
      String mangaId, int chapterNumber, int page) async {
    final db = await database;
    await db.update(
      'manga',
      {
        'lastRead': DateTime.now().millisecondsSinceEpoch,
        'lastReadChapter': chapterNumber,
        'lastReadPage': page,
      },
      where: 'id = ?',
      whereArgs: [mangaId],
    );
  }

  // ─── Directory Scanning ────────────────────────────────────────────────────

  /// Scan a manga folder. The folder should contain .cbz files
  /// (or sub-folders with .cbz files if it's a library root).
  Future<Manga> scanMangaFolder(String folderPath) async {
    final dir = Directory(folderPath);
    final folderName = p.basename(folderPath);
    final mangaId =
        folderPath.hashCode.abs().toString();

    // Check if already in DB
    final existing = await getMangaById(mangaId);

    // Find all .cbz files (direct or one level deep)
    final cbzFiles = <FileSystemEntity>[];
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File &&
          entity.path.toLowerCase().endsWith('.cbz')) {
        cbzFiles.add(entity);
      }
    }
    cbzFiles.sort((a, b) {
      final aName = p.basename(a.path).toLowerCase();
      final bName = p.basename(b.path).toLowerCase();
      return _naturalSortString(aName, bName);
    });

    final manga = Manga(
      id: mangaId,
      title: existing?.title ?? folderName,
      folderPath: folderPath,
      coverPath: existing?.coverPath,
      chapterCount: cbzFiles.length,
      lastRead: existing?.lastRead,
      lastReadChapter: existing?.lastReadChapter,
      lastReadPage: existing?.lastReadPage,
    );
    await insertManga(manga);

    // Insert chapters
    for (var i = 0; i < cbzFiles.length; i++) {
      final cbzFile = cbzFiles[i] as File;
      final chapterId =
          '${mangaId}_${cbzFile.path.hashCode.abs()}';
      final chapterTitle = _chapterTitle(cbzFile.path, i + 1);

      final chapter = Chapter(
        id: chapterId,
        title: chapterTitle,
        cbzPath: cbzFile.path,
        mangaId: mangaId,
        chapterNumber: i + 1,
      );
      await insertChapter(chapter);
    }

    return manga;
  }

  /// Scan a root library folder that contains multiple manga sub-folders
  Future<List<Manga>> scanLibraryRoot(String rootPath) async {
    final dir = Directory(rootPath);
    final mangas = <Manga>[];

    await for (final entity in dir.list(recursive: false)) {
      if (entity is Directory) {
        // Check if dir contains .cbz files
        bool hasCbz = false;
        await for (final f in entity.list(recursive: false)) {
          if (f is File && f.path.toLowerCase().endsWith('.cbz')) {
            hasCbz = true;
            break;
          }
        }
        if (hasCbz) {
          final manga = await scanMangaFolder(entity.path);
          mangas.add(manga);
        }
      } else if (entity is File &&
          entity.path.toLowerCase().endsWith('.cbz')) {
        // Single CBZ in root - treat root as the manga
        final manga = await scanMangaFolder(rootPath);
        mangas.add(manga);
        break;
      }
    }
    return mangas;
  }

  // ─── Thumbnail Generation ──────────────────────────────────────────────────

  Future<void> generateThumbnailsForManga(
    String mangaId, {
    void Function(int done, int total)? onProgress,
  }) async {
    final chapters = await getChaptersByManga(mangaId);
    for (var i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      if (ch.thumbnailCachePath == null ||
          !File(ch.thumbnailCachePath!).existsSync()) {
        final thumbPath = await CbzService.instance
            .extractThumbnail(ch.cbzPath, ch.id);
        final pageCount =
            await CbzService.instance.getPageCount(ch.cbzPath);
        if (thumbPath != null) {
          await updateChapterThumbnail(ch.id, thumbPath, pageCount);
        }
      }
      onProgress?.call(i + 1, chapters.length);
    }

    // Set cover as first chapter's thumbnail
    final updatedChapters = await getChaptersByManga(mangaId);
    final manga = await getMangaById(mangaId);
    if (manga != null &&
        manga.coverPath == null &&
        updatedChapters.isNotEmpty &&
        updatedChapters.first.thumbnailCachePath != null) {
      await updateManga(
          manga.copyWith(coverPath: updatedChapters.first.thumbnailCachePath));
    }
  }

  // ─── Saved Library Paths ──────────────────────────────────────────────────

  Future<List<String>> getSavedLibraryPaths() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('library_paths') ?? [];
  }

  Future<void> addLibraryPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('library_paths') ?? [];
    if (!paths.contains(path)) {
      paths.add(path);
      await prefs.setStringList('library_paths', paths);
    }
  }

  Future<void> removeLibraryPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('library_paths') ?? [];
    paths.remove(path);
    await prefs.setStringList('library_paths', paths);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _chapterTitle(String cbzPath, int fallbackNum) {
    final name = p.basenameWithoutExtension(cbzPath);
    // Try to extract chapter number from filename
    final match = RegExp(r'(?:ch|chapter|ep|episode)?[\s._-]*(\d+(?:\.\d+)?)',
            caseSensitive: false)
        .firstMatch(name);
    if (match != null) {
      return 'Chapter ${match.group(1)}';
    }
    return name.isNotEmpty ? name : 'Chapter $fallbackNum';
  }

  int _naturalSortString(String a, String b) {
    final numRegex = RegExp(r'(\d+)');
    final aMatches = numRegex.allMatches(a).toList();
    final bMatches = numRegex.allMatches(b).toList();
    if (aMatches.isNotEmpty && bMatches.isNotEmpty) {
      final aNum = int.tryParse(aMatches.last.group(0) ?? '') ?? 0;
      final bNum = int.tryParse(bMatches.last.group(0) ?? '') ?? 0;
      if (aNum != bNum) return aNum.compareTo(bNum);
    }
    return a.compareTo(b);
  }
}
