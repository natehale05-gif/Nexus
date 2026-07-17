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
  CompoundStore({Compound? seed}) : compound = seed ?? buildDemoCompound() {
    _recomputeInsights();
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  @override
  final Compound compound;
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
  }

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
