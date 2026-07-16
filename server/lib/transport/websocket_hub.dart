import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/pairing_token.dart';
import '../integrations/ollama_bridge.dart';
import '../state/server_compound.dart';
import 'command_dispatcher.dart';

/// WebSocket state-sync hub, port 8765 (Section 8).
///
/// Protocol (newline-delimited JSON messages, one object per message):
/// - Client -> server, first message on every connection, required before
///   anything else is accepted: `{"type": "auth", "token": "<pairing token>"}`
/// - Server -> client, in reply: `{"type": "authResult", "ok": true|false}`
///   (the socket is closed if `ok` is false or auth doesn't arrive in time)
/// - Server -> client, sent right after a successful auth and again on
///   every state change:
///   `{"type": "state", "compound": {...}}`
/// - Client -> server, to run a command:
///   `{"type": "command", "id": "<echoed back>", "command": "toggleLight", "args": {"id": "lt_kitchen"}}`
/// - Server -> client, command result:
///   `{"type": "commandResult", "id": "<echoed>", "ok": true}` or
///   `{"type": "commandResult", "id": "<echoed>", "ok": false, "error": "..."}`
/// - Client -> server, NEXUS AI chat: `{"type": "chat", "id": "<echoed>", "message": "..."}`
/// - Server -> client: `{"type": "chatReply", "id": "<echoed>", "message": "..."}`
class WebSocketHub {
  WebSocketHub(this.server, this.dispatcher, this.ollama, this.pairingToken);

  final ServerCompound server;
  final CommandDispatcher dispatcher;
  final OllamaBridge ollama;
  final PairingToken pairingToken;

  static const _authTimeout = Duration(seconds: 5);

  final _sockets = <WebSocketChannel>{};
  final _authenticated = <WebSocketChannel>{};

  Handler get handler => webSocketHandler(_onConnect);

  void broadcastState() {
    final payload = jsonEncode({'type': 'state', 'compound': server.compound.toJson()});
    for (final socket in _sockets) {
      if (_authenticated.contains(socket)) socket.sink.add(payload);
    }
  }

  void startBroadcasting() {
    server.onChange.listen((_) => broadcastState());
  }

  void _onConnect(WebSocketChannel socket, String? protocol) {
    _sockets.add(socket);
    log('client connected (${_sockets.length} total, awaiting auth)', name: 'nexus.ws');

    final authDeadline = Timer(_authTimeout, () {
      if (!_authenticated.contains(socket)) {
        log('client did not authenticate in time, closing', name: 'nexus.ws');
        socket.sink.close();
      }
    });

    socket.stream.listen(
      (raw) => _onMessage(socket, raw as String),
      onDone: () {
        authDeadline.cancel();
        _sockets.remove(socket);
        _authenticated.remove(socket);
        log('client disconnected (${_sockets.length} total)', name: 'nexus.ws');
      },
      onError: (_) {
        authDeadline.cancel();
        _sockets.remove(socket);
        _authenticated.remove(socket);
      },
    );
  }

  Future<void> _onMessage(WebSocketChannel socket, String raw) async {
    Map<String, dynamic> message;
    try {
      message = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = message['type'] as String?;
    final id = message['id'];

    if (!_authenticated.contains(socket)) {
      if (type == 'auth' && pairingToken.verify(message['token'] as String?)) {
        _authenticated.add(socket);
        socket.sink.add(jsonEncode({'type': 'authResult', 'ok': true}));
        socket.sink.add(jsonEncode({'type': 'state', 'compound': server.compound.toJson()}));
      } else {
        socket.sink.add(jsonEncode({'type': 'authResult', 'ok': false}));
        await socket.sink.close();
      }
      return;
    }

    if (type == 'command') {
      try {
        final result = dispatcher.dispatch(
          message['command'] as String,
          (message['args'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
        socket.sink.add(jsonEncode({'type': 'commandResult', 'id': id, 'ok': true, ...result}));
      } catch (error) {
        socket.sink.add(jsonEncode({'type': 'commandResult', 'id': id, 'ok': false, 'error': '$error'}));
      }
    } else if (type == 'chat') {
      final reply = await ollama.generateReply(message['message'] as String? ?? '');
      socket.sink.add(jsonEncode({'type': 'chatReply', 'id': id, 'message': reply}));
    }
  }
}
