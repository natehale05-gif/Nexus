import '../ai_message.dart';
import '../ai_provider.dart';

/// On-device provider: runs entirely on this device with no network. It's
/// backed today by NEXUS's built-in, house-aware rule-based responder
/// (passed in as [respond]) - a real offline option. The same interface is
/// designed to later host a neural on-device model (llama.cpp / MLX) with no
/// call-site changes.
class LocalProvider implements AiProvider {
  LocalProvider({required this.respond});

  /// Produces a reply from the latest user message + live house state.
  final String Function(String userText) respond;

  @override
  String get backendName => 'On-device';

  @override
  Stream<String> generate(List<AiMessage> messages, {String? model}) async* {
    final lastUser = messages.lastWhere(
      (m) => m.role == AiRole.user,
      orElse: () => const AiMessage(AiRole.user, ''),
    );
    final reply = respond(lastUser.text);
    // Emit in small slices so it renders like the streaming providers.
    const chunk = 24;
    for (var i = 0; i < reply.length; i += chunk) {
      yield reply.substring(i, i + chunk > reply.length ? reply.length : i + chunk);
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }
}
