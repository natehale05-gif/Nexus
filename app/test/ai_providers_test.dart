import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexus_app/ai/actions.dart';
import 'package:nexus_app/ai/ai_message.dart';
import 'package:nexus_app/ai/ai_provider.dart';
import 'package:nexus_app/ai/providers/anthropic_provider.dart';
import 'package:nexus_app/ai/providers/mac_studio_provider.dart';
import 'package:nexus_app/ai/providers/openai_provider.dart';
import 'package:nexus_app/state/compound_store.dart';
import 'package:nexus_shared/nexus_shared.dart';

/// A fake [http.Client] that returns a canned streamed body (the lines
/// joined by newlines), so we can exercise the providers' SSE/NDJSON
/// parsing without hitting a real API.
class _FakeClient extends http.BaseClient {
  _FakeClient({this.status = 200, this.lines = const []});

  final int status;
  final List<String> lines;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = utf8.encode('${lines.join('\n')}\n');
    return http.StreamedResponse(Stream.value(body), status);
  }
}

const _messages = [AiMessage(AiRole.user, 'hi')];

void main() {
  group('OpenAiProvider', () {
    test('parses SSE deltas until [DONE]', () async {
      final provider = OpenAiProvider(
        apiKey: 'k',
        clientFactory: () => _FakeClient(lines: [
          'data: {"choices":[{"delta":{"content":"Hel"}}]}',
          'data: {"choices":[{"delta":{"content":"lo"}}]}',
          'data: [DONE]',
          'data: {"choices":[{"delta":{"content":"IGNORED"}}]}',
        ]),
      );
      final out = await provider.generate(_messages).join();
      expect(out, 'Hello');
    });

    test('maps 401 to an auth AiException', () async {
      final provider = OpenAiProvider(apiKey: 'bad', clientFactory: () => _FakeClient(status: 401));
      expect(
        () => provider.generate(_messages).toList(),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.auth)),
      );
    });
  });

  group('AnthropicProvider', () {
    test('parses content_block_delta events and stops at message_stop', () async {
      final provider = AnthropicProvider(
        apiKey: 'k',
        clientFactory: () => _FakeClient(lines: [
          'event: content_block_delta',
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hi"}}',
          '',
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":" there"}}',
          '',
          'data: {"type":"message_stop"}',
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"AFTER"}}',
        ]),
      );
      final out = await provider.generate(_messages).join();
      expect(out, 'Hi there');
    });

    test('maps 429 to a rateLimited AiException', () async {
      final provider = AnthropicProvider(apiKey: 'k', clientFactory: () => _FakeClient(status: 429));
      expect(
        () => provider.generate(_messages).toList(),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.rateLimited)),
      );
    });
  });

  group('MacStudioProvider', () {
    test('parses Ollama NDJSON message.content until done', () async {
      final provider = MacStudioProvider(
        baseUrl: 'http://127.0.0.1:11434',
        clientFactory: () => _FakeClient(lines: [
          '{"message":{"role":"assistant","content":"Yo"},"done":false}',
          '{"message":{"role":"assistant","content":"!"},"done":true}',
          '{"message":{"role":"assistant","content":"AFTER"},"done":false}',
        ]),
      );
      final out = await provider.generate(_messages).join();
      expect(out, 'Yo!');
    });
  });

  group('action tags', () {
    test('executeActionTags turns off all lights against the store', () {
      final store = CompoundStore();
      for (final l in store.compound.devices.whereType<LightDevice>()) {
        l.on = true;
      }
      executeActionTags('Sure.<action name="turnOffAllLights" />', store);
      expect(store.compound.devices.whereType<LightDevice>().every((l) => !l.on), isTrue);
      store.dispose();
    });

    test('stripActionTags removes the tag from display text', () {
      expect(stripActionTags('Done.<action name="turnOffAllLights" />'), 'Done.');
    });
  });

  group('AiProviderKind', () {
    test('id round-trips through fromId', () {
      for (final kind in AiProviderKind.values) {
        expect(AiProviderKindLabel.fromId(kind.id), kind);
      }
    });
  });
}
