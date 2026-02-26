# MangaView — Offline Manga Reader

An offline Android manga reader with chapter thumbnail preview — the feature Mihon doesn't have.

---

## Features

- **Chapter Thumbnail Grid** (main feature): Instead of boring chapter lists, each chapter shows a thumbnail of its first page
- **Show More / Show All**: Initially shows 6 chapters, "Show more" loads 12 at a time, "Show all" shows everything at once
- **Full-Screen Reader**: Zoomable reader with page slider, swipe between pages, prev/next chapter navigation
- **CBZ Support**: Reads `.cbz` (Comic Book Zip) format — compatible with Mihon downloads
- **Smart Scanning**: Add a single manga folder OR a root library folder containing multiple manga
- **Read Progress**: Remembers your last read chapter and page, shows "Continue" button
- **Dark Theme**: Beautiful dark UI with purple/pink accents

---

## Project Structure

```
lib/
  main.dart                          # App entry point
  theme/app_theme.dart               # Dark theme colors
  models/
    manga.dart                       # Manga series model
    chapter.dart                     # Chapter model  
  services/
    cbz_service.dart                 # CBZ parsing & thumbnail extraction
    library_service.dart             # Database, folder scanning
  screens/
    library_screen.dart              # Home screen — manga grid
    manga_screen.dart                # Manga detail + THUMBNAIL GRID
    reader_screen.dart               # Full-screen reader
  widgets/
    chapter_thumbnail_grid.dart      # ★ THE MAIN FEATURE WIDGET
    chapter_card.dart                # Individual chapter thumbnail
    manga_card.dart                  # Manga series card
```

---

## Setup & Build

### Prerequisites
- Flutter SDK >= 3.0.0
- Android SDK 21+ (Android 5.0+)

### Install & Run

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build release APK
flutter build apk --release
```

### Android Permissions

For Android 11+ (API 30+), the app requests `MANAGE_EXTERNAL_STORAGE` permission.
You may need to manually grant it via:
**Settings → Apps → MangaView → Permissions → Files and Media → Allow management of all files**

---

## How to Use

1. **Open the app** → empty library screen
2. **Tap the + button** → select a folder containing `.cbz` files  
   - *Single manga*: Select the folder that directly contains `.cbz` chapter files  
   - *Library root*: Use "Scan Library Root" from the menu to scan a folder containing multiple manga sub-folders
3. **The app scans** all `.cbz` files and auto-generates chapter thumbnails
4. **Tap any manga** → see the chapter thumbnail grid
5. **Tap Show more** to reveal more chapters, **Show all** for everything
6. **Tap any chapter thumbnail** → opens full-screen reader
7. **In reader**: Swipe left/right to turn pages, tap the center to show/hide controls, use the slider to jump to any page

---

## Folder Structure Expected

### Option A: Single Manga Folder
```
MyManga/
  Chapter 001.cbz
  Chapter 002.cbz
  Chapter 003.cbz
  ...
```

### Option B: Library Root
```
MangaLibrary/
  Naruto/
    ch001.cbz
    ch002.cbz
  OnePiece/
    ch001.cbz
    ch002.cbz
```

---

## Dependencies

| Package | Purpose |
|---|---|
| `archive` | Read/parse CBZ (ZIP) files |
| `path_provider` | App cache directory |
| `permission_handler` | Android storage permissions |
| `file_picker` | Folder selection UI |
| `photo_view` | Zoomable page viewer |
| `sqflite` | Local manga database |
| `shared_preferences` | Library path settings |

---

## The Main Feature — Chapter Thumbnail Grid

The `ChapterThumbnailGrid` widget in `lib/widgets/chapter_thumbnail_grid.dart` is the core feature.

- Shows **3-column thumbnail grid** of chapter cover images
- **Initially shows 6 chapters**
- **"Show more" button**: Loads 12 more each press
- **"Show all" button**: Expands to all chapters at once  
- **Collapse button**: Collapses back to initial view
- Thumbnails are extracted from the first page of each `.cbz` and **cached locally**
- Loading state shows shimmer animations while thumbnails generate

