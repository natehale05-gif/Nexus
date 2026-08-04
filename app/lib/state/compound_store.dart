import 'dart:async';
import 'dart:math';
import 'package:nexus_shared/nexus_shared.dart';
import 'nexus_data_source.dart';

/// Owns the live [Compound] tree for local-demo-mode and exposes every
/// mutation the UI needs. Also runs the simulation ticker described in
/// Section 4 (grill preheat/probe behavior) and re-runs `computeInsights`
/// on every tick (Section 6). For live mode against the Dart server, see
/// [ServerClient] - both implement [NexusDataSource] so the UI doesn't
/// care which one is active.
class CompoundStore extends NexusDataSource {
  CompoundStore({Compound? seed, this.onPersist, bool simulate = true})
      : compound = seed ?? buildDemoCompound() {
    _recomputeInsights();
    // A compound you built yourself shouldn't have its devices drifting on
    // their own - the ticker is demo behavior, so it's opt-out.
    if (simulate) {
      _ticker = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    }
  }

  @override
  final Compound compound;

  /// Called after every user-driven change so the caller can persist. Not
  /// called from the simulation ticker: that fires every 2s and would write
  /// constantly for state nobody asked to keep.
  final void Function(Compound compound)? onPersist;

  Timer? _ticker;
  final _random = Random();

  @override
  ConnectionStatus get connectionStatus => ConnectionStatus.demo;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  T _device<T extends Device>(String id) => compound.devices.firstWhere((d) => d.id == id) as T;

  void _recomputeInsights() {
    compound.insights = computeInsights(compound);
  }

  void _mutate(void Function() body) {
    body();
    _recomputeInsights();
    notifyListeners();
    onPersist?.call(compound);
  }

