import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
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
/// directly, to point the app at a real running `nexus_server` instance
/// instead. Requires the server's pairing token (shown in its startup
/// log) - see `server/lib/auth/pairing_token.dart`.
class ServerClient extends NexusDataSource {
  ServerClient({required String hostOrUrl, required this.token}) : uri = _normalize(hostOrUrl) {
    _compound = buildDemoCompound();
    _connect();
  }

  final String token;
  final Uri uri;
  late Compound _compound;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int _nextId = 0;
  int _reconnectAttempt = 0;
  bool _disposed = false;
  bool _everConnected = false;

  /// True once at least one real `state` push has arrived from the
  /// server (until then, [compound] is just the local demo seed so the
  /// UI has something sensible to render while connecting).
  bool isConnected = false;

  ConnectionStatus _status = ConnectionStatus.connecting;

  @override
  ConnectionStatus get connectionStatus => _status;

  final _pendingChats = <String, Completer<String>>{};

  /// Bare LAN-shaped addresses (a raw IP, `localhost`, `*.local`, or any
  /// single-label hostname with no domain suffix) default to plain
  /// `ws://` - that's how the server listens directly on the LAN. Anything
  /// else (in particular a Tailscale MagicDNS name like
  /// `myhouse.tailnet-name.ts.net`) defaults to `wss://`, since that's
  /// required for a `https://*.github.io` page to reach it at all (browsers
  /// block plain `ws://` from an https:// origin) - see the root README's
  /// "Remote access with Tailscale" section for fronting both ports with
  /// `tailscale serve`. An explicit `ws://`/`wss://` scheme in [hostOrUrl]
  /// always wins.
  static bool _isLanShaped(String hostAndMaybePort) {
    final host = hostAndMaybePort.split(':').first;
    if (host == 'localhost') return true;
    if (host.endsWith('.local')) return true;
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) return true;
    return !host.contains('.');
  }

  static Uri _normalize(String hostOrUrl) {
    var value = hostOrUrl.trim();
    if (!value.contains('://')) {
      final scheme = _isLanShaped(value) ? 'ws' : 'wss';
      value = '$scheme://$value';
    }
    final uri = Uri.parse(value);
    // Always default to the WebSocket port (8765) - the REST/streaming port
    // is derived from this one (see [_restBaseUri]) as "one more" (8766),
    // matching the server's own default pairing and the tailscale-serve
    // setup documented in the README, so there's only ever one address to
    // configure.
    return uri.hasPort ? uri : uri.replace(port: 8765);
  }

  /// The REST API's base URL, derived from the WebSocket [uri] - the
  /// server always runs REST on the port right after the WebSocket one
  /// (8765/8766 by default, or whatever a `tailscale serve` setup fronts
  /// them as, as long as it keeps that same +1 pairing).
  Uri _restBaseUri() => Uri(
        scheme: uri.scheme == 'wss' ? 'https' : 'http',
        host: uri.host,
        port: uri.port + 1,
      );

  @override
  Compound get compound => _compound;

  @override
  Uri? mediaStreamUri(String itemId) {
    final streamToken = sha256.convert(utf8.encode('$token:$itemId')).toString();
    return _restBaseUri().replace(
      path: '/media/stream/$itemId',
      queryParameters: {'token': streamToken},
    );
  }

  void _connect() {
    _status = _everConnected ? ConnectionStatus.reconnecting : ConnectionStatus.connecting;
    notifyListeners();
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (isConnected) {
      isConnected = false;
      _status = ConnectionStatus.reconnecting;
      notifyListeners();
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    final delaySeconds = min(30, pow(2, _reconnectAttempt).toInt());
    _reconnectAttempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
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
      case 'authResult':
        if (message['ok'] != true) {
          _status = ConnectionStatus.reconnecting;
          notifyListeners();
        }
      case 'state':
        _compound = Compound.fromJson(message['compound'] as Map<String, dynamic>);
        isConnected = true;
        _everConnected = true;
        _status = ConnectionStatus.connected;
        _reconnectAttempt = 0;
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
    _reconnectTimer?.cancel();
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
    // Reflect it optimistically too, so the transport controls feel
    // responsive even before the round-trip completes.
    compound.nowPlaying?.isPlaying = playing;
    notifyListeners();
    _send('setNowPlayingState', {'value': playing});
  }

  @override
  void playLibraryItem(String itemId) => _send('playLibraryItem', {'id': itemId});

  @override
  void reportPlaybackPosition(String itemId, double positionSeconds) =>
      _send('setPlaybackPosition', {'id': itemId, 'value': positionSeconds});

  @override
  void rescanLibrary() => _send('rescanLibrary', const {});

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
