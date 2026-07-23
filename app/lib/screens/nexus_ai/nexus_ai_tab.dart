import 'package:flutter/widgets.dart';
import '../../ai/actions.dart';
import '../../ai/ai_message.dart';
import '../../ai/ai_provider.dart';
import '../../icons/nexus_icons.dart';
import '../../state/ai_scope.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';
import '../security/tab_header.dart';
import 'chat_engine.dart';

const _suggestions = [
  'Turn off all lights',
  'Where is the F-250?',
  'Open barn gate',
  "What's playing?",
  'Any alerts?',
  'Run movie mode',
];

/// NEXUS AI tab (Section 5) - a streaming chat interface routed through the
/// active [ProviderRegistry] provider (on-device / Mac Studio Ollama /
/// Anthropic / OpenAI, chosen in Settings). Replies stream token-by-token
/// into a single bubble, and `<action>` tags in the reply execute device
/// commands against the live store.
class NexusAiTab extends StatefulWidget {
  const NexusAiTab({super.key});

  @override
  State<NexusAiTab> createState() => _NexusAiTabState();
}

class _NexusAiTabState extends State<NexusAiTab> {
  final _messages = <ChatMessage>[];
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _typing = false;

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _typing) return;
    final registry = AiScope.of(context);

    // Build the provider-facing history from the visible conversation so
    // far (before adding this turn), then the new user turn.
    final history = [
      for (final m in _messages)
        AiMessage(m.role == ChatRole.user ? AiRole.user : AiRole.assistant, m.text),
      AiMessage(AiRole.user, trimmed),
    ];

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: trimmed));
      _typing = true;
    });
    _textController.clear();
    _scrollToBottom();

    // Stream the reply through the active provider, appending deltas to a
    // single assistant bubble so tokens render as they arrive. Action tags
    // are stripped from the display and executed once the reply completes.
    final buffer = StringBuffer();
    var assistantIndex = -1;

    void render() {
      final visible = stripActionTags(buffer.toString());
      setState(() {
        if (assistantIndex == -1) {
          _messages.add(ChatMessage(role: ChatRole.assistant, text: visible));
          assistantIndex = _messages.length - 1;
          _typing = false;
        } else {
          _messages[assistantIndex] = ChatMessage(role: ChatRole.assistant, text: visible);
        }
      });
    }

    try {
      await for (final delta in registry.chat(history)) {
        if (!mounted) return;
        buffer.write(delta);
        render();
        _scrollToBottom();
      }
      registry.executeActions(buffer.toString());
    } on AiException catch (e) {
      if (!mounted) return;
      buffer.clear();
      buffer.write(e.displayMessage);
      render();
    } catch (e) {
      if (!mounted) return;
      buffer.clear();
      buffer.write('Something went wrong: $e');
      render();
    } finally {
      if (mounted) {
        setState(() => _typing = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 60), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NexusColors.background,
      child: Column(
        children: [
          const TabHeader(title: 'NEXUS', pillLabel: 'Online', pillColor: NexusColors.green),
          Expanded(
            child: _messages.isEmpty
                ? _Hero(onSuggestion: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _messages.length + (_typing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) return const _TypingBubble();
                      return _Bubble(message: _messages[index]);
                    },
                  ),
          ),
          _Composer(controller: _textController, focusNode: _textFocusNode, onSend: _send),
        ],
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: NexusDurations.pulse)..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NEXUS', style: NexusText.largeTitle.copyWith(color: NexusColors.purple)),
            const SizedBox(height: 6),
            Text('Ask anything about your compound', style: NexusText.subhead, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NexusColors.purple.withValues(alpha: 0.4 + _controller.value * 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(AiScope.of(context).activeLabel, style: NexusText.footnote),
              ],
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in _suggestions)
                  PressScale(
                    onTap: () => widget.onSuggestion(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: NexusColors.surface,
                        borderRadius: BorderRadius.circular(NexusRadii.pill),
                        border: Border.all(color: NexusColors.separator),
                      ),
                      child: Text(suggestion, style: NexusText.bodyMedium),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? NexusColors.blue : NexusColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: NexusText.body.copyWith(color: isUser ? const Color(0xFFFFFFFF) : NexusColors.textPrimary),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: NexusColors.surface, borderRadius: BorderRadius.circular(16)),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  _dot(i),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dot(int index) {
    final t = ((_controller.value + index * 0.2) % 1.0);
    final scale = 0.6 + (t < 0.5 ? t : 1 - t) * 1.2;
    return Transform.scale(
      scale: scale.clamp(0.6, 1.2),
      child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: NexusColors.textFaint, shape: BoxShape.circle)),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.focusNode, required this.onSend});

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: const BoxDecoration(
          color: NexusColors.surface,
          border: Border(top: BorderSide(color: NexusColors.separator, width: 0.6)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: NexusColors.secondarySurface, borderRadius: BorderRadius.circular(20)),
                child: EditableText(
                  controller: controller,
                  focusNode: focusNode,
                  style: NexusText.body,
                  cursorColor: NexusColors.blue,
                  backgroundCursorColor: NexusColors.textFaint,
                  maxLines: 4,
                  minLines: 1,
                  onSubmitted: onSend,
                ),
              ),
            ),
            const SizedBox(width: 10),
            PressScale(
              onTap: () => onSend(controller.text),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: NexusColors.blue, shape: BoxShape.circle),
                child: const Center(child: NexusIcon(NexusGlyph.send, size: 15, color: Color(0xFFFFFFFF))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
