import 'dart:io';

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
    );
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

  File get pairingTokenFile => File('$dataDir/pairing_token');
  File get snapshotFile => File('$dataDir/state.json');

  static String _defaultDataDir() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.nexus';
  }
}
