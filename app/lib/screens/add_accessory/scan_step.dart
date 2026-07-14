import 'package:flutter/widgets.dart';
import '../../icons/nexus_icons.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';

/// Add Accessory step 1 (Section 7): animated concentric pulse rings
/// around a signal icon while results stream in over ~2.5s.
class ScanStep extends StatefulWidget {
  const ScanStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<ScanStep> createState() => _ScanStepState();
}

class _ScanStepState extends State<ScanStep> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++) _ring(i),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(color: NexusColors.blue, shape: BoxShape.circle),
                      child: const Center(child: NexusIcon(NexusGlyph.signal, size: 26, color: Color(0xFFFFFFFF))),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          Text('Scanning for accessories', style: NexusText.title),
          const SizedBox(height: 8),
          Text(
            'Checking WiFi, Zigbee, and the mesh network',
            style: NexusText.subhead,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _ring(int index) {
    final t = ((_controller.value + index / 3) % 1.0);
    final size = 60.0 + t * 80;
    final opacity = (1 - t).clamp(0.0, 1.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: NexusColors.blue.withValues(alpha: opacity * 0.5), width: 2),
      ),
    );
  }
}
