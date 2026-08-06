library;

/// What Siri is allowed to do, and how it finds what you meant.
///
/// Siri talks to this rather than to [CommandDispatcher] directly, for two
/// reasons.
///
/// The first is the boundary. NEXUS's own assistant is deliberately *not*
/// reachable from here: pointing one assistant at another produces a game of
/// telephone where neither is accountable for the answer, and where a spoken
/// request could end up as an arbitrary prompt. That exclusion is enforced by
/// an allow-list rather than by remembering not to add it - see [allowed].
///
/// The second is resolution. "Turn off the barn lights" has to become a
/// device id, and doing that matching in Swift would mean a second
/// implementation that drifts from this one. The server owns the compound, so
/// the server does the matching.

import 'package:nexus_shared/nexus_shared.dart';

/// One thing Siri can do.
class SiriAction {
  const SiriAction({
    required this.name,
    required this.summary,
    required this.command,
    this.needsTarget = true,
  });

  /// The verb, as the intent layer names it.
  final String name;

  /// One line, for the shortcut list Apple shows.
  final String summary;

  /// The [CommandDispatcher] command this maps to, or empty when there isn't
  /// a single one - "turn on" is `setLightOn` for a light and `setMediaOn`
  /// for a TV, so the runner picks it from the target's kind - and for the
  /// status actions, which read rather than command.
  final String command;

  /// False for compound-wide actions that don't name a thing.
  final bool needsTarget;
}

/// Everything Siri may do - and, by omission, everything it may not.
///
/// Chat is absent on purpose. So is anything that changes the compound's
/// shape (adding or moving buildings and devices): a misheard word should
/// never rearrange the property, and those are all deliberate,
/// look-at-the-screen actions anyway.
const siriActions = <SiriAction>[
  SiriAction(
    name: 'turnOn',
    summary: 'Turn something on',
    command: '',
  ),
  SiriAction(
    name: 'turnOff',
    summary: 'Turn something off',
    command: '',
  ),
  SiriAction(
    name: 'setBrightness',
    summary: 'Dim or brighten a light',
    command: 'setBrightness',
  ),
  SiriAction(
    name: 'lock',
    summary: 'Lock a door, or close a gate',
    command: 'setLocked',
  ),
  SiriAction(
    name: 'unlock',
    summary: 'Unlock a door, or open a gate',
    command: 'setLocked',
  ),
  SiriAction(
    name: 'setTemperature',
    summary: 'Set a thermostat',
    command: 'setClimateTarget',
  ),
  SiriAction(
    name: 'allLightsOff',
    summary: 'Turn every light off',
    command: 'turnOffAllLights',
    needsTarget: false,
  ),
  SiriAction(
    name: 'status',
    summary: 'Ask how something is',
    command: '',
  ),
  SiriAction(
    name: 'compoundStatus',
    summary: 'Ask how the compound is',
    command: '',
    needsTarget: false,
  ),
];

/// True if Siri may run [action].
bool allowed(String action) => siriActions.any((a) => a.name == action);

/// Something Siri can act on or ask about.
class SiriTarget {
  const SiriTarget({
    required this.id,
    required this.name,
    required this.kind,
    this.detail = '',
  });

  final String id;
  final String name;

  /// `light`, `lock`, `gate`, `climate`, `media`, `grill`, `camera`,
  /// `building`, `room` or `vehicle`.
  final String kind;

  /// Where it is, so a spoken answer can say "the barn light" rather than
  /// leaving you to guess which one it picked.
  final String detail;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'kind': kind, 'detail': detail};
}

/// Everything in the compound Siri could name, flattened.
List<SiriTarget> siriTargets(Compound compound) {
  String where(Device device) {
    final building = compound.buildings
        .where((b) => b.id == device.buildingId)
        .map((b) => b.name)
        .firstOrNull;
    final room = device.roomId == null
        ? null
        : compound.rooms.where((r) => r.id == device.roomId).map((r) => r.name).firstOrNull;
    return [if (room != null) room, if (building != null) building].join(', ');
  }

  return [
    for (final device in compound.devices)
      SiriTarget(
        id: device.id,
        name: device.name,
        kind: _kindOf(device),
        detail: where(device),
      ),
    for (final building in compound.buildings)
      SiriTarget(id: building.id, name: building.name, kind: 'building'),
    for (final room in compound.rooms)
      SiriTarget(
        id: room.id,
        name: room.name,
        kind: 'room',
        detail: compound.buildings
                .where((b) => b.id == room.buildingId)
                .map((b) => b.name)
                .firstOrNull ??
            '',
      ),
    for (final vehicle in compound.vehicles)
      SiriTarget(id: vehicle.id, name: vehicle.name, kind: 'vehicle'),
    for (final camera in compound.cameras)
      SiriTarget(id: camera.id, name: camera.name, kind: 'camera'),
  ];
}

