import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';

/// Wraps any tappable control with the spring-like 0.95x press-scale
/// feedback required everywhere in the app (Section 2).
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.scale = 0.95,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(LongPressStartDetails)? onLongPressStart;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onLongPressStart: widget.onLongPressStart,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onLongPressCancel: () => _setPressed(false),
      onLongPressEnd: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: NexusDurations.fast,
        curve: NexusCurves.pressScale,
        child: widget.child,
      ),
    );
  }
}
