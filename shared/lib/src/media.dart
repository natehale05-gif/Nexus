/// Powers the Media tab's "Now Playing" hero card (Section 5).
///
/// [itemId] references a library item on the server (see
/// `server/lib/media/library_item.dart`) - it's what a client streams from
/// `GET /media/stream/<itemId>`. [durationSeconds]/[positionSeconds] are the
/// wire-format source of truth; [progress] and [runtimeMinutes] are derived
/// convenience getters for UI code, not persisted separately.
class NowPlaying {
  NowPlaying({
    required this.itemId,
    required this.title,
    this.year,
    this.genre,
    required this.durationSeconds,
    required this.positionSeconds,
    required this.isPlaying,
  });

  String itemId;
  String title;
  int? year;
  String? genre;
  double durationSeconds;
  double positionSeconds;
  bool isPlaying;

  int get runtimeMinutes => (durationSeconds / 60).round();

  /// 0.0-1.0, derived from [positionSeconds]/[durationSeconds].
  double get progress => durationSeconds <= 0 ? 0 : (positionSeconds / durationSeconds).clamp(0, 1);

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'title': title,
        'year': year,
        'genre': genre,
        'durationSeconds': durationSeconds,
        'positionSeconds': positionSeconds,
        'isPlaying': isPlaying,
      };

  factory NowPlaying.fromJson(Map<String, dynamic> json) => NowPlaying(
        itemId: json['itemId'] as String,
        title: json['title'] as String,
        year: json['year'] as int?,
        genre: json['genre'] as String?,
        durationSeconds: (json['durationSeconds'] as num).toDouble(),
        positionSeconds: (json['positionSeconds'] as num).toDouble(),
        isPlaying: json['isPlaying'] as bool,
      );
}

/// A poster tile in the "Continue Watching" grid - tapping one plays it
/// (see `NexusDataSource.playLibraryItem`).
class ContinueWatchingItem {
  ContinueWatchingItem({
    required this.id,
    required this.title,
    required this.durationSeconds,
    this.positionSeconds = 0,
  });

  String id;
  String title;
  double durationSeconds;
  double positionSeconds;

  /// 0.0-1.0, derived from [positionSeconds]/[durationSeconds].
  double get progress => durationSeconds <= 0 ? 0 : (positionSeconds / durationSeconds).clamp(0, 1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'durationSeconds': durationSeconds,
        'positionSeconds': positionSeconds,
      };

  factory ContinueWatchingItem.fromJson(Map<String, dynamic> json) =>
      ContinueWatchingItem(
        id: json['id'] as String,
        title: json['title'] as String,
        durationSeconds: (json['durationSeconds'] as num).toDouble(),
        positionSeconds: (json['positionSeconds'] as num?)?.toDouble() ?? 0,
      );
}

/// What kind of thing a library entry is. The server's scanner assigns
/// this from the file's extension (see `server/lib/media/`), and the Media
/// tab groups by it: movies/episodes play as video, photos show in a grid,
/// music plays as audio.
enum MediaKind { movie, episode, photo, music }

/// A single item in the library, used for the Photos and Music sections
/// (movies/TV keep their richer [ContinueWatchingItem]/[NowPlaying] shape).
class LibraryEntry {
  LibraryEntry({
    required this.id,
    required this.title,
    required this.kind,
    this.durationSeconds = 0,
    this.subtitle,
  });

  final String id;
  final String title;
  final MediaKind kind;

  /// Playable length for music; 0 for photos.
  final double durationSeconds;

  /// Secondary line - e.g. an album/folder name for music, or the folder a
  /// photo came from.
  final String? subtitle;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'durationSeconds': durationSeconds,
        'subtitle': subtitle,
      };

  factory LibraryEntry.fromJson(Map<String, dynamic> json) => LibraryEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        kind: MediaKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => MediaKind.movie,
        ),
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
        subtitle: json['subtitle'] as String?,
      );
}

/// Powers the Media tab's stat row.
class MediaLibraryStats {
  MediaLibraryStats({
    required this.movieCount,
    required this.showCount,
    required this.episodeCount,
    this.photoCount = 0,
    this.trackCount = 0,
  });

  int movieCount;
  int showCount;
  int episodeCount;
  int photoCount;
  int trackCount;

  Map<String, dynamic> toJson() => {
        'movieCount': movieCount,
        'showCount': showCount,
        'episodeCount': episodeCount,
        'photoCount': photoCount,
        'trackCount': trackCount,
      };

  factory MediaLibraryStats.fromJson(Map<String, dynamic> json) =>
      MediaLibraryStats(
        movieCount: json['movieCount'] as int,
        showCount: json['showCount'] as int,
        episodeCount: json['episodeCount'] as int,
        photoCount: json['photoCount'] as int? ?? 0,
        trackCount: json['trackCount'] as int? ?? 0,
      );
}
