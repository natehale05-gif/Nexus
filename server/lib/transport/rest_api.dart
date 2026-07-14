import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../integrations/ollama_bridge.dart';
import '../state/server_compound.dart';
import 'command_dispatcher.dart';

/// REST API, port 8766 (Section 8) - one-off commands/queries; live push
/// is [WebSocketHub]'s job.
///
/// Routes:
/// - `GET  /health`            -> `{"status": "ok"}`
/// - `GET  /state`             -> the full compound snapshot
/// - `POST /command/<name>`    -> body is the JSON args map for that
///   command (same names/args as the WebSocket `command` message)
/// - `POST /chat`              -> body `{"message": "..."}`, returns
///   `{"message": "<assistant reply>"}`
class RestApi {
  RestApi(this.server, this.dispatcher, this.ollama);

  final ServerCompound server;
  final CommandDispatcher dispatcher;
  final OllamaBridge ollama;

  Handler get handler {
    final router = Router();

    router.get('/health', (Request request) => Response.ok(jsonEncode({'status': 'ok'}), headers: _json));

    router.get('/state', (Request request) {
      return Response.ok(jsonEncode(server.compound.toJson()), headers: _json);
    });

    router.post('/command/<name>', (Request request, String name) async {
      final body = await request.readAsString();
      final args = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map).cast<String, dynamic>();
      try {
        final result = dispatcher.dispatch(name, args);
        return Response.ok(jsonEncode(result), headers: _json);
      } on ArgumentError catch (error) {
        return Response(400, body: jsonEncode({'error': '$error'}), headers: _json);
      }
    });

    router.post('/chat', (Request request) async {
      final body = await request.readAsString();
      final decoded = body.isEmpty ? <String, dynamic>{} : (jsonDecode(body) as Map).cast<String, dynamic>();
      final reply = await ollama.generateReply(decoded['message'] as String? ?? '');
      return Response.ok(jsonEncode({'message': reply}), headers: _json);
    });

    return router.call;
  }

  static const _json = {'content-type': 'application/json'};
}
