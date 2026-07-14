import 'dart:developer';

import 'integration.dart';

/// Jellyfin bridge (Section 8) - powers the Media tab.
///
/// Real implementation notes:
/// - REST (`/Users/{id}/Items/Resume`, `/Items/Counts`) for library stats
///   and Continue Watching, mapped onto [MediaLibraryStats] /
///   [ContinueWatchingItem].
/// - WebSocket (`/socket`) for live "now playing" session state -
///   Jellyfin pushes `Sessions` messages on playback changes rather than
///   requiring polling, mapped onto [NowPlaying].
class JellyfinBridge extends Integration {
  JellyfinBridge(super.server);

  @override
  String get name => 'jellyfin';

  @override
  Future<void> start() async {
    log('[$name] stub bridge started - would open a Jellyfin session WebSocket here', name: 'nexus.jellyfin');
  }

  @override
  Future<void> stop() async {}
}
