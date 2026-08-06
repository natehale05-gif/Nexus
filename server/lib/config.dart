import 'dart:io';

import 'package:nexus_shared/nexus_shared.dart';

import 'sync/sync_source.dart';

/// Server configuration, overridable via environment variables so a real
/// deployment (e.g. a launchd/systemd service) isn't stuck with the
/// hardcoded bind address/ports/data location. All are optional - the
/// defaults match the previous hardcoded behavior exactly.
class ServerConfig {
  ServerConfig({
    required this.bindAddress,
    required this.wsPort,
    required this.restPort,
    required this.dataDir,
    required this.mediaRoot,
    required this.driveRoot,
    required this.cameras,
    required this.syncSources,
  });

  factory ServerConfig.fromEnvironment() {
    final env = Platform.environment;
    final dataDir = env['NEXUS_DATA_DIR'] ?? _defaultDataDir();
    return ServerConfig(
      bindAddress: env['NEXUS_BIND_ADDRESS'] ?? '0.0.0.0',
      wsPort: int.tryParse(env['NEXUS_WS_PORT'] ?? '') ?? 8765,
      restPort: int.tryParse(env['NEXUS_REST_PORT'] ?? '') ?? 8766,
      dataDir: dataDir,
      mediaRoot: env['NEXUS_MEDIA_ROOT'] ?? '$dataDir/media',
      // Personal files, kept apart from the scanned media library: one is
      // yours to arrange, the other is the server's to index.
      driveRoot: env['NEXUS_DRIVE_ROOT'] ?? '$dataDir/drive',
      cameras: parseCameras(env['NEXUS_CAMERAS']),
      // Explicit sources win; otherwise use whichever of Apple's standard
      // folders actually exist on this machine, so a Mac with iCloud on
      // needs no configuration at all.
      syncSources: parseSyncSources(env['NEXUS_SYNC_SOURCES']).isNotEmpty
          ? parseSyncSources(env['NEXUS_SYNC_SOURCES'])
          : appleSyncCandidates(
              env['HOME'] ?? env['USERPROFILE'] ?? '',
              os: Platform.operatingSystem,
            ),
    );
  }

  /// Parses `NEXUS_CAMERAS`: a comma-separated list of `Name=streamUrl`
  /// pairs, e.g.
  ///   NEXUS_CAMERAS="Front Door=http://go2rtc:1984/api/stream.m3u8?src=front,Barn=..."
  /// A bare `Name` (no `=`) registers a camera with no stream yet, which
  /// the app shows as configured-but-not-streaming rather than hiding.
  static List<Camera> parseCameras(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final cameras = <Camera>[];
    for (final part in raw.split(',')) {
      final entry = part.trim();
      if (entry.isEmpty) continue;
      final split = entry.indexOf('=');
      final name = (split == -1 ? entry : entry.substring(0, split)).trim();
      final url = split == -1 ? null : entry.substring(split + 1).trim();
      if (name.isEmpty) continue;
      cameras.add(Camera(
        id: 'cam_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
        name: name,
        streamUrl: (url == null || url.isEmpty) ? null : url,
      ));
    }
    return cameras;
  }

  final String bindAddress;
  final int wsPort;
  final int restPort;
  final String dataDir;

  /// Filesystem root the media library scanner walks for movies/TV. Set
  /// `NEXUS_MEDIA_ROOT` to point this at a real library - defaults to a
  /// `media/` folder inside the data dir, which will just be empty until
  /// configured.
  final String mediaRoot;
  final String driveRoot;

  /// Security cameras declared via `NEXUS_CAMERAS` (see [parseCameras]).
  final List<Camera> cameras;

  /// Folders pulled into Drive - see sync/folder_sync.dart.
  final List<SyncSource> syncSources;

  File get pairingTokenFile => File('$dataDir/pairing_token');
  File get snapshotFile => File('$dataDir/state.json');

  static String _defaultDataDir() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.nexus';
  }
}