/// Exhaustive on purpose - no default case. Device is sealed, so adding a
/// new kind of device stops compiling here until someone decides what Siri
/// should call it, rather than silently landing in a bucket named "device"
/// that no phrase will ever match.
String _kindOf(Device device) => switch (device) {
      LightDevice() => 'light',
      LockDevice(isGate: true) => 'gate',
      LockDevice() => 'lock',
      ClimateDevice() => 'climate',
      MediaDevice() => 'media',
      GrillDevice() => 'grill',
    };

/// The kind a phrase is asking about, when it says so.
///
/// "Main thermostat" and "Barn Main Floor" share the word "main", which was
/// enough to have Siri switch off a light in another building when asked
/// about a thermostat. The noun in the phrase is the strongest signal
/// available, so when there is one it filters rather than merely scores.
const _kindWords = <String, String>{
  'light': 'light',
  'lamp': 'light',
  'lighting': 'light',
  'thermostat': 'climate',
  'heat': 'climate',
  'heating': 'climate',
  'ac': 'climate',
  'climate': 'climate',
  'temperature': 'climate',
  'gate': 'gate',
  'lock': 'lock',
  'door': 'lock',
  'tv': 'media',
  'television': 'media',
  'media': 'media',
  'grill': 'grill',
  'smoker': 'grill',
  'traeger': 'grill',
  'camera': 'camera',
  'cam': 'camera',
  'building': 'building',
  'room': 'room',
  'truck': 'vehicle',
  'vehicle': 'vehicle',
  'car': 'vehicle',
};

/// The kinds a phrase explicitly names, if any.
Set<String> kindsNamedIn(String phrase) {
  final named = <String>{};
  for (final word in _normalize(phrase).split(' ')) {
    final kind = _kindWords[word];
    if (kind != null) named.add(kind);
  }
  // A "door" might be a gate on a compound, and asking for one shouldn't
  // exclude the other.
  if (named.contains('lock')) named.add('gate');
  if (named.contains('gate')) named.add('lock');
  return named;
}

/// Finds what a spoken phrase meant.
///
/// Speech recognition gives you words, not ids, and it rarely gives you the
/// exact name: "barn lights" for "Barn Light", "the front door" for "Front
/// Door". So matching is deliberately loose, and ordered - an exact name beats
/// a prefix, which beats a word overlap - and returns everything that matched
/// so the caller can ask when it's genuinely ambiguous rather than guessing.
List<SiriTarget> resolveTargets(
  Compound compound,
  String phrase, {
  Set<String>? kinds,
}) {
  final query = _normalize(phrase);
  if (query.isEmpty) return const [];
  final words = query.split(' ').where((w) => w.length > 2).toSet();
  final named = kindsNamedIn(phrase);

  final scored = <(int, SiriTarget)>[];
  for (final target in siriTargets(compound)) {
    if (kinds != null && !kinds.contains(target.kind)) continue;
    final name = _normalize(target.name);
    int score;
    if (name == query) {
      score = 100;
    } else if (name.startsWith(query) || query.startsWith(name)) {
      score = 80;
    } else if (name.contains(query) || query.contains(name)) {
      score = 60;
    } else {
      // Word overlap, so "barn lights" still finds "Barn Light" - and so
      // that naming a room or building narrows to things inside it.
      final nameWords = name.split(' ').toSet();
      final overlap = nameWords.intersection(words).length;
      if (overlap == 0) continue;
      // A phrase that names a kind must match that kind. Otherwise one word
      // in common is enough to reach across the compound and switch off
      // something nobody mentioned.
      if (named.isNotEmpty && !named.contains(target.kind)) continue;
      score = 20 + overlap * 5;
      if (_normalize(target.detail).split(' ').toSet().intersection(words).isNotEmpty) {
        score += 10;
      }
    }
    scored.add((score, target));
  }

  scored.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    return byScore != 0 ? byScore : a.$2.name.compareTo(b.$2.name);
  });
  return [for (final entry in scored) entry.$2];
}

/// Lowercase, punctuation-free, singularised enough for speech.
///
/// "Lights" and "light" have to match, and Siri will hand over anything from
/// "the Barn's lights" to "barn lights please".
String _normalize(String raw) {
  final cleaned = raw
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  const filler = {'the', 'a', 'an', 'my', 'please', 'in', 'on', 'at', 'to'};
  return [
    for (final word in cleaned.split(' '))
      if (word.isNotEmpty && !filler.contains(word)) _singular(word),
  ].join(' ');
}

String _singular(String word) {
  if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
