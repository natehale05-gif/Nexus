import 'package:nexus_shared/nexus_shared.dart';
import '../../state/compound_store.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  ChatMessage({required this.role, required this.text, DateTime? time}) : time = time ?? DateTime.now();
  final ChatRole role;
  final String text;
  final DateTime time;
}

/// Section 5: "System prompt context must include, live, on every
/// request: building names, which lights are on, which locks are open,
/// grill status per grill..., current media playback, mesh node health
/// summary, weather, vehicle locations, and any active proactive
/// insights." This is what a real Ollama-backed server would prepend to
/// every completion request (Section 8) - built here so the local-demo
/// stub can reason over the same context.
String buildSystemContext(Compound compound) {
  final buildings = compound.buildings.map((b) => b.name).join(', ');
  final lightsOn = compound.devices.whereType<LightDevice>().where((l) => l.on).map((l) => l.name).toList();
  final openLocks = compound.devices.whereType<LockDevice>().where((l) => !l.locked).map((l) => l.name).toList();
  final grills = compound.devices.whereType<GrillDevice>().map((g) {
    final probe = g.probe != null ? ', probe ${g.probe!.round()}°/${g.probeTarget?.round()}°' : '';
    return '${g.name}: ${g.on ? "on, ${g.temp.round()}°/${g.set.round()}°$probe, pellets ${g.pellets}%" : "off"}${g.cloudOnline ? "" : " (cloud unreachable)"}';
  }).join('; ');
  final media = compound.nowPlaying == null
      ? 'nothing playing'
      : '${compound.nowPlaying!.title} (${compound.nowPlaying!.isPlaying ? "playing" : "paused"})';
  final meshSummary = compound.meshNodes
      .map((m) => '${m.name}: ${m.online ? "online ${m.batteryPercent}%" : "OFFLINE"}')
      .join('; ');
  final vehicles = compound.vehicles.map((v) => '${v.name}: ${v.locationDescription}').join('; ');
  final insights = compound.insights.map((i) => '[${i.level.name}] ${i.message}').join('; ');
  final weather = compound.weather;

  return '''
Buildings: $buildings
Lights on: ${lightsOn.isEmpty ? 'none' : lightsOn.join(', ')}
Open locks/gates: ${openLocks.isEmpty ? 'none' : openLocks.join(', ')}
Grills: ${grills.isEmpty ? 'none' : grills}
Media: $media
Mesh health: $meshSummary
Weather: ${weather == null ? 'unknown' : '${weather.tempF.round()}°F, ${weather.condition}'}
Vehicles: $vehicles
Active insights: ${insights.isEmpty ? 'none' : insights}
''';
}

/// Simplified stand-in for the real build's `<action>`-tag parsing
/// (Section 8) - matches a handful of the suggestion-chip intents against
/// live compound state and, where applicable, actually mutates the store
/// before replying.
String generateAssistantReply(String userText, CompoundStore store) {
  final compound = store.compound;
  final text = userText.toLowerCase();

  if (text.contains('turn off all lights') || text.contains('all lights off')) {
    final onCount = compound.devices.whereType<LightDevice>().where((l) => l.on).length;
    store.turnOffAllLights();
    return onCount == 0
        ? 'All lights were already off.'
        : 'Done - turned off $onCount light${onCount == 1 ? '' : 's'} across the compound.';
  }

  if (text.contains('run movie mode')) {
    for (final light in compound.devices.whereType<LightDevice>()) {
      if (light.buildingId == 'main') {
        store.setBrightness(light.id, light.roomId == 'main_living' ? 15 : 0);
      }
    }
    final appleTv = compound.devices.whereType<MediaDevice>().where((m) => m.buildingId == 'main').firstOrNull;
    if (appleTv != null) store.setMediaOn(appleTv.id, true);
    return "Movie mode is on - dimmed the main house lights and turned on the Apple TV. Enjoy.";
  }

  if (text.contains("what's playing") || text.contains('whats playing') || text.contains('now playing')) {
    final np = compound.nowPlaying;
    if (np == null) return 'Nothing is playing right now.';
    return '${np.title} (${np.year}) is ${np.isPlaying ? 'playing' : 'paused'}, ${(np.progress * 100).round()}% through.';
  }

  if (text.contains('any alerts') || text.contains('alerts?')) {
    final active = compound.alerts.where((a) => a.level != Level.info).toList();
    if (active.isEmpty) return 'No active alerts - everything looks quiet.';
    return active.map((a) => '${a.level == Level.crit ? "Critical" : "Warning"}: ${a.message} (${a.source})').join('\n');
  }

  if (text.contains('brisket') || text.contains('probe') || text.contains('grill') || text.contains('smoker')) {
    final grill = compound.devices.whereType<GrillDevice>().firstOrNull;
    if (grill == null) return "I don't see a grill on the network.";
    if (!grill.cloudOnline) return '${grill.name} is offline - the Traeger cloud connection is unreachable right now.';
    if (!grill.on) return '${grill.name} is off.';
    if (grill.probe == null) {
      return '${grill.name} is preheating - ${grill.temp.round()}° of ${grill.set.round()}°. No probe connected yet.';
    }
    final remaining = (grill.probeTarget! - grill.probe!).round();
    if (remaining <= 0) {
      return "It's done - probe hit ${grill.probe!.round()}°, target was ${grill.probeTarget!.round()}°.";
    }
    return "Chamber's holding ${grill.temp.round()}°, probe is at ${grill.probe!.round()}° - about $remaining° to go to ${grill.probeTarget!.round()}°.";
  }

  final gateMatch = RegExp(r'open (?:the )?([a-z ]+?) (gate|door)').firstMatch(text);
  if (gateMatch != null) {
    final query = gateMatch.group(1)!.trim();
    final candidates = store.devicesMatchingName(query).whereType<LockDevice>().toList();
    if (candidates.isNotEmpty) {
      final lock = candidates.first;
      store.setLocked(lock.id, false);
      return 'Opened ${lock.name}.';
    }
  }

  final whereMatch = RegExp(r'where is (?:the |my )?(.+?)\??$').firstMatch(text);
  if (whereMatch != null) {
    final query = whereMatch.group(1)!.trim();
    final vehicle = compound.vehicles.where((v) => v.name.toLowerCase().contains(query)).firstOrNull;
    if (vehicle != null) {
      return '${vehicle.name} is ${vehicle.locationDescription.toLowerCase()}, battery at ${vehicle.batteryPercent}%.';
    }
  }

  final lightsOn = compound.devices.whereType<LightDevice>().where((l) => l.on).length;
  final openLocks = compound.devices.whereType<LockDevice>().where((l) => !l.locked).length;
  return "I'm not fully wired to Ollama yet in this demo, but here's the current state: $lightsOn light"
      "${lightsOn == 1 ? '' : 's'} on, $openLocks lock${openLocks == 1 ? '' : 's'}/gate"
      "${openLocks == 1 ? '' : 's'} open. Try one of the suggestions below.";
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
