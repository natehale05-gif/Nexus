import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/state/server_client.dart';
import 'package:nexus_shared/nexus_shared.dart';

/// A tiny in-process fake of the real server's WebSocket protocol
/// (`server/lib/transport/websocket_hub.dart`) - just enough to exercise
/// [ServerClient] without spinning up the whole `nexus_server` package as
/// a test dependency.
class _FakeHub {
  _FakeHub(this.compound);

  final Compound compound;
  HttpServer? _server;
  WebSocket? _socket;

  Future<int> start() async {
    _server = await HttpServer.bind('127.0.0.1', 0);
    _server!.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      _socket = socket;
      socket.add(jsonEncode({'type': 'state', 'compound': compound.toJson()}));
      socket.listen((raw) => _onMessage(socket, raw as String));
    });
    return _server!.port;
  }

  void _onMessage(WebSocket socket, String raw) {
    final message = jsonDecode(raw) as Map<String, dynamic>;
    if (message['type'] == 'command') {
      final args = (message['args'] as Map).cast<String, dynamic>();
      if (message['command'] == 'toggleLight') {
        final light = compound.devices.whereType<LightDevice>().firstWhere((d) => d.id == args['id']);
        light.on = !light.on;
      }
      socket.add(jsonEncode({'type': 'commandResult', 'id': message['id'], 'ok': true}));
      socket.add(jsonEncode({'type': 'state', 'compound': compound.toJson()}));
    } else if (message['type'] == 'chat') {
      socket.add(jsonEncode({'type': 'chatReply', 'id': message['id'], 'message': 'fake reply'}));
    }
  }

  Future<void> stop() async {
    await _socket?.close();
    await _server?.close(force: true);
  }
}

void main() {
  late _FakeHub hub;
  late int port;

  setUp(() async {
    hub = _FakeHub(buildDemoCompound());
    port = await hub.start();
  });

  tearDown(() async {
    await hub.stop();
  });

  test('receives the initial state push and reflects it in compound', () async {
    final client = ServerClient(hostOrUrl: '127.0.0.1:$port', token: 'test-token');
    addTearDown(client.dispose);

    await _waitFor(() => client.isConnected);

    expect(client.compound.zones, isNotEmpty);
    expect(client.isConnected, isTrue);
  });

  test('toggleLight sends a command and reflects the broadcasted result', () async {
    final client = ServerClient(hostOrUrl: '127.0.0.1:$port', token: 'test-token');
    addTearDown(client.dispose);
    await _waitFor(() => client.isConnected);

    final light = client.compound.devices.whereType<LightDevice>().first;
    final initial = light.on;

    client.toggleLight(light.id);

    await _waitFor(() {
      final current = client.compound.devices.whereType<LightDevice>().firstWhere((d) => d.id == light.id);
      return current.on != initial;
    });
  });

  test('sendChat resolves with the server reply', () async {
    final client = ServerClient(hostOrUrl: '127.0.0.1:$port', token: 'test-token');
    addTearDown(client.dispose);
    await _waitFor(() => client.isConnected);

    final reply = await client.sendChat('hello');
    expect(reply, 'fake reply');
  });

  group('address failover', () {
    test('falls through a dead address to a live one', () async {
      // Port 1 is reserved and nothing listens there, which is what "the LAN
      // address you paired on at home" looks like from a hotel.
      final client = ServerClient(
        hostOrUrl: '127.0.0.1:1',
        token: 'test-token',
        fallbacks: ['127.0.0.1:$port'],
      );
      addTearDown(client.dispose);

      await _waitFor(() => client.isConnected, timeout: const Duration(seconds: 10));
      expect(client.activeAddress, '127.0.0.1:$port');
    });

    test('a duplicate address does not cost an extra failed attempt', () async {
      final client = ServerClient(
        hostOrUrl: '127.0.0.1:$port',
        token: 'test-token',
        fallbacks: ['127.0.0.1:$port', '  ', '127.0.0.1:$port'],
      );
      addTearDown(client.dispose);
      await _waitFor(() => client.isConnected);
      expect(client.activeAddress, '127.0.0.1:$port');
    });

    test('reaching the server keeps working after failover, not just connecting',
        () async {
      final client = ServerClient(
        hostOrUrl: '127.0.0.1:1',
        token: 'test-token',
        fallbacks: ['127.0.0.1:$port'],
      );
      addTearDown(client.dispose);
      await _waitFor(() => client.isConnected, timeout: const Duration(seconds: 10));

      // Media streams are built off the active address, so a stale one here
      // would connect fine and then fail to play anything.
      final stream = client.mediaStreamUri('some-item')!;
      expect(stream.port, port + 1);

      final light = client.compound.devices.whereType<LightDevice>().first;
      final initial = light.on;
      client.toggleLight(light.id);
      await _waitFor(() {
        final current =
            client.compound.devices.whereType<LightDevice>().firstWhere((d) => d.id == light.id);
        return current.on != initial;
      });
    });
  });
}

Future<void> _waitFor(bool Function() predicate, {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $timeout');
    }
    await Future.delayed(const Duration(milliseconds: 20));
  }
}
