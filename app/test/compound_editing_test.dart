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
