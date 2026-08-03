import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_app/ai/ai_provider.dart';
import 'package:nexus_app/ai/hugging_face.dart';
import 'package:nexus_app/ai/providers/mac_studio_provider.dart';

void main() {
  group('parameterHint', () {
    test('reads the size out of common repo names', () {
      expect(parameterHint('meta-llama/Llama-3.1-8B-Instruct-GGUF'), '8B');
      expect(parameterHint('TheBloke/Mistral-7B-Instruct-v0.2-GGUF'), '7B');
      expect(parameterHint('Qwen/Qwen2.5-14B-Instruct-GGUF'), '14B');
      expect(parameterHint('org/Phi-3.5-3.8B-gguf'), '3.8B');
    });

    test('returns null rather than a wrong guess', () {
      // No standalone digit+B token here; "base" must not read as a size.
      expect(parameterHint('google-bert/bert-base-uncased'), isNull);
      expect(parameterHint('org/some-model-gguf'), isNull);
      // The owner half is ignored, so a number there can't leak through.
      expect(parameterHint('7Bfoo/plain-model'), isNull);
    });
  });

  group('estimatedRamGb', () {
    test('scales with parameter count', () {
      // ~0.6 GB per billion at 4-bit, plus overhead.
      expect(estimatedRamGb('7B'), closeTo(5.2, 0.01));
      expect(estimatedRamGb('70B'), closeTo(43.0, 0.01));
    });

    test('is null when the size is unknown', () {
      expect(estimatedRamGb(null), isNull);
    });
  });

  group('HuggingFaceCatalog', () {
    test('requests only GGUF models, sorted by downloads', () async {
      Uri? seen;
      final catalog = HuggingFaceCatalog(
        client: MockClient((request) async {
          seen = request.url;
          return http.Response(jsonEncode([
            {'id': 'TheBloke/Mistral-7B-Instruct-v0.2-GGUF', 'downloads': 900, 'likes': 40},
            {'id': 'Qwen/Qwen2.5-14B-Instruct-GGUF', 'downloads': 100, 'likes': 9},
          ]), 200);
        }),
      );

      final models = await catalog.search('mistral');
      // Without the gguf filter the Hub would mostly return PyTorch
      // checkpoints that fail at pull time with nothing explaining why.
      expect(seen!.queryParameters['filter'], 'gguf');
      expect(seen!.queryParameters['search'], 'mistral');
      expect(seen!.queryParameters['sort'], 'downloads');

      expect(models, hasLength(2));
      expect(models.first.id, 'TheBloke/Mistral-7B-Instruct-v0.2-GGUF');
      expect(models.first.owner, 'TheBloke');
      expect(models.first.parameterHint, '7B');
      // This prefix is the whole reason no GGUF loader is needed here.
      expect(models.first.ollamaRef, 'hf.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF');
    });

    test('omits the search param entirely when the query is blank', () async {
      Uri? seen;
      final catalog = HuggingFaceCatalog(client: MockClient((request) async {
        seen = request.url;
        return http.Response('[]', 200);
      }));
      await catalog.search('   ');
      expect(seen!.queryParameters.containsKey('search'), isFalse);
    });

    test('skips malformed entries instead of throwing', () async {
      final catalog = HuggingFaceCatalog(client: MockClient((_) async => http.Response(
            jsonEncode([
              {'no_id': true},
              {'id': 'ok/model-8B-GGUF'},
            ]),
            200,
          )));
      final models = await catalog.search('x');
      expect(models.map((m) => m.id), ['ok/model-8B-GGUF']);
      expect(models.single.downloads, 0);
    });

    test('a failed search surfaces as an exception, not an empty list', () async {
      final catalog = HuggingFaceCatalog(
        client: MockClient((_) async => http.Response('nope', 503)),
      );
      // Silently returning [] would read as "no models match", which is a
      // different and misleading thing.
      expect(catalog.search('x'), throwsA(isA<HuggingFaceException>()));
    });
  });

  group('Ollama pull', () {
    /// Ollama streams newline-delimited JSON from POST /api/pull.
    http.Client streaming(List<String> lines, {int status = 200}) => MockClient.streaming(
          (request, bodyStream) async => http.StreamedResponse(
            Stream.fromIterable(lines.map((l) => utf8.encode('$l\n'))),
            status,
          ),
        );

    test('reports byte progress, then completion', () async {
      final events = await MacStudioProvider.pullModel(
        'http://127.0.0.1:11434',
        'hf.co/org/model-GGUF',
        clientFactory: () => streaming([
          '{"status":"pulling manifest"}',
          '{"status":"pulling abc123","completed":500,"total":1000}',
          '{"status":"verifying sha256 digest"}',
          '{"status":"success"}',
        ]),
      ).toList();

      expect(events.map((e) => e.status), [
        'pulling manifest',
        'pulling abc123',
        'verifying sha256 digest',
        'success',
      ]);
      // Phases without byte counts report null, not a fake 0% that looks stuck.
      expect(events[0].fraction, isNull);
      expect(events[1].fraction, 0.5);
      expect(events[2].fraction, isNull);
      expect(events.last.isComplete, isTrue);
    });

    test('an in-band error is raised even though the status was 200', () async {
      // Ollama reports a bad model name this way, so checking the status code
      // alone would let it look like a successful no-op pull.
      final stream = MacStudioProvider.pullModel(
        'http://127.0.0.1:11434',
        'hf.co/org/nope',
        clientFactory: () => streaming([
          '{"status":"pulling manifest"}',
          '{"error":"repository not found"}',
        ]),
      );
      expect(
        stream.toList(),
        throwsA(isA<AiException>().having((e) => e.detail, 'detail', contains('not found'))),
      );
    });

    test('a non-200 raises with the body included', () async {
      final stream = MacStudioProvider.pullModel(
        'http://127.0.0.1:11434',
        'x',
        clientFactory: () => streaming(['blocked'], status: 500),
      );
      expect(stream.toList(), throwsA(isA<AiException>()));
    });

    test('partial JSON lines are skipped, not fatal', () async {
      final events = await MacStudioProvider.pullModel(
        'http://127.0.0.1:11434',
        'x',
        clientFactory: () => streaming([
          '{"status":"pulling manifest"}',
          '{"status":"trunc',
          '{"status":"success"}',
        ]),
      ).toList();
      expect(events.map((e) => e.status), ['pulling manifest', 'success']);
    });

    test('a trailing slash in the base URL does not produce a double slash', () async {
      Uri? seen;
      await MacStudioProvider.pullModel(
        'http://127.0.0.1:11434/',
        'x',
        clientFactory: () => MockClient.streaming((request, _) async {
          seen = request.url;
          return http.StreamedResponse(const Stream.empty(), 200);
        }),
      ).toList();
      expect(seen.toString(), 'http://127.0.0.1:11434/api/pull');
    });
  });
}
