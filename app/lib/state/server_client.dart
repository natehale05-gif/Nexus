import 'dart:async';
import 'dart:convert';

import 'package:nexus_shared/nexus_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'nexus_data_source.dart';

/// Live-mode [NexusDataSource]: mirrors whatever the Dart server pushes
/// over its WebSocket state-sync channel (Section 8) and forwards every
/// mutation back as a `command` message instead of applying it locally -
/// the server is the source of truth, this is just a thin reflection of
/// it. See `server/lib/transport/websocket_hub.dart` for the wire
/// protocol this speaks.
///
/// Not wired in by default (the app defaults to [CompoundStore]'s
/// local-demo-mode per the spec's own build order), but fully functional:
/// pass `?server=<host:port>` in the URL on web, or construct one
/// directly with a `ws://host:port` URL, to point the app at a real
/// running `nexus_server` instance instead.
class ServerClient extends NexusDataSource {
  ServerClient({required String hostOrUrl}) : uri = _normalize(hostOrUrl) {
    _compound = buildDemoCompound();
    _connect();
  }

  final Uri uri;
  late Compound _compound;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  int _nextId = 0;
  bool _disposed = false;

  /// True once at least one real `state` push has arrived from the
  /// server (until then, [compound] is just the local demo seed so the
  /// UI has something sensible to render while connecting).
  bool isConnected = false;

  final _pendingChats = <String, Completer<String>>{};

  static Uri _normalize(String hostOrUrl) {
    var value = hostOrUrl.trim();
    if (!value.contains('://')) value = 'ws://$value';
    final uri = Uri.parse(value);
    return uri.hasPort ? uri : uri.replace(port: 8765);
  }

  @override
  Compound get compound => _compound;

  void _connect() {
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (!_disposed) _connect();
    });
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> message;
    try {
      message = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (message['type']) {
      case 'state':
        _compound = Compound.fromJson(message['compound'] as Map<String, dynamic>);
        isConnected = true;
        notifyListeners();
      case 'chatReply':
        final id = message['id'] as String?;
        _pendingChats.remove(id)?.complete(message['message'] as String? ?? '');
    }
  }

  void _send(String command, Map<String, dynamic> args) {
    _channel?.sink.add(jsonEncode({'type': 'command', 'id': '${_nextId++}', 'command': command, 'args': args}));
  }

  Future<String> sendChat(String message) {
    final id = '${_nextId++}';
    final completer = Completer<String>();
    _pendingChats[id] = completer;
    _channel?.sink.add(jsonEncode({'type': 'chat', 'id': id, 'message': message}));
    return completer.future.timeout(
      const Duration(seconds: 25),
      onTimeout: () => "The server didn't respond in time.",
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  void toggleLight(String id) => _send('toggleLight', {'id': id});

  @override
  void setBrightness(String id, double value) => _send('setBrightness', {'id': id, 'value': value});

  @override
  void setClimateMode(String id, ClimateMode mode) => _send('setClimateMode', {'id': id, 'mode': mode.name});

  @override
  void setClimateTarget(String id, double value) => _send('setClimateTarget', {'id': id, 'value': value});

  @override
  void nudgeClimateTarget(String id, double delta) => _send('nudgeClimateTarget', {'id': id, 'delta': delta});

  @override
  void setFanMode(String id, FanMode fan) => _send('setFanMode', {'id': id, 'fan': fan.name});

  @override
  void setHold(String id, String? hold) => _send('setHold', {'id': id, 'hold': hold});

  @override
  void setGrillOn(String id, bool on) => _send('setGrillOn', {'id': id, 'value': on});

  @override
  void setGrillTarget(String id, double value) => _send('setGrillTarget', {'id': id, 'value': value});

  @override
  void setProbeTarget(String id, double? value) => _send('setProbeTarget', {'id': id, 'value': value});

  @override
  void setLocked(String id, bool locked) => _send('setLocked', {'id': id, 'value': locked});

  @override
  void setMediaOn(String id, bool on) => _send('setMediaOn', {'id': id, 'value': on});

  @override
  void setNowPlayingState(bool playing) {
    // No server-side now-playing mutator yet (Jellyfin bridge is a stub) -
    // reflect it optimistically so the transport controls still feel
    // responsive in live mode.
    compound.nowPlaying?.isPlaying = playing;
    notifyListeners();
  }

  @override
  void turnOffAllLights() => _send('turnOffAllLights', const {});

  @override
  void addDevice(Device device) => _send('addDevice', {'device': device.toJson()});

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
}
