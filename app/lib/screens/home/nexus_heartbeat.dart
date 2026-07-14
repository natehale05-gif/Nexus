import 'package:flutter/widgets.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';

/// Small pulsing "NEXUS" wordmark + dot, bottom-left of the map - a quiet
/// system-online heartbeat, deliberately *not* a data widget (Section 3).
///
/// [connectionState] is purely cosmetic and doesn't add app chrome: green
/// stays the default local-demo-mode heartbeat, but when the app is
/// running in live mode against a real server (Section 9's `?server=`
/// wiring) it reflects that connection so testers can tell at a glance
/// whether they're looking at demo or live data.
enum HeartbeatConnection { demo, live, liveConnecting }

class NexusHeartbeat extends StatefulWidget {
  const NexusHeartbeat({super.key, this.connectionState = HeartbeatConnection.demo});

  final HeartbeatConnection connectionState;

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

  Color get _dotColor {
    switch (widget.connectionState) {
      case HeartbeatConnection.demo:
      case HeartbeatConnection.live:
        return NexusColors.green;
      case HeartbeatConnection.liveConnecting:
        return NexusColors.amber;
    }
  }

  String? get _suffix {
    switch (widget.connectionState) {
      case HeartbeatConnection.demo:
        return null;
      case HeartbeatConnection.live:
        return ' · LIVE';
      case HeartbeatConnection.liveConnecting:
        return ' · CONNECTING';
    }
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
                color: _dotColor.withValues(alpha: opacity),
                boxShadow: [
                  BoxShadow(color: _dotColor.withValues(alpha: opacity * 0.6), blurRadius: 6),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 7),
        Text(
          'NEXUS${_suffix ?? ''}',
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
