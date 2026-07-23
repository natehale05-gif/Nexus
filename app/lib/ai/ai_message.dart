/// The provider-facing chat message model. Deliberately separate from the
/// UI's `ChatMessage` (`screens/nexus_ai/chat_engine.dart`) so the `ai/`
/// layer never depends on `screens/` - the AI tab maps between them.
enum AiRole { system, user, assistant }

class AiMessage {
  const AiMessage(this.role, this.text);

  final AiRole role;
  final String text;

  String get wireRole => switch (role) {
        AiRole.system => 'system',
        AiRole.user => 'user',
        AiRole.assistant => 'assistant',
      };
}
