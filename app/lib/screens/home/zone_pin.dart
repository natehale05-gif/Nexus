import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../theme/tokens.dart';

/// A zone pin on the Home map (Section 3). Buildings are grouped into
/// zones geographically; pin color/size are computed from every
/// building/device in the zone via [computeZoneStatus].
class ZonePin extends StatefulWidget {
  const ZonePin({
    super.key,
    required this.zone,
    required this.status,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Zone zone;
  final ZoneStatus status;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<ZonePin> createState() => _ZonePinState();
}

class _ZonePinState extends State<ZonePin> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.status.state) {
      case ZonePinState.alert:
        return NexusColors.red;
      case ZonePinState.caution:
        return NexusColors.amber;
      case ZonePinState.secure:
        return NexusColors.blue;
    }
  }

  double get _dotSize {
    switch (widget.status.state) {
      case ZonePinState.alert:
        return 18;
      case ZonePinState.caution:
        return 16;
      case ZonePinState.secure:
        return 12;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldPulse = widget.status.state == ZonePinState.alert && !widget.selected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: NexusTapTargets.mapPin,
        height: NexusTapTargets.mapPin,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final pulseValue = shouldPulse ? _pulse.value : 0.0;
                return Container(
                  width: _dotSize + pulseValue * 14,
                  height: _dotSize + pulseValue * 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _color.withValues(alpha: shouldPulse ? (0.35 * (1 - pulseValue)) : 0),
                  ),
                );
              },
            ),
            AnimatedContainer(
              duration: NexusDurations.fast,
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _color,
                border: widget.selected ? Border.all(color: const Color(0xFFFFFFFF), width: 2.4) : null,
                boxShadow: widget.selected
                    ? [
                        BoxShadow(color: _color.withValues(alpha: 0.9), blurRadius: 6, spreadRadius: 0.5),
                        BoxShadow(color: _color.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 4),
                        const BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 4)),
                      ]
                    : [
                        BoxShadow(color: _color.withValues(alpha: 0.5), blurRadius: 6),
                        const BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
                      ],
              ),
            ),
            if (widget.status.hasOfflineMeshNode)
              Positioned(
                right: NexusTapTargets.mapPin / 2 - _dotSize / 2 - 4,
                top: NexusTapTargets.mapPin / 2 - _dotSize / 2 - 4,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NexusColors.red,
                    border: Border.all(color: NexusColors.mapBase, width: 1.5),
                  ),
                ),
              ),
            Positioned(
              bottom: 6,
              child: Text(
                widget.zone.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFFFFF).withValues(alpha: 0.82),
                  shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
