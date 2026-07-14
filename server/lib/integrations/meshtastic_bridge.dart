import 'dart:developer';

import 'integration.dart';

/// Meshtastic LoRa mesh bridge (Section 8) - powers [MeshNode]
/// battery/online-status data, which in turn drives the red offline
/// badge on Home's zone pins and the "N mesh nodes offline" crit insight.
///
/// Real implementation notes:
/// - `meshtasticd` bridges LoRa packets onto Mosquitto; connect an MQTT
///   client and subscribe to `msh/US/+/json/{position,telemetry,text,
///   detection_sensor,nodeinfo}/+` (region prefix depends on deployment).
/// - `telemetry` messages carry battery percentage; absence of any
///   message from a node within its expected report interval is what
///   should flip [MeshNode.online] to false (a simple "last seen" timeout,
///   not a single dropped packet).
/// - `nodeinfo` messages carry the human-readable name to reconcile
///   against [Building.meshNodeId].
class MeshtasticBridge extends Integration {
  MeshtasticBridge(super.server);

  @override
  String get name => 'meshtastic';

  @override
  Future<void> start() async {
    log('[$name] stub bridge started - would subscribe to msh/US/+/json/... via MQTT here', name: 'nexus.meshtastic');
  }

  @override
  Future<void> stop() async {}
}
