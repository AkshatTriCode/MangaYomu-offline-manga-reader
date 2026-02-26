# 読むMangaView — Offline Manga Reader

An offline Android manga reader made with flutter.
---

## Features

- **Smart Scanning**: Add a single manga folder OR a root library folder containing multiple manga
- **Read Progress**: Remembers your last read chapter and page, shows "Continue" button
- **Dark Theme**: Beautiful dark UI with purple/pink accents

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

=======
# MangaYomu---offline-manga-reader-app
An offline Android manga reader built with Flutter.
>>>>>>> 2e07716fa6411298dd600771b2a014c122e4bfc8
