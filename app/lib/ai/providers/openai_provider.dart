import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai_message.dart';
import '../ai_provider.dart';
import '../sse.dart';

/// OpenAI Chat Completions API (`POST /v1/chat/completions`, SSE streaming).
/// The system context stays in the `messages` array (role `system`); text
/// arrives as `choices[].delta.content`, terminated by a `data: [DONE]`
/// sentinel.
class OpenAiProvider implements AiProvider {
  OpenAiProvider({
    required this.apiKey,
    this.defaultModel = 'gpt-4o',
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 60),
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final String apiKey;
  final String defaultModel;
  final Duration timeout;
  final http.Client Function() _clientFactory;

  @override
  String get backendName => 'OpenAI';

  @override
  Stream<String> generate(List<AiMessage> messages, {String? model}) async* {
    final client = _clientFactory();
    try {
      final request = http.Request('POST', Uri.parse('https://api.openai.com/v1/chat/completions'))
        ..headers.addAll({
          'content-type': 'application/json',
          'authorization': 'Bearer $apiKey',
        })
        ..body = jsonEncode({
          'model': model ?? defaultModel,
          'stream': true,
          'messages': [
            for (final m in messages) {'role': m.wireRole, 'content': m.text},
          ],
        });
      final response = await client.send(request).timeout(timeout);
      _throwForStatus(response.statusCode);
      await for (final line in decodeLines(response.stream)) {
        final data = sseData(line);
        if (data == null || data.isEmpty) continue;
        if (data == '[DONE]') return;
        final Map<String, dynamic> event;
        try {
          event = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final choices = event['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;
        final delta = (choices.first as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
        final content = delta?['content'] as String?;
        if (content != null && content.isNotEmpty) yield content;
      }
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw AiException(AiErrorKind.timeout, backendName, 'no response within ${timeout.inSeconds}s');
    } catch (e) {
      throw AiException(AiErrorKind.unreachable, backendName, 'Could not reach api.openai.com.');
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
