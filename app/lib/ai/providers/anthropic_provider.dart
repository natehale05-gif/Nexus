import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai_message.dart';
import '../ai_provider.dart';
import '../sse.dart';

/// Anthropic Messages API (`POST /v1/messages`, SSE streaming). The system
/// context is passed as the top-level `system` field (Anthropic keeps
/// `messages` to user/assistant turns only); text arrives as
/// `content_block_delta` events.
class AnthropicProvider implements AiProvider {
  AnthropicProvider({
    required this.apiKey,
    this.defaultModel = 'claude-sonnet-5',
    this.maxTokens = 1024,
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 60),
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final String apiKey;
  final String defaultModel;
  final int maxTokens;
  final Duration timeout;
  final http.Client Function() _clientFactory;

  @override
  String get backendName => 'Anthropic';

  @override
  Stream<String> generate(List<AiMessage> messages, {String? model}) async* {
    final system = messages.where((m) => m.role == AiRole.system).map((m) => m.text).join('\n\n');
    final turns = messages.where((m) => m.role != AiRole.system);
    final client = _clientFactory();
    try {
      final request = http.Request('POST', Uri.parse('https://api.anthropic.com/v1/messages'))
        ..headers.addAll({
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          // Lets the browser (web build) attempt the call; note keys in a
          // browser are exposed and CORS may still block it.
          'anthropic-dangerous-direct-browser-access': 'true',
        })
        ..body = jsonEncode({
          'model': model ?? defaultModel,
          'max_tokens': maxTokens,
          if (system.isNotEmpty) 'system': system,
          'stream': true,
          'messages': [
            for (final m in turns) {'role': m.wireRole, 'content': m.text},
          ],
        });
      final response = await client.send(request).timeout(timeout);
      _throwForStatus(response.statusCode);
      await for (final line in decodeLines(response.stream)) {
        final data = sseData(line);
        if (data == null || data.isEmpty) continue;
        final Map<String, dynamic> event;
        try {
          event = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        switch (event['type']) {
          case 'content_block_delta':
            final delta = event['delta'] as Map<String, dynamic>?;
            final text = delta?['text'] as String?;
            if (text != null && text.isNotEmpty) yield text;
          case 'message_stop':
            return;
          case 'error':
            final message = (event['error'] as Map<String, dynamic>?)?['message'] as String? ?? 'stream error';
            throw AiException(AiErrorKind.badResponse, backendName, message);
        }
      }
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw AiException(AiErrorKind.timeout, backendName, 'no response within ${timeout.inSeconds}s');
    } catch (e) {
      throw AiException(AiErrorKind.unreachable, backendName, 'Could not reach api.anthropic.com.');
    } finally {
      client.close();
    }
  }

  void _throwForStatus(int status) {
    if (status == 401 || status == 403) throw AiException(AiErrorKind.auth, backendName, 'unauthorized');
    if (status == 429) throw AiException(AiErrorKind.rateLimited, backendName, 'rate limited');
    if (status >= 400) throw AiException(AiErrorKind.badResponse, backendName, 'HTTP $status');
  }
}
