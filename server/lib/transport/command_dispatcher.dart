import 'package:nexus_shared/nexus_shared.dart';

import '../integrations/integrations_manager.dart';
import '../state/server_compound.dart';

/// Executes one named command with JSON args against [ServerCompound].
/// Shared by the WebSocket hub (Section 8: "WebSocket... for live state
/// push") and the REST API (Section 8: "REST... for one-off
/// commands/queries") so both transports expose the identical command
/// surface.
class CommandDispatcher {
  CommandDispatcher(this.server, this.integrations);

  final ServerCompound server;
  final IntegrationsManager integrations;

  /// Returns a JSON-able result map. Throws [ArgumentError] for unknown
  /// commands or missing/invalid args - callers should turn that into a
  /// 400 (REST) or an `error` message (WebSocket).
  Map<String, dynamic> dispatch(String command, Map<String, dynamic> args) {
    switch (command) {
      case 'toggleLight':
        server.toggleLight(_id(args));
      case 'setBrightness':
        server.setBrightness(_id(args), _num(args, 'value'));
      case 'setClimateMode':
        server.setClimateMode(_id(args), ClimateMode.values.byName(_str(args, 'mode')));
      case 'setClimateTarget':
        server.setClimateTarget(_id(args), _num(args, 'value'));
      case 'nudgeClimateTarget':
        server.nudgeClimateTarget(_id(args), _num(args, 'delta'));
      case 'setFanMode':
        server.setFanMode(_id(args), FanMode.values.byName(_str(args, 'fan')));
      case 'setHold':
        server.setHold(_id(args), args['hold'] as String?);
      case 'setGrillOn':
        server.setGrillOn(_id(args), _bool(args, 'value'));
      case 'setGrillTarget':
        server.setGrillTarget(_id(args), _num(args, 'value'));
      case 'setProbeTarget':
        server.setProbeTarget(_id(args), args['value'] == null ? null : _num(args, 'value'));
      case 'setLocked':
        server.setLocked(_id(args), _bool(args, 'value'));
      case 'setMediaOn':
        server.setMediaOn(_id(args), _bool(args, 'value'));
      case 'turnOffAllLights':
        server.turnOffAllLights();
      case 'setGrillCloudOnline':
        integrations.traeger.setCloudOnline(_id(args), _bool(args, 'value'));
      case 'addDevice':
        server.addDevice(Device.fromJson(args['device'] as Map<String, dynamic>));
      default:
        throw ArgumentError('Unknown command: $command');
    }
    return {'ok': true, 'compound': server.compound.toJson()};
  }

  String _id(Map<String, dynamic> args) => _str(args, 'id');

  String _str(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! String) throw ArgumentError('Expected string arg "$key"');
    return value;
  }

  num _num(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! num) throw ArgumentError('Expected numeric arg "$key"');
    return value;
  }

  bool _bool(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! bool) throw ArgumentError('Expected boolean arg "$key"');
    return value;
  }
}
