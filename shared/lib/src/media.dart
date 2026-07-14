/// Powers the Media tab's "Now Playing" hero card (Section 5).
class NowPlaying {
  NowPlaying({
    required this.title,
    required this.year,
    required this.genre,
    required this.runtimeMinutes,
    required this.progress,
    required this.isPlaying,
  });

  String title;
  int year;
  String genre;
  int runtimeMinutes;

  /// 0.0-1.0.
  double progress;
  bool isPlaying;

  Map<String, dynamic> toJson() => {
        'title': title,
        'year': year,
        'genre': genre,
        'runtimeMinutes': runtimeMinutes,
        'progress': progress,
        'isPlaying': isPlaying,
      };

  factory NowPlaying.fromJson(Map<String, dynamic> json) => NowPlaying(
        title: json['title'] as String,
        year: json['year'] as int,
        genre: json['genre'] as String,
        runtimeMinutes: json['runtimeMinutes'] as int,
        progress: (json['progress'] as num).toDouble(),
        isPlaying: json['isPlaying'] as bool,
      );
}

/// A poster tile in the "Continue Watching" grid.
class ContinueWatchingItem {
  ContinueWatchingItem({
    required this.id,
    required this.title,
    required this.progress,
  });

  String id;
  String title;
  double progress;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'progress': progress,
      };

  factory ContinueWatchingItem.fromJson(Map<String, dynamic> json) =>
      ContinueWatchingItem(
        id: json['id'] as String,
        title: json['title'] as String,
        progress: (json['progress'] as num).toDouble(),
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
