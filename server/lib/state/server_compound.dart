import 'dart:async';

import 'package:nexus_shared/nexus_shared.dart';

import '../devices/device_driver.dart';

/// Server-side owner of the live [Compound] tree.
///
/// This is the single source of truth the WebSocket hub broadcasts from
/// and the REST API mutates - every protocol bridge in `integrations/`
/// funnels its updates through here rather than touching the app
/// directly, and every command from the app (light toggle, climate set,
/// grill ignite, etc.) arrives here before being (in a real deployment)
/// forwarded out to the relevant bridge.
class ServerCompound {
  ServerCompound({Compound? seed, DeviceDriver? driver})
      : compound = seed ?? buildDemoCompound(),
        _driver = driver ?? DeviceDriver() {
    _recomputeInsights();
  }

  final Compound compound;

  /// Sends the actual HTTP commands to devices that have an endpoint.
  final DeviceDriver _driver;
  final _changes = StreamController<Compound>.broadcast();

  /// Emits the full compound every time something changes. The WebSocket
  /// hub subscribes to this and pushes `compound.toJson()` to every
  /// connected client (Section 8/9 - "WebSocket state sync first").
  Stream<Compound> get onChange => _changes.stream;

  void dispose() {
    _driver.close();
    _changes.close();
  }

  /// Pushes a command out to the physical device, if this one is wired to any.
  ///
  /// Fire-and-forget on purpose: NEXUS's own state has already been updated
  /// and broadcast, so the UI stays responsive whether or not the device is
  /// plugged in. A device that's unreachable is an ordinary condition on a
  /// compound, not an error to fail the command over.
  void _push(Device device, DeviceRequest? Function(DeviceEndpoint) build) {
    final endpoint = device.endpoint;
    if (endpoint == null) return;
    final request = build(endpoint);
    if (request != null) unawaited(_driver.send(request));
  }

  T _device<T extends Device>(String id) => compound.devices.firstWhere((d) => d.id == id) as T;

  void _recomputeInsights() {
    compound.insights = computeInsights(compound);
  }

  /// Every mutation funnels through here so insights stay fresh and every
  /// connected client gets notified in one place.
  void mutate(void Function() body) {
    body();
    _recomputeInsights();
    _changes.add(compound);
  }

  void toggleLight(String id) => mutate(() {
        final light = _device<LightDevice>(id);
        light.on = !light.on;
        _push(light, (e) => buildPowerRequest(e, light.on));
      });

  void setBrightness(String id, num value) => mutate(() {
        final light = _device<LightDevice>(id);
        light.brightness = value.round().clamp(0, 100);
        if (light.brightness > 0) light.on = true;
        _push(light, (e) => buildBrightnessRequest(e, light.brightness));
      });

  void setClimateMode(String id, ClimateMode mode) => mutate(() {
        _device<ClimateDevice>(id).mode = mode;
      });

  void setClimateTarget(String id, num value) => mutate(() {
        _device<ClimateDevice>(id).set = value.toDouble().clamp(55, 85);
      });

  void nudgeClimateTarget(String id, num delta) => mutate(() {
        final climate = _device<ClimateDevice>(id);
        climate.set = (climate.set + delta).clamp(55, 85);
      });

  void setFanMode(String id, FanMode fan) => mutate(() {
        _device<ClimateDevice>(id).fan = fan;
      });

  void setHold(String id, String? hold) => mutate(() {
        _device<ClimateDevice>(id).hold = hold;
      });

  void setGrillOn(String id, bool on) => mutate(() {
        final grill = _device<GrillDevice>(id);
        grill.on = on;
        if (!on) grill.probe = null;
      });

  void setGrillTarget(String id, num value) => mutate(() {
        _device<GrillDevice>(id).set = value.toDouble().clamp(165, 500);
      });

  void setProbeTarget(String id, num? value) => mutate(() {
        _device<GrillDevice>(id).probeTarget = value?.toDouble();
      });

  void setLocked(String id, bool locked) => mutate(() {
        final lock = _device<LockDevice>(id);
        lock.locked = locked;
        lock.openSince = locked ? null : DateTime.now();
      });

  void setMediaOn(String id, bool on) => mutate(() {
        _push(_device<MediaDevice>(id), (e) => buildPowerRequest(e, on));
        _device<MediaDevice>(id).on = on;
      });

  void setMeshNodeStatus(String id, {bool? online, int? batteryPercent}) => mutate(() {
        final node = compound.meshNodes.firstWhere((n) => n.id == id);
        if (online != null) node.online = online;
        if (batteryPercent != null) node.batteryPercent = batteryPercent;
      });

  void turnOffAllLights() => mutate(() {
        for (final light in compound.devices.whereType<LightDevice>()) {
          if (light.on) _push(light, (e) => buildPowerRequest(e, false));
        }
        for (final device in compound.devices.whereType<LightDevice>()) {
          device.on = false;
        }
      });

  void addDevice(Device device) => mutate(() {
        compound.devices.add(device);
      });

  /// Moves the zone a building belongs to. A zone with several buildings
  /// moves as one - grouping them is what said they're in the same place.
  void moveBuilding(String buildingId, double mapX, double mapY) => mutate(() {
        for (final zone in compound.zones) {
          if (zone.buildingIds.contains(buildingId)) zone.moveTo(mapX, mapY);
        }
      });

  void moveVehicle(String vehicleId, double mapX, double mapY) => mutate(() {
        for (final vehicle in compound.vehicles) {
          if (vehicle.id == vehicleId) vehicle.moveTo(mapX, mapY);
        }
      });

  void removeDevice(String id) => mutate(() {
        compound.devices.removeWhere((d) => d.id == id);
      });
}
