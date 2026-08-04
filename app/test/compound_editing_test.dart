import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/state/compound_store.dart';
import 'package:nexus_shared/nexus_shared.dart';

void main() {
  CompoundStore emptyStore({void Function(Compound)? onPersist}) =>
      CompoundStore(seed: buildEmptyCompound(), simulate: false, onPersist: onPersist);

  test('an empty compound really is empty', () {
    final compound = buildEmptyCompound();
    expect(compound.buildings, isEmpty);
    expect(compound.rooms, isEmpty);
    expect(compound.devices, isEmpty);
    expect(compound.zones, isEmpty);
  });

  test('adding a building also puts it on the map', () {
    final store = emptyStore();
    final building = store.addBuilding('Main House', mapX: 0.4, mapY: 0.6);

    expect(building.id, 'main_house');
    expect(store.compound.buildings.single.name, 'Main House');
    // Without a zone the building would exist but never render on Home.
    final zone = store.compound.zones.single;
    expect(zone.buildingIds, ['main_house']);
    expect(zone.mapX, 0.4);
    expect(zone.mapY, 0.6);
    store.dispose();
  });

  test('ids stay unique when names collide', () {
    final store = emptyStore();
    expect(store.addBuilding('Barn').id, 'barn');
    expect(store.addBuilding('Barn').id, 'barn_2');
    expect(store.addBuilding('Barn').id, 'barn_3');
    store.dispose();
  });

  test('map positions are clamped inside the canvas', () {
    final store = emptyStore();
    store.addBuilding('Far', mapX: 5, mapY: -3);
    final zone = store.compound.zones.single;
    expect(zone.mapX, 0.95);
    expect(zone.mapY, 0.05);
    store.dispose();
  });

  test('locks attach to the building, everything else to the room', () {
    final store = emptyStore();
    store.addBuilding('Shop');
    final room = store.addRoom('shop', 'Bay');

    final light = store.addDeviceOfType(
      type: DeviceType.light,
      name: 'Bay Light',
      buildingId: 'shop',
      roomId: room.id,
    );
    final lock = store.addDeviceOfType(
      type: DeviceType.lock,
      name: 'Shop Door',
      buildingId: 'shop',
      roomId: room.id, // deliberately passed; the model must ignore it
    );

    expect(light, isA<LightDevice>());
    expect(light.roomId, room.id);
    expect(lock, isA<LockDevice>());
    expect(lock.roomId, isNull);
    store.dispose();
  });

  test('removing a building takes its rooms and devices with it', () {
    final store = emptyStore();
    store.addBuilding('Cabin');
    store.addBuilding('Barn');
    final room = store.addRoom('cabin', 'Loft');
    store.addDeviceOfType(
      type: DeviceType.light,
      name: 'Loft Light',
      buildingId: 'cabin',
      roomId: room.id,
    );
    store.addDeviceOfType(type: DeviceType.lock, name: 'Barn Gate', buildingId: 'barn');

    store.removeBuilding('cabin');

    // Orphans would show up as ghost entries across the UI.
    expect(store.compound.buildings.single.id, 'barn');
    expect(store.compound.rooms, isEmpty);
    expect(store.compound.devices.single.id, 'barn_gate');
    expect(store.compound.zones.single.buildingIds, ['barn']);
    store.dispose();
  });

  test('removing a room takes only that room\'s devices', () {
    final store = emptyStore();
    store.addBuilding('Main');
    final kitchen = store.addRoom('main', 'Kitchen');
    final office = store.addRoom('main', 'Office');
    store.addDeviceOfType(
        type: DeviceType.light, name: 'Kitchen Light', buildingId: 'main', roomId: kitchen.id);
    store.addDeviceOfType(
        type: DeviceType.light, name: 'Office Light', buildingId: 'main', roomId: office.id);

    store.removeRoom(kitchen.id);

    expect(store.compound.rooms.single.id, office.id);
    expect(store.compound.devices.single.name, 'Office Light');
    store.dispose();
  });

  test('renaming a building renames its single-building zone', () {
    final store = emptyStore();
    store.addBuilding('Shed');
    store.renameBuilding('shed', 'Workshop');
    expect(store.compound.buildings.single.name, 'Workshop');
    expect(store.compound.zones.single.name, 'Workshop');
    store.dispose();
  });

  test('edits are persisted, simulation ticks are not', () async {
    var saves = 0;
    final store = emptyStore(onPersist: (_) => saves++);
    store.addBuilding('Barn');
    store.addRoom('barn', 'Stalls');
    expect(saves, 2);

    // No ticker when simulate: false, so nothing should write on its own.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(saves, 2);
    store.dispose();
  });

  test('vehicles are compound-level, not filed under a building', () {
    final store = emptyStore();
    final truck = store.addVehicle('Ranch Truck', mapX: 0.3, mapY: 0.8);

    expect(truck.id, 'ranch_truck');
    expect(store.compound.vehicles.single.name, 'Ranch Truck');
    expect(truck.mapX, 0.3);
    // Removing a building must not take vehicles with it.
    store.addBuilding('Barn');
    store.removeBuilding('barn');
    expect(store.compound.vehicles, hasLength(1));
    store.dispose();
  });

  test('a gate is a lock with gate wording', () {
    final store = emptyStore();
    store.addBuilding('Main');
    final gate = store.addGate('North Gate', 'main');

    expect(gate.isGate, isTrue, reason: 'the UI reads Open/Closed off this');
    expect(gate.roomId, isNull, reason: 'gates attach to the building');
    // Same device list as everything else, so control and polling just work.
    expect(store.compound.devices.single.id, 'north_gate');
    store.dispose();
  });

  test('a gate can be wired to hardware like any other device', () {
    final store = emptyStore();
    store.addBuilding('Main');
    final gate = store.addGate(
      'Driveway',
      'main',
      endpoint: const DeviceEndpoint(protocol: DeviceProtocol.shellyGen1, host: '10.0.0.9'),
    );
    expect(gate.endpoint!.host, '10.0.0.9');
    // And survives a save/load, which locks previously did not.
    final restored = Compound.fromJson(store.compound.toJson());
    expect((restored.devices.single as LockDevice).isGate, isTrue);
    expect(restored.devices.single.endpoint!.host, '10.0.0.9');
    store.dispose();
  });

  test('vehicle map positions are clamped like buildings', () {
    final store = emptyStore();
    final v = store.addVehicle('Stray', mapX: -2, mapY: 9);
    expect(v.mapX, 0.05);
    expect(v.mapY, 0.95);
    store.dispose();
  });

  group('moving things on the map', () {
    test('dragging a building moves its zone and persists', () {
      var saves = 0;
      final store = emptyStore(onPersist: (_) => saves++);
      store.addBuilding('Barn', mapX: 0.5, mapY: 0.5);
      final before = saves;

      store.moveBuilding('barn', 0.2, 0.8);

      expect(store.compound.zones.single.mapX, 0.2);
      expect(store.compound.zones.single.mapY, 0.8);
      // Getting the layout right is worth nothing if it's gone next launch.
      expect(saves, before + 1);
      store.dispose();
    });

    test('a drag past the edge lands at the edge rather than being ignored', () {
      final store = emptyStore();
      store.addBuilding('Shed');
      store.moveBuilding('shed', 3, -2);
      // Clamped, not rejected: overshooting means "as far as it goes".
      expect(store.compound.zones.single.mapX, 0.95);
      expect(store.compound.zones.single.mapY, 0.05);
      store.dispose();
    });

    test('moving one building does not drag the others with it', () {
      final store = emptyStore();
      store.addBuilding('A', mapX: 0.3, mapY: 0.3);
      store.addBuilding('B', mapX: 0.7, mapY: 0.7);

      store.moveBuilding('a', 0.1, 0.1);

      final b = store.compound.zones.firstWhere((z) => z.buildingIds.contains('b'));
      expect(b.mapX, 0.7);
      expect(b.mapY, 0.7);
      store.dispose();
    });

    test('an unknown id is a no-op, not a crash', () {
      final store = emptyStore();
      store.addBuilding('Barn', mapX: 0.4, mapY: 0.4);
      store.moveBuilding('does_not_exist', 0.9, 0.9);
      expect(store.compound.zones.single.mapX, 0.4);
      store.dispose();
    });

    test('vehicles move the same way', () {
      final store = emptyStore();
      store.addVehicle('Truck', mapX: 0.5, mapY: 0.5);
      store.moveVehicle('truck', 0.25, 0.75);
      expect(store.compound.vehicles.single.mapX, 0.25);
      expect(store.compound.vehicles.single.mapY, 0.75);
      store.dispose();
    });

    test('a moved position survives a save and reload', () {
      final store = emptyStore();
      store.addBuilding('Cabin');
      store.moveBuilding('cabin', 0.42, 0.61);

      final restored = Compound.fromJson(store.compound.toJson());
      expect(restored.zones.single.mapX, closeTo(0.42, 1e-9));
      expect(restored.zones.single.mapY, closeTo(0.61, 1e-9));
      store.dispose();
    });
  });

  test('a compound survives a JSON round trip', () {
    final store = emptyStore();
    store.addBuilding('Barn', mapX: 0.3, mapY: 0.7);
    final room = store.addRoom('barn', 'Tack Room');
    store.addDeviceOfType(
        type: DeviceType.light, name: 'Tack Light', buildingId: 'barn', roomId: room.id);
    store.addDeviceOfType(type: DeviceType.lock, name: 'Barn Gate', buildingId: 'barn');

    final restored = Compound.fromJson(store.compound.toJson());

    expect(restored.buildings.single.name, 'Barn');
    expect(restored.rooms.single.name, 'Tack Room');
    expect(restored.devices.map((d) => d.name), containsAll(['Tack Light', 'Barn Gate']));
    expect(restored.zones.single.mapX, 0.3);
    store.dispose();
  });
}
