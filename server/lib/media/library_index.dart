import 'package:nexus_shared/nexus_shared.dart';

import 'library_item.dart';
import 'library_scanner.dart';

/// Holds the current scan of the media library in memory. Rebuilt entirely
/// on [rescan] (a filesystem walk is cheap; the library is small) rather
/// than persisted - what *is* persisted is per-item playback position,
/// tracked separately on `Compound.playbackPositions` (keyed by the same
/// stable item id), so a rescan never loses watch progress.
class LibraryIndex {
  LibraryIndex(this.scanner);

  final LibraryScanner scanner;
  List<LibraryItem> _items = [];

  List<LibraryItem> get items => List.unmodifiable(_items);

  Future<void> rescan() async {
    _items = await scanner.scan();
  }

  LibraryItem? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  MediaLibraryStats stats() {
    final episodes = _items.where((i) => i.kind == LibraryItemKind.episode).toList();
    final movies = _items.where((i) => i.kind == LibraryItemKind.movie).length;
    final shows = episodes.map((i) => i.showTitle ?? i.title).toSet().length;
    return MediaLibraryStats(
      movieCount: movies,
      showCount: shows,
      episodeCount: episodes.length,
      photoCount: _items.where((i) => i.kind == LibraryItemKind.photo).length,
      trackCount: _items.where((i) => i.kind == LibraryItemKind.music).length,
    );
  }

  /// Photos, newest-scanned first, as the app-facing projection.
  List<LibraryEntry> photos({int limit = 60}) => _entriesOf(LibraryItemKind.photo, MediaKind.photo, limit);

  /// Music tracks as the app-facing projection.
  List<LibraryEntry> music({int limit = 200}) => _entriesOf(LibraryItemKind.music, MediaKind.music, limit);

  List<LibraryEntry> _entriesOf(LibraryItemKind from, MediaKind to, int limit) => _items
      .where((i) => i.kind == from)
      .take(limit)
      .map((i) => LibraryEntry(
            id: i.id,
            title: i.title,
            kind: to,
            durationSeconds: i.durationSeconds,
            subtitle: i.showTitle,
          ))
      .toList();

  /// Up to [limit] items, biased toward whatever already has playback
  /// progress (a real "continue watching" list); falls back to whatever the
  /// scan found first if nothing's been played yet.
  List<ContinueWatchingItem> continueWatching(Map<String, double> positions, {int limit = 6}) {
    // Watchable video only - photos and music have their own sections.
    final watchable = _items
        .where((i) => i.kind == LibraryItemKind.movie || i.kind == LibraryItemKind.episode)
        .toList();
    final withProgress = watchable.where((i) => (positions[i.id] ?? 0) > 0).toList()
      ..sort((a, b) => (positions[b.id] ?? 0).compareTo(positions[a.id] ?? 0));
    final chosen = withProgress.isNotEmpty ? withProgress : watchable;
    return chosen.take(limit).map((item) {
      return ContinueWatchingItem(
        id: item.id,
        title: item.displayTitle,
        durationSeconds: item.durationSeconds,
        positionSeconds: positions[item.id] ?? 0,
      );
    }).toList();
  }

  NowPlaying nowPlayingFor(LibraryItem item, Map<String, double> positions, {required bool isPlaying}) {
    return NowPlaying(
      itemId: item.id,
      title: item.displayTitle,
      year: item.year,
      genre: item.kind == LibraryItemKind.episode ? 'TV Show' : 'Movie',
      durationSeconds: item.durationSeconds,
      positionSeconds: positions[item.id] ?? 0,
      isPlaying: isPlaying,
    );
  }
}
