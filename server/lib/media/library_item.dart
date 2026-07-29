/// A single scanned library file - a movie, TV episode, photo, or music
/// track. Server-side only: the app sees the `nexus_shared` projections
/// ([ContinueWatchingItem]/[NowPlaying]/[LibraryEntry]) built from these,
/// referencing them by [id].
enum LibraryItemKind { movie, episode, photo, music }

class LibraryItem {
  LibraryItem({
    required this.id,
    required this.path,
    required this.title,
    required this.kind,
    required this.durationSeconds,
    this.year,
    this.showTitle,
    this.seasonNumber,
    this.episodeNumber,
  });

  /// Stable hash of the file's path relative to the library root (see
  /// `library_scanner.dart`) - stays the same across rescans as long as the
  /// file doesn't move, so playback position survives a rescan.
  final String id;

  /// Absolute path on disk.
  final String path;

  final String title;
  final int? year;
  final LibraryItemKind kind;

  /// Episodes only.
  final String? showTitle;
  final int? seasonNumber;
  final int? episodeNumber;

  final double durationSeconds;

  /// Display title for UI lists - "Show · S1E2" for episodes, the movie
  /// title (+ year) otherwise.
  String get displayTitle {
    if (kind == LibraryItemKind.episode) {
      final show = showTitle ?? title;
      if (seasonNumber != null && episodeNumber != null) {
        return '$show · S${seasonNumber}E$episodeNumber';
      }
      return show;
    }
    return year == null ? title : '$title ($year)';
  }
}
