import 'ai_message.dart';

/// The four selectable chat backends.
enum AiProviderKind { local, macStudio, anthropic, openai }

extension AiProviderKindLabel on AiProviderKind {
  /// Stable id used in persisted settings / the wire.
  String get id => switch (this) {
        AiProviderKind.local => 'local',
        AiProviderKind.macStudio => 'mac_studio',
        AiProviderKind.anthropic => 'anthropic',
        AiProviderKind.openai => 'openai',
      };

  String get label => switch (this) {
        AiProviderKind.local => 'Built-in (no download)',
        // The id stays `mac_studio` for settings already on disk. The label
        // deliberately doesn't name the engine: NEXUS installs and runs it
        // now, so which one it is stopped being the user's problem.
        AiProviderKind.macStudio => 'Local model',
        AiProviderKind.anthropic => 'Anthropic',
        AiProviderKind.openai => 'OpenAI',
      };

  static AiProviderKind fromId(String? id) => switch (id) {
        'mac_studio' => AiProviderKind.macStudio,
        'anthropic' => AiProviderKind.anthropic,
        'openai' => AiProviderKind.openai,
        _ => AiProviderKind.local,
      };
}

/// What went wrong, distinct enough per bucket that a user-facing message
/// makes it obvious which backend failed and why.
enum AiErrorKind { auth, timeout, unreachable, rateLimited, badResponse }

class AiException implements Exception {
  AiException(this.kind, this.backend, this.detail);

  final AiErrorKind kind;

  /// Human name of the backend that failed, e.g. "Anthropic" or
  /// "Mac Studio (Ollama)".
  final String backend;

  final String detail;

  /// The message shown in the chat when this provider fails.
  String get displayMessage => switch (kind) {
        AiErrorKind.auth => '$backend: authentication failed - check the API key in Settings.',
        AiErrorKind.timeout => '$backend timed out. Check your connection and try again.',
        AiErrorKind.unreachable => "$backend is unreachable. $detail",
        AiErrorKind.rateLimited => '$backend is rate-limited right now - try again in a moment.',
        AiErrorKind.badResponse => '$backend returned an error: $detail',
      };

  @override
  String toString() => 'AiException($backend, $kind, $detail)';
}

/// A chat backend. Every implementation streams the assistant's reply as
/// incremental text deltas so the UI can render tokens as they arrive,
/// uniformly across on-device, remote Ollama, Anthropic, and OpenAI.
abstract class AiProvider {
  String get backendName;

  /// Streams the assistant reply for [messages] (which may include a leading
  /// [AiRole.system] context message). [model] overrides the provider's
  /// default when given. Throws [AiException] on failure.
  Stream<String> generate(List<AiMessage> messages, {String? model});
}
