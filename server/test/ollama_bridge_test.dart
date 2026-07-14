import 'package:nexus_shared/nexus_shared.dart';
import 'package:nexus_server/integrations/ollama_bridge.dart';
import 'package:nexus_server/state/server_compound.dart';
import 'package:test/test.dart';

void main() {
  group('action tag execution', () {
    test('executes a turnOffAllLights action and strips the tag from output', () {
      final server = ServerCompound();
      for (final light in server.compound.devices.whereType<LightDevice>()) {
        light.on = true;
      }

      const modelOutput = 'Sure, turning them off now.<action name="turnOffAllLights"/>';
      final executed = executeActionTags(modelOutput, server);
      final visible = stripActionTags(modelOutput);

      expect(executed, isNotEmpty);
      expect(server.compound.devices.whereType<LightDevice>().every((l) => !l.on), isTrue);
      expect(visible, 'Sure, turning them off now.');
    });

    test('executes a setLocked action with attributes', () {
      final server = ServerCompound();
      final lock = server.compound.devices.whereType<LockDevice>().first..locked = true;

      executeActionTags('<action name="setLocked" id="${lock.id}" value="false"/>', server);

      expect(lock.locked, isFalse);
    });
  });

  group('buildSystemContext', () {
    test('includes grill probe/target data', () {
      final server = ServerCompound();
      final grill = server.compound.devices.whereType<GrillDevice>().first
        ..on = true
        ..probe = 150
        ..probeTarget = 203;

      final context = buildSystemContext(server.compound);

      expect(context, contains('150'));
      expect(context, contains('203'));
      expect(context, contains(grill.name));
    });
  });
}
