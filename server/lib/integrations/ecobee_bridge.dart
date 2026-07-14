import 'dart:developer';

import 'integration.dart';

/// Ecobee bridge (Section 8) - only relevant if the compound has any
/// Ecobee-branded thermostats; otherwise [ClimateDevice] is driven by
/// whatever local thermostat protocol is in use (often folded into the
/// Zigbee/Z-Wave bridges instead).
///
/// Real implementation notes:
/// - OAuth2 PIN-based authorization flow against the official Ecobee API,
///   storing the refresh token in the same local secret store described
///   for Traeger below.
/// - Poll `/1/thermostat` (Ecobee has no push/webhook API) at a
///   reasonable interval (they rate-limit aggressively) and map
///   `runtime.actualTemperature` / `desiredHeat` / `desiredCool` /
///   `hvacMode` onto [ClimateDevice].
class EcobeeBridge extends Integration {
  EcobeeBridge(super.server);

  @override
  String get name => 'ecobee';

  @override
  Future<void> start() async {
    log('[$name] stub bridge started - would poll the Ecobee API here', name: 'nexus.ecobee');
  }

  @override
  Future<void> stop() async {}
}
