// lib/screens/library_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/manga.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/manga_card.dart';
import 'manga_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Manga> _mangas = [];
  bool _loading = true;
  String _searchQuery = '';
  bool _searchActive = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    final mangas = await LibraryService.instance.getAllManga();
    setState(() {
      _mangas = mangas;
      _loading = false;
    });
  }

  Future<void> _addMangaFolder() async {
    // Request storage permission
    PermissionStatus status;
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        status = await Permission.manageExternalStorage.request();
      } else if (await Permission.storage.isDenied) {
        status = await Permission.storage.request();
      } else {
        status = PermissionStatus.granted;
      }
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Storage permission needed to read manga files'),
              action: SnackBarAction(
                  label: 'Settings',
                  onPressed: openAppSettings),
            ),
          );
        }
        return;
      }
    }

    // Pick folder
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select manga folder',
    );

    if (result == null) return;

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Scanning folder...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );
    }

    try {
      // Scan for manga
      await LibraryService.instance.addLibraryPath(result);
      await LibraryService.instance.scanLibraryRoot(result);
      await _loadLibrary();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manga added to library!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addSingleMangaFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select manga chapter folder (contains .cbz files)',
    );
    if (result == null) return;

    try {
      final manga =
          await LibraryService.instance.scanMangaFolder(result);
      await _loadLibrary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${manga.title}" added!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteManga(Manga manga) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Remove from library?'),
        content: Text(
          '"${manga.title}" will be removed from your library. '
          'The original files will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await LibraryService.instance.deleteManga(manga.id);
      await _loadLibrary();
    }
  }

  List<Manga> get _filteredMangas {
    if (_searchQuery.isEmpty) return _mangas;
    final q = _searchQuery.toLowerCase();
    return _mangas
        .where((m) => m.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(innerBoxIsScrolled),
        ],
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primary))
            : _filteredMangas.isEmpty
                ? _buildEmptyState()
                : _buildGrid(),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      title: _searchActive
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'Search manga...',
                hintStyle: TextStyle(color: AppTheme.onSurfaceMuted),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            )
          : const Text('読むMangaYomu'),
      actions: [
        IconButton(
          onPressed: () {
            setState(() {
              _searchActive = !_searchActive;
              if (!_searchActive) {
                _searchQuery = '';
                _searchController.clear();
              }
            });
          },
          icon: Icon(
              _searchActive ? Icons.close_rounded : Icons.search_rounded),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          color: AppTheme.surface,
          onSelected: (v) {
            if (v == 'library') _addMangaFolder();
            if (v == 'manga') _addSingleMangaFolder();
            if (v == 'refresh') _loadLibrary();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'manga',
              child: Row(children: [
                Icon(Icons.create_new_folder_rounded,
                    size: 18, color: AppTheme.primaryLight),
                SizedBox(width: 10),
                Text('Add Manga Folder'),
              ]),
            ),
            PopupMenuItem(
              value: 'library',
              child: Row(children: [
                Icon(Icons.folder_open_rounded,
                    size: 18, color: AppTheme.primaryLight),
                SizedBox(width: 10),
                Text('Scan Library Root'),
              ]),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'refresh',
              child: Row(children: [
                Icon(Icons.refresh_rounded,
                    size: 18, color: AppTheme.onSurfaceMuted),
                SizedBox(width: 10),
                Text('Refresh'),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return RefreshIndicator(
      onRefresh: _loadLibrary,
      color: AppTheme.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _filteredMangas.length,
        itemBuilder: (ctx, i) {
          final manga = _filteredMangas[i];
          return MangaCard(
            manga: manga,
            onTap: () => _openManga(manga),
            onLongPress: () => _deleteManga(manga),
          );
        },
      ),
    );
  }

  void _openManga(Manga manga) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MangaScreen(manga: manga)),
    ).then((_) => _loadLibrary());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: AppTheme.primary,
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your library is empty',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a folder containing .cbz manga files\nto start reading',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.onSurfaceMuted),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _addSingleMangaFolder,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Manga Folder'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _addSingleMangaFolder,
      backgroundColor: AppTheme.accent,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add_rounded),
    );
  }
}
