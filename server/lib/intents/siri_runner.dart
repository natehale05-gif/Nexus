import 'package:nexus_shared/nexus_shared.dart';

import '../transport/command_dispatcher.dart';
import 'siri_surface.dart';

/// The answer to one spoken request.
class SiriResult {
  const SiriResult({
    required this.ok,
    required this.spoken,
    this.needsChoice = const [],
  });

  final bool ok;

  /// What Siri should say back. Written to be heard rather than read: short,
  /// and it names what it actually did, because you can't see the screen.
  final String spoken;

  /// Populated when the phrase matched several things and picking one for you
  /// would be a guess - Siri asks instead.
  final List<SiriTarget> needsChoice;

  Map<String, dynamic> toJson() => {
        'ok': ok,
        'spoken': spoken,
        if (needsChoice.isNotEmpty)
          'needsChoice': [for (final t in needsChoice) t.toJson()],
      };
}

/// Runs one intent from Siri.
///
/// Everything a spoken request can do passes through here, and it can only do
/// what [siriActions] lists. That is the enforcement point for "Siri gets the
/// whole app except the assistant": there is no branch that reaches chat, and
/// an action that isn't on the list is refused before anything is resolved,
/// let alone run.
SiriResult runSiriIntent(
  CommandDispatcher dispatcher,
  Compound compound, {
  required String action,
  String phrase = '',
  num? value,
}) {
  if (!allowed(action)) {
    // Deliberately not "unknown command": the interesting case is someone
    // reaching for the assistant, and the answer to that is that this door
    // doesn't lead there.
    return SiriResult(
      ok: false,
      spoken: "NEXUS can't do that from Siri.",
    );
  }

  final spec = siriActions.firstWhere((a) => a.name == action);

  if (!spec.needsTarget) {
    return switch (action) {
      'allLightsOff' => _run(dispatcher, 'turnOffAllLights', const {}, 'All lights are off.'),
      'compoundStatus' => SiriResult(ok: true, spoken: _compoundSummary(compound)),
      _ => const SiriResult(ok: false, spoken: "NEXUS can't do that from Siri."),
    };
  }

  final matches = resolveTargets(compound, phrase, kinds: _kindsFor(action));
  if (matches.isEmpty) {
    return SiriResult(
      ok: false,
      spoken: phrase.trim().isEmpty
          ? "Which one?"
          : "I couldn't find ${phrase.trim()} on the compound.",
    );
  }
  // Only ambiguous if the runners-up are just as good a match; an exact name
  // with a vaguer one behind it isn't a question worth asking.
  if (matches.length > 1 && _equallyGood(compound, phrase, matches)) {
    return SiriResult(
      ok: false,
      spoken: 'Which one - ${matches.take(3).map((t) => t.name).join(', ')}?',
      needsChoice: matches.take(5).toList(),
    );
  }

  final target = matches.first;
  return switch (action) {
    'turnOn' => _power(dispatcher, compound, target, true),
    'turnOff' => _power(dispatcher, compound, target, false),
    'setBrightness' => _run(
        dispatcher,
        'setBrightness',
        {'id': target.id, 'value': (value ?? 100).clamp(0, 100)},
        '${target.name} set to ${(value ?? 100).round()} percent.',
      ),
    'lock' => _lock(dispatcher, target, true),
    'unlock' => _lock(dispatcher, target, false),
    'setTemperature' => _run(
        dispatcher,
        'setClimateTarget',
        {'id': target.id, 'value': value ?? 70},
        '${target.name} set to ${(value ?? 70).round()} degrees.',
      ),
    'status' => SiriResult(ok: true, spoken: _statusOf(compound, target)),
    _ => const SiriResult(ok: false, spoken: "NEXUS can't do that from Siri."),
  };
}

/// Which kinds of thing an action can sensibly apply to.
///
/// Narrowing before matching is what stops "turn off the barn" picking the
/// building itself, and what makes "lock the barn" find the barn's gate.
Set<String>? _kindsFor(String action) => switch (action) {
      'turnOn' || 'turnOff' => {'light', 'media', 'grill'},
      'setBrightness' => {'light'},
      'lock' || 'unlock' => {'lock', 'gate'},
      'setTemperature' => {'climate'},
      _ => null,
    };

bool _equallyGood(Compound compound, String phrase, List<SiriTarget> matches) {
  // Re-resolve one at a time would be wasteful; instead treat "several things
  // whose names are all different from the phrase" as ambiguous, and a single
  // exact-name hit as decisive.
  final spoken = phrase.toLowerCase().trim();
  final exact = matches.where((t) => t.name.toLowerCase() == spoken).length;
  return exact != 1;
}

