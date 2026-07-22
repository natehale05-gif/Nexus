/// Shared types for the [DownloadManager] (see `download_manager.dart` and
/// its platform implementations). Pure Dart - no platform imports - so both
/// the native and web implementations can re-export it.
library;

/// Where a given library item stands with respect to being saved on *this*
/// device for offline playback. Downloads are per-device local state, not
/// part of the server-synced compound.
enum DownloadStatus {
  /// Not saved locally - plays by streaming from the server.
  notDownloaded,

  /// Currently being fetched to local storage.
  downloading,

  /// Fully saved locally - plays from disk, works with no server/internet.
  downloaded,

  /// The last download attempt failed (offer a retry).
  failed,
}

/// A library item saved locally for offline playback.
class DownloadedItem {
  const DownloadedItem({
    required this.id,
    required this.title,
    required this.durationSeconds,
  });

  final String id;
  final String title;
  final double durationSeconds;
}
