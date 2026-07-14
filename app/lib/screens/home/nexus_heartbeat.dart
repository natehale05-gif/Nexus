import 'package:flutter/widgets.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';

/// Small pulsing green "NEXUS" wordmark + dot, bottom-left of the map - a
/// quiet system-online heartbeat, deliberately *not* a data widget
/// (Section 3).
class NexusHeartbeat extends StatefulWidget {
  const NexusHeartbeat({super.key});

  @override
  State<NexusHeartbeat> createState() => _NexusHeartbeatState();
}

class _NexusHeartbeatState extends State<NexusHeartbeat> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: NexusDurations.pulse)..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final opacity = 0.4 + _controller.value * 0.6;
            return Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NexusColors.green.withValues(alpha: opacity),
                boxShadow: [
                  BoxShadow(color: NexusColors.green.withValues(alpha: opacity * 0.6), blurRadius: 6),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 7),
        Text(
          'NEXUS',
          style: NexusText.caption.copyWith(
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.72),
            fontSize: 11,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}
