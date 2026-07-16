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
  });

  factory ServerConfig.fromEnvironment() {
    final env = Platform.environment;
    return ServerConfig(
      bindAddress: env['NEXUS_BIND_ADDRESS'] ?? '0.0.0.0',
      wsPort: int.tryParse(env['NEXUS_WS_PORT'] ?? '') ?? 8765,
      restPort: int.tryParse(env['NEXUS_REST_PORT'] ?? '') ?? 8766,
      dataDir: env['NEXUS_DATA_DIR'] ?? _defaultDataDir(),
    );
  }

  final String bindAddress;
  final int wsPort;
  final int restPort;
  final String dataDir;

  File get pairingTokenFile => File('$dataDir/pairing_token');
  File get snapshotFile => File('$dataDir/state.json');

  static String _defaultDataDir() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.nexus';
  }
}
