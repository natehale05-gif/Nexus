import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ai_provider.dart';

/// This device's AI configuration: which provider/model it defaults to, the
/// API keys, and the Mac Studio Ollama URL. Persisted per-device via
/// `flutter_secure_storage` (Keychain / Keystore / encrypted) - never in
/// plain prefs - mirroring `state/connection_settings.dart`.
class AiConfig {
  const AiConfig({
    this.kind = AiProviderKind.local,
    this.model,
    this.anthropicKey,
    this.openAiKey,
    this.macStudioUrl,
  });

  final AiProviderKind kind;
  final String? model;
  final String? anthropicKey;
  final String? openAiKey;
  final String? macStudioUrl;

  AiConfig copyWith({
    AiProviderKind? kind,
    String? model,
    String? anthropicKey,
    String? openAiKey,
    String? macStudioUrl,
  }) =>
      AiConfig(
        kind: kind ?? this.kind,
        model: model ?? this.model,
        anthropicKey: anthropicKey ?? this.anthropicKey,
        openAiKey: openAiKey ?? this.openAiKey,
        macStudioUrl: macStudioUrl ?? this.macStudioUrl,
      );
}

class AiSettings {
  AiSettings({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _kindKey = 'nexus.ai.provider';
  static const _modelKey = 'nexus.ai.model';
  static const _anthropicKey = 'nexus.ai.anthropic_key';
  static const _openAiKey = 'nexus.ai.openai_key';
  static const _macStudioUrlKey = 'nexus.ai.mac_studio_url';

  final FlutterSecureStorage _storage;

  Future<AiConfig> load() async {
    return AiConfig(
      kind: AiProviderKindLabel.fromId(await _storage.read(key: _kindKey)),
      model: _nullIfEmpty(await _storage.read(key: _modelKey)),
      anthropicKey: _nullIfEmpty(await _storage.read(key: _anthropicKey)),
      openAiKey: _nullIfEmpty(await _storage.read(key: _openAiKey)),
      macStudioUrl: _nullIfEmpty(await _storage.read(key: _macStudioUrlKey)),
    );
  }

  Future<void> save(AiConfig config) async {
    await _storage.write(key: _kindKey, value: config.kind.id);
    await _write(_modelKey, config.model);
    await _write(_anthropicKey, config.anthropicKey);
    await _write(_openAiKey, config.openAiKey);
    await _write(_macStudioUrlKey, config.macStudioUrl);
  }

  Future<void> _write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  static String? _nullIfEmpty(String? value) => (value == null || value.isEmpty) ? null : value;
}
