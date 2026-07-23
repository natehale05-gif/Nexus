import 'package:flutter/foundation.dart';

import '../state/nexus_data_source.dart';
import 'actions.dart';
import 'ai_message.dart';
import 'ai_provider.dart';
import 'ai_settings.dart';
import 'providers/anthropic_provider.dart';
import 'providers/local_provider.dart';
import 'providers/mac_studio_provider.dart';
import 'providers/openai_provider.dart';

/// Holds the active AI provider + model choice for this device and routes
/// chat through it. Same `ChangeNotifier` shape as the rest of the app's
/// state; exposed to the tree via `state/ai_scope.dart`.
///
/// The `localResponder` and `systemContext` callbacks are injected (from
/// `main.dart`) so this `ai/` layer never imports `screens/` - they wrap
/// `generateAssistantReply` and `buildSystemContext` respectively against
/// the live store.
class ProviderRegistry extends ChangeNotifier {
  ProviderRegistry({
    required AiSettings settings,
    required NexusDataSource Function() storeOf,
    required String Function() systemContext,
    required String Function(String userText) localResponder,
  })  : _settings = settings,
        _storeOf = storeOf,
        _systemContext = systemContext,
        _localResponder = localResponder;

  final AiSettings _settings;
  final NexusDataSource Function() _storeOf;
  final String Function() _systemContext;
  final String Function(String userText) _localResponder;

  AiConfig _config = const AiConfig();
  AiConfig get config => _config;

  AiProviderKind get activeKind => _config.kind;
  String? get activeModel => _config.model;

  /// A short label for the AI hero, e.g. "Anthropic · claude-sonnet-5".
  String get activeLabel {
    final model = _config.model;
    return model == null || model.isEmpty ? _config.kind.label : '${_config.kind.label} · $model';
  }

  Future<void> load() async {
    _config = await _settings.load();
    notifyListeners();
  }

  /// Whether [kind] has what it needs to run (a key / URL). `local` always
  /// does; the others need their credential set.
  bool isConfigured(AiProviderKind kind) => switch (kind) {
        AiProviderKind.local => true,
        AiProviderKind.macStudio => (_config.macStudioUrl ?? '').isNotEmpty,
        AiProviderKind.anthropic => (_config.anthropicKey ?? '').isNotEmpty,
        AiProviderKind.openai => (_config.openAiKey ?? '').isNotEmpty,
      };

  Future<void> update(AiConfig config) async {
    _config = config;
    await _settings.save(config);
    notifyListeners();
  }

  Future<void> selectProvider(AiProviderKind kind) => update(_config.copyWith(kind: kind));

  /// Streams the assistant reply for [messages], prepending the live house
  /// context as a system message. Errors surface as an [AiException] on the
  /// stream (the UI shows `displayMessage`).
  Stream<String> chat(List<AiMessage> messages) async* {
    final provider = _buildActive();
    final context = _systemContext();
    final withContext = [
      if (context.trim().isNotEmpty) AiMessage(AiRole.system, _systemPrompt(context)),
      ...messages,
    ];
    yield* provider.generate(withContext, model: _config.model);
  }

  /// Executes any `<action .../>` tags the model emitted against the live
  /// store (device control). Call once with the completed reply text.
  void executeActions(String fullText) => executeActionTags(fullText, _storeOf());

  String _systemPrompt(String context) =>
      'You are NEXUS, the assistant for a private compound. Live state:\n$context\n'
      'To control a device, emit a self-closing tag like '
      '<action name="setLocked" id="lk_front" value="false" />. Keep replies concise.';

  AiProvider _buildActive() {
    switch (_config.kind) {
      case AiProviderKind.local:
        return LocalProvider(respond: _localResponder);
      case AiProviderKind.macStudio:
        final url = _config.macStudioUrl;
        if (url == null || url.isEmpty) {
          throw AiException(AiErrorKind.unreachable, 'Mac Studio (Ollama)', 'Set the Mac Studio URL in Settings.');
        }
        return MacStudioProvider(baseUrl: url);
      case AiProviderKind.anthropic:
        final key = _config.anthropicKey;
        if (key == null || key.isEmpty) {
          throw AiException(AiErrorKind.auth, 'Anthropic', 'no key');
        }
        return AnthropicProvider(apiKey: key);
      case AiProviderKind.openai:
        final key = _config.openAiKey;
        if (key == null || key.isEmpty) {
          throw AiException(AiErrorKind.auth, 'OpenAI', 'no key');
        }
        return OpenAiProvider(apiKey: key);
    }
  }
}
