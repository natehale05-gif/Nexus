import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ai_message.dart';
import '../ai_provider.dart';
import '../sse.dart';

/// True for an Ollama URL pointing at this machine, so the UI can say
/// "this machine" instead of echoing a loopback address back at the user.
bool isLoopback(String baseUrl) {
  final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
  return host == 'localhost' || host == '127.0.0.1' || host == '::1';
}

/// One progress event from an Ollama model pull.
class PullProgress {
  const PullProgress({required this.status, this.completed, this.total});

  final String status;
  final int? completed;
  final int? total;

  /// 0..1 while layers are downloading, null during the phases Ollama reports
  /// without byte counts (manifest, verify, extract) - a fake 0% there would
  /// look stuck.
  double? get fraction {
    final done = completed, all = total;
    if (done == null || all == null || all <= 0) return null;
    return (done / all).clamp(0.0, 1.0);
  }

  bool get isComplete => status == 'success';
}

/// An Ollama instance, local or remote.
///
/// Point [baseUrl] at `http://127.0.0.1:11434` and this is genuinely local
/// inference on the machine running NEXUS - no cloud, no API key. Point it at
/// a Tailscale address and it's the same code talking to a beefier box (the
/// original "Mac Studio" case). Uses Ollama's streaming chat endpoint
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
      final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/tags');
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

  /// Downloads a model into Ollama, streaming progress.
  ///
  /// `POST /api/pull` emits newline-delimited JSON with `status`, and for the
  /// layer-download phase `completed`/`total` bytes. Ollama accepts Hugging
  /// Face repos directly as `hf.co/owner/repo`, which is why pulling a model
  /// from HF needs no downloader or GGUF loader of NEXUS's own - and why the
  /// model lands somewhere the existing chat path can already use it.
  static Stream<PullProgress> pullModel(
    String baseUrl,
    String model, {
    http.Client Function()? clientFactory,
  }) async* {
    final client = (clientFactory ?? http.Client.new)();
    try {
      final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/pull');
      final request = http.Request('POST', uri)
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode({'model': model, 'stream': true});
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw AiException(
          response.statusCode == 404 ? AiErrorKind.badResponse : AiErrorKind.unreachable,
          'Ollama',
          'Could not pull "$model" (${response.statusCode}). $body'.trim(),
        );
      }

      await for (final line in decodeLines(response.stream)) {
        if (line.trim().isEmpty) continue;
        final Map<String, dynamic> event;
        try {
          event = jsonDecode(line) as Map<String, dynamic>;
        } catch (_) {
          continue; // A partial line mid-stream isn't fatal.
        }
        // Ollama reports failures in-band with a 200, so this has to be
        // checked per event rather than only on the status code.
        final error = event['error'];
        if (error != null) {
          throw AiException(AiErrorKind.badResponse, 'Ollama', '$error');
        }
        yield PullProgress(
          status: (event['status'] as String?) ?? '',
          completed: (event['completed'] as num?)?.toInt(),
          total: (event['total'] as num?)?.toInt(),
        );
      }
    } finally {
      client.close();
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
