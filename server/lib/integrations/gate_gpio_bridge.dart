import 'dart:developer';

import 'integration.dart';

/// Gate control bridge (Section 8) - a GPIO trigger pulse on a
/// Raspberry-Pi-class relay controller at each gate.
///
/// Real implementation notes: this is push-only (no useful "state" to
/// read back from a dumb relay), so [LockDevice.locked] for a gate is
/// really "believed open/closed" based on the last pulse sent plus
/// optionally a reed/contact sensor bridged in over Zigbee for ground
/// truth. Pulsing is a fire-and-forget HTTP call to the Pi (e.g. a tiny
/// `gpiozero`-backed Flask endpoint) or direct GPIO if the server itself
/// has GPIO access.
class GateGpioBridge extends Integration {
  GateGpioBridge(super.server);

  @override
  String get name => 'gate_gpio';

  @override
  Future<void> start() async {
    log('[$name] stub bridge started - would arm the GPIO relay trigger endpoint here', name: 'nexus.gate');
  }

  @override
  Future<void> stop() async {}

  /// Real implementation: send the pulse to the gate controller for
  /// [gateDeviceId]. Currently a no-op - [ServerCompound.setLocked] is
  /// what the demo/local state relies on instead.
  Future<void> pulse(String gateDeviceId) async {
    log('[$name] would pulse GPIO relay for $gateDeviceId', name: 'nexus.gate');
  }
}
