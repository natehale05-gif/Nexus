import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai_message.dart';
import '../ai_provider.dart';
import '../sse.dart';

/// Remote Ollama instance (the user's Mac Studio), reached over Tailscale at
/// a user-set base URL. Uses Ollama's streaming chat endpoint
/// (`POST /api/chat`, `stream: true`), which emits newline-delimited JSON
/// objects, each carrying a `message.content` delta.
class MacStudioProvider implements AiProvider {
  MacStudioProvider({
    required this.baseUrl,
    this.defaultModel = 'llama3.1',
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 60),
  }) : _clientFactory = clientFactory ?? http.Client.new;

  /// e.g. `http://100.x.y.z:11434` (Tailscale) or `http://192.168.1.50:11434`.
  final String baseUrl;
  final String defaultModel;
  final Duration timeout;
  final http.Client Function() _clientFactory;

  @override
  String get backendName => 'Mac Studio (Ollama)';

  @override
  Stream<String> generate(List<AiMessage> messages, {String? model}) async* {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/chat');
    final client = _clientFactory();
    try {
      final request = http.Request('POST', uri)
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode({
          'model': model ?? defaultModel,
          'stream': true,
          'messages': [
            for (final m in messages) {'role': m.wireRole, 'content': m.text},
          ],
        });
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode >= 400) {
        throw AiException(AiErrorKind.badResponse, backendName, 'HTTP ${response.statusCode}');
      }
      await for (final line in decodeLines(response.stream)) {
        if (line.trim().isEmpty) continue;
        final Map<String, dynamic> obj;
        try {
          obj = jsonDecode(line) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final content = (obj['message'] as Map<String, dynamic>?)?['content'] as String?;
        if (content != null && content.isNotEmpty) yield content;
        if (obj['done'] == true) break;
      }
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw AiException(AiErrorKind.timeout, backendName, 'no response within ${timeout.inSeconds}s');
    } catch (e) {
      throw AiException(AiErrorKind.unreachable, backendName, 'Could not reach $uri (check the address / Tailscale).');
    } finally {
      client.close();
    }
  }
}
