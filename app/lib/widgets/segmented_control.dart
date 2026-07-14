import 'package:flutter/widgets.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// iOS-style segmented control: rounded gray track with an animated white
/// pill sliding behind the selected label. Used for the grill/thermostat
/// fan Auto/On picker (Section 4).
class NexusSegmentedControl<T> extends StatelessWidget {
  const NexusSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 36,
  });

  final List<NexusSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = segments.indexWhere((s) => s.value == value);
    return LayoutBuilder(builder: (context, constraints) {
      final segmentWidth = constraints.maxWidth / segments.length;
      return Container(
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: NexusColors.secondarySurface,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: NexusDurations.fast,
              curve: Curves.easeOut,
              left: selectedIndex < 0 ? 0 : segmentWidth * selectedIndex - 3,
              top: 0,
              bottom: 0,
              width: segmentWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular((height - 6) / 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (final segment in segments)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(segment.value),
                      child: Center(
                        child: Text(
                          segment.label,
                          style: NexusText.bodyMedium.copyWith(
                            color: segment.value == value
                                ? NexusColors.textPrimary
                                : NexusColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class NexusSegment<T> {
  const NexusSegment(this.value, this.label);
  final T value;
  final String label;
}
