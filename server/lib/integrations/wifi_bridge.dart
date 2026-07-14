import 'dart:developer';

import 'integration.dart';

/// WiFi device bridge (Tuya, Shelly, Sengled, etc.) - Section 8.
///
/// Real implementation notes:
/// - mDNS discovery (`multicast_dns` package) to find devices on the LAN,
///   matched against known vendor service types (e.g. `_shelly._tcp`).
/// - Prefer each device's local HTTP API for state + control once
///   discovered (most Shelly/Tuya-local-firmware devices expose one).
/// - Fall back to the vendor's cloud API only where no local API exists
///   (e.g. stock Tuya cloud devices without local-key extraction) -
///   Section 1 is explicit that core local functions should not be
///   cloud-gated, so this fallback should be the exception, not the rule.
/// - Each discovered device maps to a [LightDevice] (or other type) in
///   the shared model; poll/subscribe to its native push mechanism where
///   available instead of pure polling.
class WifiBridge extends Integration {
  WifiBridge(super.server);

  @override
  String get name => 'wifi';

  @override
  Future<void> start() async {
    log('[$name] stub bridge started - would begin mDNS discovery here', name: 'nexus.wifi');
  }

  @override
  Future<void> stop() async {}
}
