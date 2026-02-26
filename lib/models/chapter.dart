// lib/models/chapter.dart
class Chapter {
  final String id;
  final String title;
  final String cbzPath;
  final String mangaId;
  final int chapterNumber;
  String? thumbnailCachePath;
  int? pageCount;

  Chapter({
    required this.id,
    required this.title,
    required this.cbzPath,
    required this.mangaId,
    required this.chapterNumber,
    this.thumbnailCachePath,
    this.pageCount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'cbzPath': cbzPath,
        'mangaId': mangaId,
        'chapterNumber': chapterNumber,
        'thumbnailCachePath': thumbnailCachePath,
        'pageCount': pageCount,
      };

  factory Chapter.fromMap(Map<String, dynamic> map) => Chapter(
        id: map['id'],
        title: map['title'],
        cbzPath: map['cbzPath'],
        mangaId: map['mangaId'],
        chapterNumber: map['chapterNumber'],
        thumbnailCachePath: map['thumbnailCachePath'],
        pageCount: map['pageCount'],
      );

  Chapter copyWith({
    String? thumbnailCachePath,
    int? pageCount,
  }) =>
      Chapter(
        id: id,
        title: title,
        cbzPath: cbzPath,
        mangaId: mangaId,
        chapterNumber: chapterNumber,
        thumbnailCachePath: thumbnailCachePath ?? this.thumbnailCachePath,
        pageCount: pageCount ?? this.pageCount,
      );
}
