import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai_message.dart';
import '../ai_provider.dart';
import '../sse.dart';

/// An Ollama instance, local or remote.
///
/// Point [baseUrl] at `http://127.0.0.1:11434` and this is genuinely local
/// inference on the machine running NEXUS - no cloud, no API key. Point it at
/// a Tailscale address and it's the same code talking to a beefier box (the
/// original "Mac Studio" case). Uses Ollama's streaming chat endpoint
/// (`POST /api/chat`, `stream: true`), which emits newline-delimited JSON
/// objects, each carrying a `message.content` delta.
/// True for an Ollama URL pointing at this machine, so the UI can say
/// "this machine" instead of echoing a loopback address back at the user.
bool isLoopback(String baseUrl) {
  final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
  return host == 'localhost' || host == '127.0.0.1' || host == '::1';
}

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
  String get backendName =>
      isLoopback(baseUrl) ? 'Ollama (this machine)' : 'Ollama ($baseUrl)';

  /// Models actually installed on that Ollama, via `GET /api/tags`.
  ///
  /// Worth asking rather than making people type a model name blind: getting
  /// it wrong produces an opaque 404 from Ollama, and the installed set is
  /// the only list that matters.
  static Future<List<String>> listModels(
    String baseUrl, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final owned = client == null;
    final active = client ?? http.Client();
    try {
      final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+\$'), '')}/api/tags');
      final response = await active.get(uri).timeout(timeout);
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final models = <String>[
        for (final entry in (decoded['models'] as List<dynamic>? ?? const []))
          if ((entry as Map<String, dynamic>)['name'] case final String name) name,
      ]..sort();
      return models;
    } catch (_) {
      // Ollama not running, wrong port, or unreachable. An empty list lets the
      // UI say "nothing detected" instead of surfacing a raw socket error.
      return const [];
    } finally {
      if (owned) active.close();
    }
  }

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