SiriResult _power(
  CommandDispatcher dispatcher,
  Compound compound,
  SiriTarget target,
  bool on,
) {
  final verb = on ? 'on' : 'off';
  return switch (target.kind) {
    // setLightOn rather than toggleLight: spoken commands have to be
    // definite, and voice can't check the current state first.
    'light' => _run(dispatcher, 'setLightOn', {'id': target.id, 'value': on},
        '${target.name} is $verb.'),
    'media' => _run(dispatcher, 'setMediaOn', {'id': target.id, 'value': on},
        '${target.name} is $verb.'),
    'grill' => _run(dispatcher, 'setGrillOn', {'id': target.id, 'value': on},
        '${target.name} is $verb.'),
    _ => SiriResult(ok: false, spoken: "${target.name} doesn't turn $verb."),
  };
}

SiriResult _lock(CommandDispatcher dispatcher, SiriTarget target, bool locked) {
  // A gate opens and closes; a door locks and unlocks. Same command, and
  // saying it the wrong way round is the kind of thing that makes an
  // assistant sound like a machine.
  final word = target.kind == 'gate'
      ? (locked ? 'closed' : 'open')
      : (locked ? 'locked' : 'unlocked');
  return _run(
    dispatcher,
    'setLocked',
    {'id': target.id, 'value': locked},
    '${target.name} is $word.',
  );
}

SiriResult _run(
  CommandDispatcher dispatcher,
  String command,
  Map<String, dynamic> args,
  String spoken,
) {
  try {
    dispatcher.dispatch(command, args);
    return SiriResult(ok: true, spoken: spoken);
  } on ArgumentError {
    return SiriResult(ok: false, spoken: "NEXUS couldn't do that.");
  }
}

String _statusOf(Compound compound, SiriTarget target) {
  final device = compound.devices.where((d) => d.id == target.id).firstOrNull;
  return switch (device) {
    LightDevice(on: final on, brightness: final b) =>
      on ? '${target.name} is on at $b percent.' : '${target.name} is off.',
    LockDevice(isGate: true, locked: final locked) =>
      '${target.name} is ${locked ? 'closed' : 'open'}.',
    LockDevice(locked: final locked) =>
      '${target.name} is ${locked ? 'locked' : 'unlocked'}.',
    ClimateDevice(temp: final t, set: final s) =>
      '${target.name} is ${t.round()} degrees, set to ${s.round()}.',
    MediaDevice(on: final on) => '${target.name} is ${on ? 'on' : 'off'}.',
    GrillDevice(on: final on, temp: final t) =>
      on ? '${target.name} is at ${t.round()} degrees.' : '${target.name} is off.',
    _ => _nonDeviceStatus(compound, target),
  };
}

String _nonDeviceStatus(Compound compound, SiriTarget target) {
  if (target.kind == 'vehicle') {
    final vehicle = compound.vehicles.where((v) => v.id == target.id).firstOrNull;
    if (vehicle != null) {
      return '${vehicle.name} is ${vehicle.status.name} at '
          '${vehicle.locationDescription}, battery ${vehicle.batteryPercent} percent.';
    }
  }
  if (target.kind == 'camera') {
    final camera = compound.cameras.where((c) => c.id == target.id).firstOrNull;
    if (camera != null) {
      return camera.hasMotion
          ? '${camera.name} is seeing motion.'
          : '${camera.name} is quiet.';
    }
  }
  return '${target.name} is fine.';
}

/// The one-breath answer to "how's the compound".
String _compoundSummary(Compound compound) {
  final alerts = compound.alerts.where((a) => a.level != Level.info).length;
  final lightsOn = compound.devices.whereType<LightDevice>().where((l) => l.on).length;
  final openLocks = compound.devices.whereType<LockDevice>().where((l) => !l.locked).toList();

  final parts = <String>[
    if (alerts == 0) 'No alerts' else '$alerts alert${alerts == 1 ? '' : 's'}',
    if (lightsOn > 0) '$lightsOn light${lightsOn == 1 ? '' : 's'} on',
    if (openLocks.isNotEmpty)
      '${openLocks.map((l) => l.name).join(' and ')} ${openLocks.length == 1 ? 'is' : 'are'} open',
  ];
  return '${parts.join(', ')}.';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