  /// Ids are derived from the name so they read sensibly in logs and in the
  /// AI assistant's `<action>` tags, with a numeric suffix only when needed
  /// to stay unique.
  static String _slug(String name, Iterable<String> taken) {
    var base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty) base = 'item';
    if (!taken.contains(base)) return base;
    for (var i = 2;; i++) {
      final candidate = '${base}_$i';
      if (!taken.contains(candidate)) return candidate;
    }
  }

  // ---- Compound structure -------------------------------------------------
  // Adding and removing buildings/rooms is what turns the app from a fixed
  // demo into something that can model an actual property.

  /// Adds a building (and the map zone that puts it on the Home map).
  /// [mapX]/[mapY] are normalized 0..1 positions on the map canvas.
  Building addBuilding(String name, {double mapX = 0.5, double mapY = 0.5}) {
    final id = _slug(name, compound.buildings.map((b) => b.id));
    final building = Building(id: id, name: name, zoneId: id);
    _mutate(() {
      compound.buildings.add(building);
      compound.zones.add(Zone(
        id: id,
        name: name,
        buildingIds: [id],
        mapX: clampMapPosition(mapX),
        mapY: clampMapPosition(mapY),
        primaryBuildingId: id,
      ));
    });
    return building;
  }

  /// Drags a building to where it actually stands on the property.
  ///
  /// The zone is what carries the position, so this moves the zone the
  /// building belongs to. A zone holding several buildings moves as one -
  /// that's what grouping them meant.
  @override
  void moveBuilding(String buildingId, double mapX, double mapY) => _mutate(() {
        for (final zone in compound.zones) {
          if (zone.buildingIds.contains(buildingId)) zone.moveTo(mapX, mapY);
        }
      });

  @override
  void moveVehicle(String vehicleId, double mapX, double mapY) => _mutate(() {
        for (final vehicle in compound.vehicles) {
          if (vehicle.id == vehicleId) vehicle.moveTo(mapX, mapY);
        }
      });

  void renameBuilding(String id, String name) => _mutate(() {
        compound.buildings.firstWhere((b) => b.id == id).name = name;
        for (final zone in compound.zones.where((z) => z.buildingIds.contains(id))) {
          if (zone.buildingIds.length == 1) zone.name = name;
        }
      });

  /// Removes a building along with everything anchored to it - leaving
  /// orphaned rooms or devices behind would surface as ghost entries all over
  /// the UI, since devices reference buildings by id.
  void removeBuilding(String id) => _mutate(() {
        compound.buildings.removeWhere((b) => b.id == id);
        compound.rooms.removeWhere((r) => r.buildingId == id);
        compound.devices.removeWhere((d) => d.buildingId == id);
        for (final zone in compound.zones) {
          zone.buildingIds.remove(id);
        }
        compound.zones.removeWhere((z) => z.buildingIds.isEmpty);
      });

  Room addRoom(String buildingId, String name) {
    final room = Room(
      id: _slug('${buildingId}_$name', compound.rooms.map((r) => r.id)),
      buildingId: buildingId,
      name: name,
    );
    _mutate(() => compound.rooms.add(room));
    return room;
  }

  void renameRoom(String id, String name) =>
      _mutate(() => compound.rooms.firstWhere((r) => r.id == id).name = name);

  void removeRoom(String id) => _mutate(() {
        compound.rooms.removeWhere((r) => r.id == id);
        compound.devices.removeWhere((d) => d.roomId == id);
      });

  /// Builds a device of [type] with sensible defaults and a unique id.
  /// Locks always attach to the building rather than a room, matching the
  /// model's own rule.
  Device addDeviceOfType({
    required DeviceType type,
    required String name,
    required String buildingId,
    String? roomId,
    DeviceEndpoint? endpoint,
  }) {
    final id = _slug(name, compound.devices.map((d) => d.id));
    final device = switch (type) {
      DeviceType.light =>
        LightDevice(id: id, name: name, buildingId: buildingId, roomId: roomId, endpoint: endpoint),
      DeviceType.climate =>
        ClimateDevice(id: id, name: name, buildingId: buildingId, roomId: roomId, endpoint: endpoint),
      DeviceType.grill =>
        GrillDevice(id: id, name: name, buildingId: buildingId, roomId: roomId, endpoint: endpoint),
      DeviceType.media =>
        MediaDevice(id: id, name: name, buildingId: buildingId, roomId: roomId, endpoint: endpoint),
      DeviceType.lock => LockDevice(id: id, name: name, buildingId: buildingId, endpoint: endpoint),
    };
    addDevice(device);
    return device;
  }

  void renameDevice(String id, String name) =>
      _mutate(() => compound.devices.firstWhere((d) => d.id == id).name = name);

  /// Re-points a device at different hardware, or unwires it entirely.
  /// Without this, a typo'd IP meant deleting the device and starting over.
  void setDeviceEndpoint(String id, DeviceEndpoint? endpoint) => _mutate(() {
        compound.devices.firstWhere((d) => d.id == id).endpoint = endpoint;
      });

  /// Vehicles are compound-level, not building-level - a truck isn't in a
  /// room. They get their own map position so they show up on Home.
  Vehicle addVehicle(String name, {double mapX = 0.5, double mapY = 0.5}) {
    final vehicle = Vehicle(
      id: _slug(name, compound.vehicles.map((v) => v.id)),
      name: name,
      status: VehicleStatus.parked,
      locationDescription: 'On the compound',
      batteryPercent: 100,
      mapX: mapX.clamp(0.05, 0.95),
      mapY: mapY.clamp(0.05, 0.95),
    );
    _mutate(() => compound.vehicles.add(vehicle));
    return vehicle;
  }

  void renameVehicle(String id, String name) =>
      _mutate(() => compound.vehicles.firstWhere((v) => v.id == id).name = name);

  void removeVehicle(String id) =>
      _mutate(() => compound.vehicles.removeWhere((v) => v.id == id));

  /// A gate is a [LockDevice] with gate wording - same hardware path, but the
  /// UI says Open/Closed rather than Locked/Unlocked.
  LockDevice addGate(String name, String buildingId, {DeviceEndpoint? endpoint}) {
    final gate = LockDevice(
      id: _slug(name, compound.devices.map((d) => d.id)),
      name: name,
      buildingId: buildingId,
      isGate: true,
      endpoint: endpoint,
    );
    addDevice(gate);
    return gate;
  }

  void removeDevice(String id) =>
      _mutate(() => compound.devices.removeWhere((d) => d.id == id));

  // ---- Light -------------------------------------------------------------

  @override
  void toggleLight(String id) => _mutate(() {
        final light = _device<LightDevice>(id);
        light.on = !light.on;
      });

  @override
  void setBrightness(String id, double value) => _mutate(() {
        final light = _device<LightDevice>(id);
        light.brightness = value.round().clamp(0, 100);
        if (light.brightness > 0) light.on = true;
      });

  // ---- Climate -------------------------------------------------------------

  @override
  void setClimateMode(String id, ClimateMode mode) => _mutate(() {
        _device<ClimateDevice>(id).mode = mode;
      });

  @override
  void setClimateTarget(String id, double value) => _mutate(() {
        final climate = _device<ClimateDevice>(id);
        climate.set = value.clamp(55, 85);
      });

  @override
  void nudgeClimateTarget(String id, double delta) => _mutate(() {
        final climate = _device<ClimateDevice>(id);
        climate.set = (climate.set + delta).clamp(55, 85);
      });

  @override
  void setFanMode(String id, FanMode fan) => _mutate(() {
        _device<ClimateDevice>(id).fan = fan;
      });

  @override
  void setHold(String id, String? hold) => _mutate(() {
        _device<ClimateDevice>(id).hold = hold;
      });

  // ---- Grill -------------------------------------------------------------

  @override
  void setGrillOn(String id, bool on) => _mutate(() {
        final grill = _device<GrillDevice>(id);
        grill.on = on;
        if (!on) {
          grill.probe = null;
        }
      });

  @override
  void setGrillTarget(String id, double value) => _mutate(() {
        final grill = _device<GrillDevice>(id);
        grill.set = value.clamp(165, 500);
      });

  @override
  void setProbeTarget(String id, double? value) => _mutate(() {
        _device<GrillDevice>(id).probeTarget = value;
      });

  // ---- Lock/Gate -------------------------------------------------------------

  @override
  void setLocked(String id, bool locked) => _mutate(() {
        final lock = _device<LockDevice>(id);
        lock.locked = locked;
        lock.openSince = locked ? null : DateTime.now();
      });

  // ---- Media -------------------------------------------------------------

  @override
  void setMediaOn(String id, bool on) => _mutate(() {
        _device<MediaDevice>(id).on = on;
      });

  @override
  void setNowPlayingState(bool playing) => _mutate(() {
        compound.nowPlaying?.isPlaying = playing;
      });

  @override
  void playLibraryItem(String itemId) => _mutate(() {
        final item = compound.continueWatching.where((c) => c.id == itemId).firstOrNull;
        if (item == null) return;
        compound.nowPlaying = NowPlaying(
          itemId: item.id,
          title: item.title,
          durationSeconds: item.durationSeconds,
          positionSeconds: item.positionSeconds,
          isPlaying: true,
        );
      });

  @override
  void reportPlaybackPosition(String itemId, double positionSeconds) => _mutate(() {
        if (compound.nowPlaying?.itemId == itemId) {
          compound.nowPlaying!.positionSeconds = positionSeconds;
        }
      });

  @override
  void rescanLibrary() {
    // No real filesystem to scan in local-demo-mode.
  }

  @override
  Uri? mediaStreamUri(String itemId) => null;

  // ---- Scenes / bulk actions (used by NEXUS AI + insights CTA) ----------

  @override
  void turnOffAllLights() => _mutate(() {
        for (final device in compound.devices.whereType<LightDevice>()) {
          device.on = false;
        }
      });

  @override
  List<Device> devicesMatchingName(String query) {
    final q = query.toLowerCase();
    return compound.devices.where((d) => d.name.toLowerCase().contains(q)).toList();
  }

  @override
  Building? buildingMatchingName(String query) {
    final q = query.toLowerCase();
    for (final b in compound.buildings) {
      if (b.name.toLowerCase().contains(q) || b.id.toLowerCase() == q) return b;
    }
    return null;
  }

  // ---- Add accessory -------------------------------------------------------------

  @override
  void addDevice(Device device) => _mutate(() {
        compound.devices.add(device);
      });

  // ---- Simulation ticker -------------------------------------------------------------

  void _tick() {
    final changed = tickCompoundSimulation(compound, random: _random);
    if (changed) {
      _recomputeInsights();
      notifyListeners();
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
