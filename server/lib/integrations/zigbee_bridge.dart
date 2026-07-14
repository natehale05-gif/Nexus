import 'dart:developer';

import 'integration.dart';

/// Zigbee bridge via Zigbee2MQTT (Section 8).
///
/// Real implementation notes:
/// - Run `zigbee2mqtt` as a managed subprocess (or connect to an
///   already-running instance) and connect an MQTT client (e.g.
///   `package:mqtt_client`) to its broker.
/// - Subscribe to `zigbee2mqtt/<friendly_name>` for state updates and
///   publish to `zigbee2mqtt/<friendly_name>/set` for commands, mapping
///   friendly names to [Device.id]s via a persisted pairing table.
/// - Zigbee2MQTT also publishes `zigbee2mqtt/bridge/devices` - useful for
///   the Add Accessory scan step's discovery results.
class ZigbeeBridge extends Integration {
  ZigbeeBridge(super.server);

  @override
  String get name => 'zigbee';

  @override
  Future<void> start() async {
    log('[$name] stub bridge started - would connect to Zigbee2MQTT MQTT broker here', name: 'nexus.zigbee');
  }

  @override
  Future<void> stop() async {}
}
