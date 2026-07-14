import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';

/// Large iOS-style toggle switch, 62x36 per spec, with a configurable
/// "on" accent color (green for most toggles, orange for the grill's
/// ignite/shutdown toggle, red is never used here since red means alert).
class NexusSwitch extends StatelessWidget {
  const NexusSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = NexusColors.green,
    this.width = 62,
    this.height = 36,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: NexusDurations.fast,
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? activeColor : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: NexusDurations.fast,
            curve: Curves.easeOut,
            width: height - 6,
            height: height - 6,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
