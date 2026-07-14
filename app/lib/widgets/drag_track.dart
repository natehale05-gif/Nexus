import 'package:flutter/widgets.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// The horizontal drag-to-dim / drag-to-set-temp track used by the Light
/// row (0-100%) and the Grill temp control (165-500F) - Section 4.
///
/// 52px tall, rounded, gradient fill proportional to value, draggable thumb
/// line, live label inside the track. Always measures against the actual
/// rendered widget width at drag time via [LayoutBuilder]/`globalToLocal`,
/// never a hardcoded assumed size.
class DragTrack extends StatefulWidget {
  const DragTrack({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    required this.gradientColors,
    required this.labelBuilder,
    this.enabled = true,
    this.height = 52,
  });

  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;
  final List<Color> gradientColors;
  final String Function(double value) labelBuilder;
  final bool enabled;
  final double height;

  @override
  State<DragTrack> createState() => _DragTrackState();
}

class _DragTrackState extends State<DragTrack> {
  final _key = GlobalKey();

  void _handlePosition(Offset globalPosition) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !widget.enabled) return;
    final local = box.globalToLocal(globalPosition);
    final fraction = (local.dx / box.size.width).clamp(0.0, 1.0);
    final raw = widget.min + fraction * (widget.max - widget.min);
    widget.onChanged(raw);
  }

  @override
  Widget build(BuildContext context) {
    final fraction =
        ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    return Opacity(
      opacity: widget.enabled ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: widget.enabled ? (d) => _handlePosition(d.globalPosition) : null,
        onPanUpdate: widget.enabled ? (d) => _handlePosition(d.globalPosition) : null,
        child: Container(
          key: _key,
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: NexusColors.secondarySurface,
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              LayoutBuilder(builder: (context, constraints) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: constraints.maxWidth * fraction,
                  height: widget.height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: widget.gradientColors),
                  ),
                );
              }),
              LayoutBuilder(builder: (context, constraints) {
                final x = (constraints.maxWidth * fraction).clamp(6.0, constraints.maxWidth - 6);
                return Positioned(
                  left: x - 1.5,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 2),
                      ],
                    ),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.labelBuilder(widget.value),
                  style: NexusText.bodyMedium.copyWith(
                    color: NexusColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row of quick-set preset buttons shown below a [DragTrack].
class PresetRow extends StatelessWidget {
  const PresetRow({
    super.key,
    required this.presets,
    required this.selectedValue,
    required this.onSelect,
    required this.accentColor,
    this.enabled = true,
  });

  final List<PresetValue> presets;
  final double selectedValue;
  final ValueChanged<double> onSelect;
  final Color accentColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(
        children: [
          for (final preset in presets)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: enabled ? () => onSelect(preset.value) : null,
                  child: AnimatedContainer(
                    duration: NexusDurations.fast,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedValue == preset.value
                          ? accentColor.withValues(alpha: 0.16)
                          : NexusColors.secondarySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedValue == preset.value
                            ? accentColor
                            : const Color(0x00000000),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      preset.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selectedValue == preset.value
                            ? accentColor
                            : NexusColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PresetValue {
  const PresetValue(this.value, this.label);
  final double value;
  final String label;
}
