import 'dart:developer';

import 'integration.dart';

/// Z-Wave bridge via Z-Wave JS UI (Section 8).
///
/// Real implementation notes: same MQTT/WS bridge pattern as
/// [ZigbeeBridge] - Z-Wave JS UI exposes both an MQTT gateway and a raw
/// WebSocket API; either works, but MQTT keeps the topic-subscription
/// model consistent with the Zigbee and Meshtastic bridges.
class ZWaveBridge extends Integration {
  ZWaveBridge(super.server);

  @override
  String get name => 'zwave';

  @override
  Future<void> start() async {
    log('[$name] stub bridge started - would connect to Z-Wave JS UI here', name: 'nexus.zwave');
  }

  @override
  Future<void> stop() async {}
}
