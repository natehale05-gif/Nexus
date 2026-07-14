import 'dart:convert';
import 'dart:developer';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../integrations/ollama_bridge.dart';
import '../state/server_compound.dart';
import 'command_dispatcher.dart';

/// WebSocket state-sync hub, port 8765 (Section 8).
///
/// Protocol (newline-delimited JSON messages, one object per message):
/// - Server -> client, sent on connect and again on every state change:
///   `{"type": "state", "compound": {...}}`
/// - Client -> server, to run a command:
///   `{"type": "command", "id": "<echoed back>", "command": "toggleLight", "args": {"id": "lt_kitchen"}}`
/// - Server -> client, command result:
///   `{"type": "commandResult", "id": "<echoed>", "ok": true}` or
///   `{"type": "commandResult", "id": "<echoed>", "ok": false, "error": "..."}`
/// - Client -> server, NEXUS AI chat: `{"type": "chat", "id": "<echoed>", "message": "..."}`
/// - Server -> client: `{"type": "chatReply", "id": "<echoed>", "message": "..."}`
class WebSocketHub {
  WebSocketHub(this.server, this.dispatcher, this.ollama);

  final ServerCompound server;
  final CommandDispatcher dispatcher;
  final OllamaBridge ollama;

  final _sockets = <WebSocketChannel>{};

  Handler get handler => webSocketHandler(_onConnect);

  void broadcastState() {
    final payload = jsonEncode({'type': 'state', 'compound': server.compound.toJson()});
    for (final socket in _sockets) {
      socket.sink.add(payload);
    }
  }

  void startBroadcasting() {
    server.onChange.listen((_) => broadcastState());
  }

  void _onConnect(WebSocketChannel socket, String? protocol) {
    _sockets.add(socket);
    log('client connected (${_sockets.length} total)', name: 'nexus.ws');
    socket.sink.add(jsonEncode({'type': 'state', 'compound': server.compound.toJson()}));

    socket.stream.listen(
      (raw) => _onMessage(socket, raw as String),
      onDone: () {
        _sockets.remove(socket);
        log('client disconnected (${_sockets.length} total)', name: 'nexus.ws');
      },
      onError: (_) => _sockets.remove(socket),
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
