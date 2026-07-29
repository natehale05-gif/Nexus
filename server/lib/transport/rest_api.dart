import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/pairing_token.dart';
import '../integrations/ollama_bridge.dart';
import '../media/library_index.dart';
import '../media/stream_token.dart';
import '../state/server_compound.dart';
import 'command_dispatcher.dart';

/// REST API, port 8766 (Section 8) - one-off commands/queries; live push
/// is [WebSocketHub]'s job.
///
/// Routes:
/// - `GET  /health`               -> `{"status": "ok"}`
/// - `GET  /state`                -> the full compound snapshot
/// - `POST /command/<name>`       -> body is the JSON args map for that
///   command (same names/args as the WebSocket `command` message)
/// - `POST /chat`                 -> body `{"message": "..."}`, returns
///   `{"message": "<assistant reply>"}`
/// - `GET  /media/stream/<id>?token=<perItemToken>` -> the library item's
///   file, with HTTP range-request support (206 Partial Content) so seeking
///   works. Authenticated separately from everything else here - see
///   `mediaStreamToken` - since video players/browser `<video>` elements
///   can't reliably attach the usual `Authorization` header to range
///   requests.
class RestApi {
  RestApi(this.server, this.dispatcher, this.ollama, this.library, this.pairingToken);

  final ServerCompound server;
  final CommandDispatcher dispatcher;
  final OllamaBridge ollama;
  final LibraryIndex library;
  final PairingToken pairingToken;

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

    router.get('/media/stream/<id>', (Request request, String id) async {
      final item = library.byId(id);
      if (item == null) return Response.notFound('Unknown library item');

      final expected = mediaStreamToken(pairingToken.value, id);
      if (request.url.queryParameters['token'] != expected) {
        return Response.forbidden('Invalid or missing token');
      }

      final file = File(item.path);
      if (!file.existsSync()) return Response.notFound('File missing on disk');
      final length = await file.length();
      final contentType = _contentTypeFor(item.path);

      final rangeHeader = request.headers['range'];
      if (rangeHeader == null) {
        return Response.ok(file.openRead(), headers: {
          ..._json,
          'content-type': contentType,
          'accept-ranges': 'bytes',
          'content-length': '$length',
        });
      }

      final range = _parseRange(rangeHeader, length);
      if (range == null) {
        return Response(416, headers: {'content-range': 'bytes */$length'});
      }
      final (start, end) = range;
      return Response(206,
          body: file.openRead(start, end + 1),
          headers: {
            'content-type': contentType,
            'accept-ranges': 'bytes',
            'content-range': 'bytes $start-$end/$length',
            'content-length': '${end - start + 1}',
          });
    });

    return router.call;
  }

  static const _json = {'content-type': 'application/json'};

  static const _contentTypes = {
    '.mp4': 'video/mp4',
    '.m4v': 'video/x-m4v',
    '.mov': 'video/quicktime',
    '.mkv': 'video/x-matroska',
    '.avi': 'video/x-msvideo',
    '.webm': 'video/webm',
    // Photos
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.heic': 'image/heic',
    '.bmp': 'image/bmp',
    // Music
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.flac': 'audio/flac',
    '.wav': 'audio/wav',
    '.aac': 'audio/aac',
    '.ogg': 'audio/ogg',
    '.opus': 'audio/opus',
  };

  String _contentTypeFor(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot == -1 ? '' : path.substring(dot).toLowerCase();
    return _contentTypes[ext] ?? 'application/octet-stream';
  }

  /// Parses a `Range: bytes=<start>-<end>` header (either bound may be
  /// empty - an open-ended `start-` or a suffix `-N` meaning "last N
  /// bytes"). Returns null for anything malformed or out of bounds.
  (int, int)? _parseRange(String header, int fileLength) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (match == null) return null;
    final startStr = match.group(1) ?? '';
    final endStr = match.group(2) ?? '';
    if (startStr.isEmpty && endStr.isEmpty) return null;

    int start;
    int end;
    if (startStr.isEmpty) {
      final suffixLength = int.parse(endStr);
      start = fileLength - suffixLength;
      if (start < 0) start = 0;
      end = fileLength - 1;
    } else {
      start = int.parse(startStr);
      end = endStr.isEmpty ? fileLength - 1 : int.parse(endStr);
    }
    if (start < 0 || end >= fileLength || start > end) return null;
    return (start, end);
  }
}
