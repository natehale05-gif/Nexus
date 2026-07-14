import 'compound.dart';
import 'device.dart';
import 'enums.dart';
import 'insight.dart';

/// Section 6: proactive insights engine.
///
/// Pure function - takes a snapshot of the compound and returns a freshly
/// computed, prioritized list of insights. In the fuller build (Section 9,
/// build order step 10) this runs continuously server-side and is pushed to
/// the app over the WebSocket rather than computed client-side; the app's
/// local-demo-mode bootstrap also calls this directly on every state tick
/// so the UI is fully functional before the server exists.
List<Insight> computeInsights(Compound compound) {
  final insights = <Insight>[];
  var seq = 0;
  String nextId(String tag) => '${tag}_${seq++}';

  for (final node in compound.meshNodes) {
    if (!node.online) {
      insights.add(Insight(
        id: nextId('mesh_offline_${node.id}'),
        level: Level.crit,
        message: '${node.name} mesh node is offline',
        relatedDeviceId: node.id,
      ));
    } else if (node.batteryPercent < 30) {
      insights.add(Insight(
        id: nextId('mesh_battery_${node.id}'),
        level: Level.warn,
        message: '${node.name} mesh node battery at ${node.batteryPercent}%',
        relatedDeviceId: node.id,
      ));
    }
  }

  final now = DateTime.now();
  for (final device in compound.devices) {
    if (device is LockDevice && !device.locked) {
      final openedAt = device.openSince ?? now;
      final openMinutes = now.difference(openedAt).inMinutes;
      final durationText =
          openMinutes >= 1 ? ' for $openMinutes min' : '';
      insights.add(Insight(
        id: nextId('open_${device.id}'),
        level: Level.warn,
        message:
            '${device.name} has been ${device.isGate ? 'open' : 'unlocked'}$durationText',
        relatedDeviceId: device.id,
        relatedZoneId: compound.zoneOfBuilding(device.buildingId)?.id,
      ));
    }

    if (device is GrillDevice && device.on) {
      final probeText = device.probe != null
          ? ', probe ${device.probe!.round()}°'
          : '';
      insights.add(Insight(
        id: nextId('grill_on_${device.id}'),
        level: Level.warn,
        message:
            '${device.name} is running at ${device.set.round()}°$probeText',
        relatedDeviceId: device.id,
        relatedZoneId: compound.zoneOfBuilding(device.buildingId)?.id,
      ));

      if (device.pellets < 20) {
        insights.add(Insight(
          id: nextId('pellets_${device.id}'),
          level: Level.info,
          message: '${device.name} pellet hopper is low (${device.pellets}%)',
          relatedDeviceId: device.id,
          relatedZoneId: compound.zoneOfBuilding(device.buildingId)?.id,
        ));
      }
    }
  }

  final lightsOn = compound.devices
      .whereType<LightDevice>()
      .where((l) => l.on)
      .length;
  if (lightsOn >= 4) {
    insights.add(Insight(
      id: nextId('many_lights'),
      level: Level.info,
      message:
          '$lightsOn lights are on across the compound - run Away or Sleep?',
    ));
  }

  insights.sort((a, b) => b.level.index.compareTo(a.level.index));
  return insights;
}

/// Colors describing a zone pin's current visual state (Section 3, pin
/// color logic). This lives here (rather than in the app) so the server's
/// future push-based insights engine and the app's rendering agree on the
/// same computed semantics - only the actual color *values* live in the
/// app's theme.
enum ZonePinState { alert, caution, secure }

class ZoneStatus {
  const ZoneStatus({
    required this.state,
    required this.hasOfflineMeshNode,
    required this.anyOpenLock,
    required this.anyLightOrGrillOn,
  });

  final ZonePinState state;
  final bool hasOfflineMeshNode;
  final bool anyOpenLock;
  final bool anyLightOrGrillOn;
}

ZoneStatus computeZoneStatus(Compound compound, String zoneId) {
  final zoneDevices = compound.devicesOfZone(zoneId);
  final zone = compound.zones.firstWhere((z) => z.id == zoneId);

  final anyOpenLock = zoneDevices
      .whereType<LockDevice>()
      .any((l) => !l.locked);
  final anyLightOn = zoneDevices.whereType<LightDevice>().any((l) => l.on);
  final anyGrillOn = zoneDevices.whereType<GrillDevice>().any((g) => g.on);

  final hasOfflineMeshNode = zone.buildingIds.any((buildingId) {
    final node = compound.meshNodeOfBuilding(buildingId);
    return node != null && !node.online;
  });

  final ZonePinState state;
  if (anyOpenLock) {
    state = ZonePinState.alert;
  } else if (anyLightOn || anyGrillOn) {
    state = ZonePinState.caution;
  } else {
    state = ZonePinState.secure;
  }

  return ZoneStatus(
    state: state,
    hasOfflineMeshNode: hasOfflineMeshNode,
    anyOpenLock: anyOpenLock,
    anyLightOrGrillOn: anyLightOn || anyGrillOn,
  );
}
