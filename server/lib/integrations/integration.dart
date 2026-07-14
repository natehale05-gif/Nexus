import '../state/server_compound.dart';

/// Common lifecycle for every protocol bridge listed in Section 8.
///
/// **Why these are stubs:** this environment has no real Zigbee2MQTT/
/// Z-Wave JS UI/Frigate/UniFi/Jellyfin/Ollama instances, no Traeger
/// account credentials, and no physical mesh/GPIO hardware to bridge to.
/// Rather than faking a protocol implementation that would silently do
/// nothing useful (or worse, look real and mislead whoever wires this up
/// against actual hardware later), each bridge below is a documented,
/// honest interface plus the concrete wiring points a real implementation
/// needs to fill in. `SimulationTicker` (see `state/simulation_ticker.dart`)
/// stands in for all of them for demo purposes by mutating the same
/// [ServerCompound] they would otherwise feed.
abstract class Integration {
  Integration(this.server);

  final ServerCompound server;

  /// Human-readable name for logs/health checks.
  String get name;

  /// Begin bridging. Real implementations connect to the relevant
  /// subprocess/API/broker here; stub implementations just log their
  /// intended wiring.
  Future<void> start();

  Future<void> stop();
}
