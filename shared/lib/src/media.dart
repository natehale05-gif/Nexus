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

/// Powers the Media tab's 3-stat row.
class MediaLibraryStats {
  MediaLibraryStats({
    required this.movieCount,
    required this.showCount,
    required this.episodeCount,
  });

  int movieCount;
  int showCount;
  int episodeCount;

  Map<String, dynamic> toJson() => {
        'movieCount': movieCount,
        'showCount': showCount,
        'episodeCount': episodeCount,
      };

  factory MediaLibraryStats.fromJson(Map<String, dynamic> json) =>
      MediaLibraryStats(
        movieCount: json['movieCount'] as int,
        showCount: json['showCount'] as int,
        episodeCount: json['episodeCount'] as int,
      );
}
