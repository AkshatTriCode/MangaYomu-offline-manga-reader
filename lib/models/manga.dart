// lib/models/manga.dart
class Manga {
  final String id;
  final String title;
  final String folderPath;
  String? coverPath;
  int chapterCount;
  DateTime? lastRead;
  int? lastReadChapter;
  int? lastReadPage;

  Manga({
    required this.id,
    required this.title,
    required this.folderPath,
    this.coverPath,
    this.chapterCount = 0,
    this.lastRead,
    this.lastReadChapter,
    this.lastReadPage,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'folderPath': folderPath,
        'coverPath': coverPath,
        'chapterCount': chapterCount,
        'lastRead': lastRead?.millisecondsSinceEpoch,
        'lastReadChapter': lastReadChapter,
        'lastReadPage': lastReadPage,
      };

  factory Manga.fromMap(Map<String, dynamic> map) => Manga(
        id: map['id'],
        title: map['title'],
        folderPath: map['folderPath'],
        coverPath: map['coverPath'],
        chapterCount: map['chapterCount'] ?? 0,
        lastRead: map['lastRead'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['lastRead'])
            : null,
        lastReadChapter: map['lastReadChapter'],
        lastReadPage: map['lastReadPage'],
      );

  Manga copyWith({
    String? coverPath,
    int? chapterCount,
    DateTime? lastRead,
    int? lastReadChapter,
    int? lastReadPage,
  }) =>
      Manga(
        id: id,
        title: title,
        folderPath: folderPath,
        coverPath: coverPath ?? this.coverPath,
        chapterCount: chapterCount ?? this.chapterCount,
        lastRead: lastRead ?? this.lastRead,
        lastReadChapter: lastReadChapter ?? this.lastReadChapter,
        lastReadPage: lastReadPage ?? this.lastReadPage,
      );
}
