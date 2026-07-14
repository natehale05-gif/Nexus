import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:nexus_shared/nexus_shared.dart';

/// Owns the live [Compound] tree for local-demo-mode and exposes every
/// mutation the UI needs. Also runs the simulation ticker described in
/// Section 4 (grill preheat/probe behavior) and re-runs `computeInsights`
/// on every tick (Section 6) - in the fuller build this whole class is
/// replaced by a thin WebSocket client, see [ServerClient].
class CompoundStore extends ChangeNotifier {
  CompoundStore({Compound? seed}) : compound = seed ?? buildDemoCompound() {
    _recomputeInsights();
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  final Compound compound;
  Timer? _ticker;
  final _random = Random();

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
  }

  // ---- Light -------------------------------------------------------------

  void toggleLight(String id) => _mutate(() {
        final light = _device<LightDevice>(id);
        light.on = !light.on;
      });

  void setBrightness(String id, double value) => _mutate(() {
        final light = _device<LightDevice>(id);
        light.brightness = value.round().clamp(0, 100);
        if (light.brightness > 0) light.on = true;
      });

  // ---- Climate -------------------------------------------------------------

  void setClimateMode(String id, ClimateMode mode) => _mutate(() {
        _device<ClimateDevice>(id).mode = mode;
      });

  void setClimateTarget(String id, double value) => _mutate(() {
        final climate = _device<ClimateDevice>(id);
        climate.set = value.clamp(55, 85);
      });

  void nudgeClimateTarget(String id, double delta) => _mutate(() {
        final climate = _device<ClimateDevice>(id);
        climate.set = (climate.set + delta).clamp(55, 85);
      });

  void setFanMode(String id, FanMode fan) => _mutate(() {
        _device<ClimateDevice>(id).fan = fan;
      });

  void setHold(String id, String? hold) => _mutate(() {
        _device<ClimateDevice>(id).hold = hold;
      });

  // ---- Grill -------------------------------------------------------------

  void setGrillOn(String id, bool on) => _mutate(() {
        final grill = _device<GrillDevice>(id);
        grill.on = on;
        if (!on) {
          grill.probe = null;
        }
      });

  void setGrillTarget(String id, double value) => _mutate(() {
        final grill = _device<GrillDevice>(id);
        grill.set = value.clamp(165, 500);
      });

  void setProbeTarget(String id, double? value) => _mutate(() {
        _device<GrillDevice>(id).probeTarget = value;
      });

  // ---- Lock/Gate -------------------------------------------------------------

  void setLocked(String id, bool locked) => _mutate(() {
        final lock = _device<LockDevice>(id);
        lock.locked = locked;
        lock.openSince = locked ? null : DateTime.now();
      });

  // ---- Media -------------------------------------------------------------

  void setMediaOn(String id, bool on) => _mutate(() {
        _device<MediaDevice>(id).on = on;
      });

  void setNowPlayingState(bool playing) => _mutate(() {
        compound.nowPlaying?.isPlaying = playing;
      });

  // ---- Scenes / bulk actions (used by NEXUS AI + insights CTA) ----------

  void turnOffAllLights() => _mutate(() {
        for (final device in compound.devices.whereType<LightDevice>()) {
          device.on = false;
        }
      });

  List<Device> devicesMatchingName(String query) {
    final q = query.toLowerCase();
    return compound.devices.where((d) => d.name.toLowerCase().contains(q)).toList();
  }

  Building? buildingMatchingName(String query) {
    final q = query.toLowerCase();
    for (final b in compound.buildings) {
      if (b.name.toLowerCase().contains(q) || b.id.toLowerCase() == q) return b;
    }
    return null;
  }

  // ---- Add accessory -------------------------------------------------------------

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
