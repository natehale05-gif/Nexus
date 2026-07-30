import 'dart:async';

import 'package:nexus_shared/nexus_shared.dart';

import '../state/server_compound.dart';
import 'device_driver.dart';

/// Keeps NEXUS honest about hardware it doesn't control exclusively.
///
/// Without this, control is one-way: flip a Shelly at the wall switch, from
/// its own app, or on a schedule, and NEXUS keeps showing whatever it last
/// commanded - forever. A UI that confidently reports the opposite of reality
/// is worse than one that admits it doesn't know, so every wired device gets
/// re-read on an interval and the model reconciled.
class DevicePoller {
  DevicePoller(
    this.server, {
    DeviceDriver? driver,
    this.interval = const Duration(seconds: 15),
  }) : _driver = driver ?? DeviceDriver();

  final ServerCompound server;
  final DeviceDriver _driver;
  final Duration interval;
  Timer? _timer;
  bool _polling = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => poll());
    // Don't make the first reading wait a full interval.
    poll();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _driver.close();
  }

  /// Reads every wired device and applies whatever changed.
  ///
  /// Guarded against overlap: on a compound with slow or unreachable devices a
  /// round can outlast the interval, and stacking rounds would multiply the
  /// traffic against exactly the devices already struggling to answer.
  Future<void> poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final wired = server.compound.devices.where((d) => d.endpoint != null).toList();
      // Concurrently - a dozen devices each taking a second would otherwise
      // make a round longer than the interval.
      await Future.wait(wired.map(_readOne));
    } finally {
      _polling = false;
    }
  }

  Future<void> _readOne(Device device) async {
    final endpoint = device.endpoint!;
    final body = await _driver.fetch(buildStatusRequest(endpoint));
    if (body == null) return; // Unreachable: keep the last known state.
    final state = parseStatusResponse(endpoint, body);
    if (state == null) return;

    // Only notify when something actually differs, so a compound sitting idle
    // doesn't broadcast the full tree to every client every 15 seconds.
    var changed = false;
    if (device is LightDevice) {
      if (state.on != null && state.on != device.on) changed = true;
      if (state.brightness != null && state.brightness != device.brightness) changed = true;
      if (changed) {
        server.mutate(() {
          if (state.on != null) device.on = state.on!;
          if (state.brightness != null) {
            device.brightness = state.brightness!.clamp(0, 100);
          }
        });
      }
    } else if (device is MediaDevice) {
      if (state.on != null && state.on != device.on) {
        server.mutate(() => device.on = state.on!);
      }
    } else if (device is LockDevice) {
      // A relay driving a gate reads as on = open, so locked is its inverse.
      final locked = state.on == null ? null : !state.on!;
      if (locked != null && locked != device.locked) {
        server.mutate(() => device.locked = locked);
      }
    }
  }
}
