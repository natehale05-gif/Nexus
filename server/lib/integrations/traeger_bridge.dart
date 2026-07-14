import 'dart:developer';

import 'package:nexus_shared/nexus_shared.dart';

import 'integration.dart';

/// Traeger WiFIRE (or equivalent smart-grill API) bridge (Section 8) -
/// the newest/most novel integration, and the one exception to "core
/// local functions aren't cloud-gated" (Section 1): grill control is
/// inherently cloud-dependent.
///
/// Real implementation notes (Traeger has no public official API, but
/// the protocol is thoroughly reverse-engineered - the Home Assistant
/// `traeger` custom component is a solid reference to study even though
/// NEXUS isn't built on Home Assistant):
/// 1. [authenticate] once with the user's Traeger account credentials via
///    their Cognito-backed login endpoint; store the resulting *refresh
///    token* (never the password) in the server's local secret store.
/// 2. [connect] opens an MQTT-over-WSS connection to AWS IoT Core using
///    short-lived credentials minted from that refresh token, then
///    subscribes to the grill's status topic for live chamber temp,
///    probe temp(s), set point, pellet level, and connection status.
/// 3. [setTemperature]/[setIgnite]/[setProbeTarget] publish commands back
///    over that same MQTT connection.
/// 4. If the refresh-token exchange or the MQTT connection fails (stale
///    token, internet down, AWS IoT outage, etc.), [GrillDevice.cloudOnline]
///    must flip to false so the UI shows the distinct "offline (cloud
///    unreachable)" state - never silently pretend the grill is just off.
///
/// This stub keeps [GrillDevice.cloudOnline] as whatever the demo seed
/// set it to and exposes [setCloudOnline] purely so the REST API can
/// simulate a cloud outage for UI testing without a real account.
class TraegerBridge extends Integration {
  TraegerBridge(super.server);

  @override
  String get name => 'traeger';

  bool _authenticated = false;

  @override
  Future<void> start() async {
    log('[$name] stub bridge started - would authenticate against Traeger Cognito here', name: 'nexus.traeger');
  }

  @override
  Future<void> stop() async {}

  Future<void> authenticate({required String username, required String password}) async {
    log('[$name] would exchange credentials for a refresh token and store it locally', name: 'nexus.traeger');
    _authenticated = true;
  }

  Future<void> connect() async {
    if (!_authenticated) {
      log('[$name] cannot connect - not authenticated yet', name: 'nexus.traeger');
      return;
    }
    log('[$name] would open MQTT-over-WSS to AWS IoT Core and subscribe to grill status here', name: 'nexus.traeger');
  }

  void setTemperature(String grillId, num fahrenheit) {
    server.setGrillTarget(grillId, fahrenheit);
    log('[$name] would publish a set-temperature command for $grillId', name: 'nexus.traeger');
  }

  void setIgnite(String grillId, bool ignite) {
    server.setGrillOn(grillId, ignite);
    log('[$name] would publish ${ignite ? "an ignite" : "a shutdown"} command for $grillId', name: 'nexus.traeger');
  }

  void setProbeTarget(String grillId, num? fahrenheit) {
    server.setProbeTarget(grillId, fahrenheit);
  }

  /// Demo/testing hook only - flips the "offline (cloud unreachable)"
  /// state without a real outage, since this environment has no Traeger
  /// account to actually disconnect from.
  void setCloudOnline(String grillId, bool online) {
    server.mutate(() {
      final grill = server.compound.devices.whereType<GrillDevice>().firstWhere((g) => g.id == grillId);
      grill.cloudOnline = online;
    });
  }
}
