import 'package:nexus_shared/nexus_shared.dart';
import 'package:nexus_server/state/server_compound.dart';
import 'package:nexus_server/transport/command_dispatcher.dart';
import 'package:nexus_server/integrations/integrations_manager.dart';
import 'package:test/test.dart';

void main() {
  group('ServerCompound', () {
    test('toggling a light flips its state and notifies listeners', () async {
      final server = ServerCompound();
      final light = server.compound.devices.whereType<LightDevice>().first;
      final initial = light.on;

      final future = server.onChange.first;
      server.toggleLight(light.id);
      await future;

      expect(light.on, !initial);
    });

    test('opening a lock records openSince and surfaces a warn insight', () {
      final server = ServerCompound();
      final lock = server.compound.devices.whereType<LockDevice>().first;
      server.setLocked(lock.id, false);

      expect(lock.locked, false);
      expect(lock.openSince, isNotNull);
      expect(server.compound.insights.any((i) => i.relatedDeviceId == lock.id), isTrue);
    });

    test('an offline mesh node produces a crit insight', () {
      final server = ServerCompound();
      final node = server.compound.meshNodes.first;
      server.setMeshNodeStatus(node.id, online: false);

      expect(server.compound.insights.any((i) => i.level == Level.crit), isTrue);
    });
  });

  group('CommandDispatcher', () {
    test('dispatches setBrightness and turns the light on', () {
      final server = ServerCompound();
      final integrations = IntegrationsManager(server);
      final dispatcher = CommandDispatcher(server, integrations);
      final light = server.compound.devices.whereType<LightDevice>().first
        ..on = false
        ..brightness = 0;

      dispatcher.dispatch('setBrightness', {'id': light.id, 'value': 42});

      expect(light.brightness, 42);
      expect(light.on, isTrue);
    });

    test('throws for an unknown command', () {
      final server = ServerCompound();
      final integrations = IntegrationsManager(server);
      final dispatcher = CommandDispatcher(server, integrations);

      expect(() => dispatcher.dispatch('doesNotExist', const {}), throwsArgumentError);
    });
  });
}
