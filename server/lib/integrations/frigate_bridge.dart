import 'dart:developer';

import 'integration.dart';

/// Frigate bridge (Section 8) - powers the Security tab's camera grid and
/// motion alerts.
///
/// Real implementation notes:
/// - REST (`/api/config`, `/api/events`) for camera list + historical
///   events, mapped onto [Alert] entries.
/// - MQTT (`frigate/<camera>/events`, `frigate/available`) for live
///   motion/object-detection push events - this is what should actually
///   drive the LIVE/MOTION indicator dot, not polling.
/// - ffmpeg HLS restream (`frigate/<camera>/<quality>/stream`) proxied
///   or linked directly for the "Connect server to enable live feed"
///   panel once wired up.
class FrigateBridge extends Integration {
  FrigateBridge(super.server);

  @override
  String get name => 'frigate';

  @override
  Future<void> start() async {
    log('[$name] stub bridge started - would subscribe to frigate/+/events via MQTT here', name: 'nexus.frigate');
  }

  @override
  Future<void> stop() async {}
}
