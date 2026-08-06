import 'dart:io';

import 'package:nexus_server/integrations/integrations_manager.dart';
import 'package:nexus_server/intents/siri_runner.dart';
import 'package:nexus_server/intents/siri_surface.dart';
import 'package:nexus_server/media/library_index.dart';
import 'package:nexus_server/media/library_scanner.dart';
import 'package:nexus_server/state/server_compound.dart';
import 'package:nexus_server/transport/command_dispatcher.dart';
import 'package:nexus_shared/nexus_shared.dart';
import 'package:test/test.dart';

LibraryIndex _emptyLibrary() => LibraryIndex(LibraryScanner(Directory.systemTemp));

({ServerCompound server, CommandDispatcher dispatcher}) _harness() {
  final server = ServerCompound();
  final dispatcher = CommandDispatcher(server, IntegrationsManager(server), _emptyLibrary());
  return (server: server, dispatcher: dispatcher);
}

SiriResult _say(
  ({ServerCompound server, CommandDispatcher dispatcher}) h,
  String action, {
  String phrase = '',
  num? value,
}) =>
    runSiriIntent(h.dispatcher, h.server.compound,
        action: action, phrase: phrase, value: value);

void main() {
  group('the boundary', () {
    test('the assistant is not on the list of things Siri may do', () {
      // The whole point: Siri gets the app, not the app's own assistant.
      // Asserting on the catalog rather than on one call means adding chat
      // later would fail here rather than quietly working.
      expect(siriActions.map((a) => a.name), isNot(contains('chat')));
      expect(allowed('chat'), isFalse);
      expect(allowed('ask'), isFalse);
      expect(allowed('prompt'), isFalse);
    });

    test('asking Siri to chat is refused before anything is resolved', () {
      final h = _harness();
      final result = _say(h, 'chat', phrase: 'what should I cook tonight');
      expect(result.ok, isFalse);
      expect(result.spoken, contains("can't do that"));
    });

    test('an arbitrary command name cannot be smuggled through', () {
      final h = _harness();
      // Real dispatcher commands that are deliberately not spoken actions.
      for (final smuggled in ['addDevice', 'moveBuilding', 'rescanLibrary', 'setGrillCloudOnline']) {
        expect(_say(h, smuggled, phrase: 'anything').ok, isFalse,
            reason: '$smuggled is not a Siri action');
      }
    });

    test('every allowed action names a real dispatcher command or is a read', () {
      final h = _harness();
      for (final action in siriActions) {
        if (action.command.isEmpty) continue; // status reads touch nothing
        expect(
          () => h.dispatcher.dispatch(action.command, const {'id': 'nope'}),
          isNot(throwsA(predicate(
            (e) => e is ArgumentError && '$e'.contains('Unknown command'),
          ))),
          reason: '${action.name} maps to a command the server does not have',
        );
      }
    });
  });

  group('resolving what was said', () {
    test('finds a device by its exact name', () {
      final h = _harness();
      final light = h.server.compound.devices.whereType<LightDevice>().first;
      final matches = resolveTargets(h.server.compound, light.name);
      expect(matches.first.id, light.id);
    });

    test('a plural and some filler still find the thing', () {
      final h = _harness();
      final light = h.server.compound.devices.whereType<LightDevice>().first;
      final name = light.name.toLowerCase();
      // Speech gives you "the barn lights please", never "Barn Light".
      final plural = name.endsWith('s') ? name : '${name}s';
      expect(resolveTargets(h.server.compound, "the $plural please").first.id, light.id);
    });

    test('a shared word cannot reach across the compound', () {
      final h = _harness();
      // "Main Thermostat" and "Barn Main Floor" share exactly one word, which
      // used to be enough for "how is the main thermostat" to switch off a
      // light in another building.
      final climate = h.server.compound.devices.whereType<ClimateDevice>().firstOrNull;
      if (climate == null) return;
      final matches = resolveTargets(h.server.compound, climate.name);
      expect(matches.first.id, climate.id);
      expect(matches.every((t) => t.kind != 'light'), isTrue);
    });

    test('the noun in the phrase decides the kind', () {
      final h = _harness();
      expect(kindsNamedIn('turn off the barn lights'), contains('light'));
      expect(kindsNamedIn('set the thermostat'), contains('climate'));
      // A door on a compound is often a gate, so asking for one keeps both.
      expect(kindsNamedIn('lock the front door'), containsAll(['lock', 'gate']));
      expect(kindsNamedIn('the barn'), isEmpty);
    });

    test('a phrase that matches nothing resolves to nothing', () {
      final h = _harness();
      expect(resolveTargets(h.server.compound, 'submarine'), isEmpty);
    });

    test('an empty phrase is not a wildcard', () {
      // Returning everything here would make "turn off" hit whatever sorted
      // first, which is the worst possible behaviour for a spoken command.
      final h = _harness();
      expect(resolveTargets(h.server.compound, '   '), isEmpty);
    });

    test('kinds narrow the search, so "turn off" cannot pick a building', () {
      final h = _harness();
      final building = h.server.compound.buildings.first;
      final asAnything = resolveTargets(h.server.compound, building.name);
      expect(asAnything.any((t) => t.kind == 'building'), isTrue);

      final asSwitchable =
          resolveTargets(h.server.compound, building.name, kinds: {'light', 'media', 'grill'});
      expect(asSwitchable.every((t) => t.kind != 'building'), isTrue);
    });
  });

  group('doing things', () {
    test('turning a light off turns it off, rather than toggling it', () {
      final h = _harness();
      final light = h.server.compound.devices.whereType<LightDevice>().first..on = false;

      final result = _say(h, 'turnOff', phrase: light.name);

      // A toggle would have turned it back on - which is exactly the bug that
      // makes a voice assistant untrustworthy.
      expect(result.ok, isTrue);
      expect(light.on, isFalse);
      expect(result.spoken, contains('off'));
    });

    test('turning a light on is equally definite', () {
      final h = _harness();
      final light = h.server.compound.devices.whereType<LightDevice>().first..on = true;
      _say(h, 'turnOn', phrase: light.name);
      expect(light.on, isTrue);
    });

    test('setting brightness reports back what it set', () {
      final h = _harness();
      final light = h.server.compound.devices.whereType<LightDevice>().first;
      final result = _say(h, 'setBrightness', phrase: light.name, value: 30);
      expect(light.brightness, 30);
      expect(result.spoken, contains('30'));
    });

    test('a gate opens and closes; a door locks and unlocks', () {
      final h = _harness();
      final locks = h.server.compound.devices.whereType<LockDevice>();
      final gate = locks.where((l) => l.isGate).firstOrNull;
      final door = locks.where((l) => !l.isGate).firstOrNull;

      if (gate != null) {
        final result = _say(h, 'unlock', phrase: gate.name);
        expect(gate.locked, isFalse);
        // Saying "unlocked" about a gate is how an assistant sounds like a
        // machine.
        expect(result.spoken, contains('open'));
      }
      if (door != null) {
        final result = _say(h, 'lock', phrase: door.name);
        expect(door.locked, isTrue);
        expect(result.spoken, contains('locked'));
      }
    });

    test('all lights off needs no target', () {
      final h = _harness();
      for (final light in h.server.compound.devices.whereType<LightDevice>()) {
        light.on = true;
      }
      final result = _say(h, 'allLightsOff');
      expect(result.ok, isTrue);
      expect(h.server.compound.devices.whereType<LightDevice>().every((l) => !l.on), isTrue);
    });

    test('something that does not switch says so instead of failing silently', () {
      final h = _harness();
      final climate = h.server.compound.devices.whereType<ClimateDevice>().firstOrNull;
      if (climate == null) return;
      // Climate is excluded from the on/off kinds, so this finds nothing at
      // all rather than doing something surprising to a thermostat.
      final result = _say(h, 'turnOff', phrase: climate.name);
      expect(result.ok, isFalse);
    });
  });

  group('answering', () {
    test('status reads a light without changing it', () {
      final h = _harness();
      final light = h.server.compound.devices.whereType<LightDevice>().first
        ..on = true
        ..brightness = 55;
      final result = _say(h, 'status', phrase: light.name);
      expect(result.ok, isTrue);
      expect(result.spoken, contains('55'));
      expect(light.on, isTrue);
      expect(light.brightness, 55);
    });

    test('the compound summary is one sentence', () {
      final h = _harness();
      final result = _say(h, 'compoundStatus');
      expect(result.ok, isTrue);
      expect(result.spoken.endsWith('.'), isTrue);
      expect(result.spoken.split('.').where((s) => s.trim().isNotEmpty).length, 1);
    });

    test('a phrase that matches nothing says so by name', () {
      final h = _harness();
      final result = _say(h, 'turnOff', phrase: 'the submarine');
      expect(result.ok, isFalse);
      expect(result.spoken, contains('submarine'));
    });

    test('an ambiguous phrase asks rather than guessing', () {
      final h = _harness();
      // "light" matches every light on the compound; picking one would be a
      // coin flip the user cannot see.
      final result = _say(h, 'turnOff', phrase: 'light');
      if (h.server.compound.devices.whereType<LightDevice>().length > 1) {
        expect(result.ok, isFalse);
        expect(result.needsChoice.length, greaterThan(1));
        expect(result.spoken, startsWith('Which one'));
      }
    });
  });
}
