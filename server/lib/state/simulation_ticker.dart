import 'dart:async';
import 'dart:math';

import 'package:nexus_shared/nexus_shared.dart';

import 'server_compound.dart';

/// Drives [tickCompoundSimulation] on a timer server-side. In a full
/// deployment this becomes largely redundant once real bridges (Traeger
/// MQTT, Ecobee, etc. - Section 8) are pushing live readings in; it is
/// kept running underneath them here since none of those bridges have
/// real hardware/credentials to report from in this environment (see the
/// `integrations/` package docs).
class SimulationTicker {
  SimulationTicker(this._server, {Duration interval = const Duration(seconds: 2)}) : _interval = interval;

  final ServerCompound _server;
  final Duration _interval;
  final _random = Random();
  Timer? _timer;

  void start() {
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  void stop() => _timer?.cancel();

  void _tick() {
    _server.mutate(() {
      tickCompoundSimulation(_server.compound, random: _random);
    });
  }
}
