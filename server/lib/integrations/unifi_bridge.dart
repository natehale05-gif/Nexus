import 'dart:developer';

import 'integration.dart';

/// UniFi Protect/Network bridge (Section 8) - REST polling (~30s
/// interval) for camera list/network health where not already covered by
/// Frigate (e.g. mesh AP health, switch port status for wired devices).
///
/// Real implementation notes: UniFi's local API requires either the
/// legacy cookie-based auth or the newer API-key based UniFi OS
/// integrations API depending on controller version: poll
/// `/proxy/network/api/s/default/stat/device` for network health and
/// reconcile against known building locations.
class UniFiBridge extends Integration {
  UniFiBridge(super.server);

  @override
  String get name => 'unifi';

  @override
  Future<void> start() async {
    log('[$name] stub bridge started - would begin 30s REST polling here', name: 'nexus.unifi');
  }

  @override
  Future<void> stop() async {}
}
