import 'package:flutter/foundation.dart';

import 'download_types.dart';

export 'download_types.dart';

/// Web stub [DownloadManager]. A browser has no app-managed filesystem to
/// save large video into for offline in-app playback, so offline downloads
/// are a native-only feature: here everything is a no-op and `isSupported`
/// is `false`, which the Media tab uses to hide download affordances.
/// Streaming still works on web when online. See `download_manager.dart`.
class DownloadManager extends ChangeNotifier {
  DownloadManager({Object? directoryOverride});

  bool get isSupported => false;

  Future<void> load() async {}

  DownloadStatus statusFor(String itemId) => DownloadStatus.notDownloaded;

  double progressFor(String itemId) => 0;

  List<DownloadedItem> get downloaded => const [];

  Uri? localUri(String itemId) => null;

  Future<void> download(
    String itemId,
    Uri source, {
    String title = '',
    double durationSeconds = 0,
  }) async {}

  Future<void> delete(String itemId) async {}
}
