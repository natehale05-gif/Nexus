import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../../icons/nexus_icons.dart';
import '../../../state/compound_scope.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/drag_track.dart';
import '../../../widgets/expand_section.dart';
import '../../../widgets/nexus_switch.dart';
import 'device_row_shell.dart';

/// Light device row + expanded drag-to-dim control (Section 4).
class LightRow extends StatefulWidget {
  const LightRow({super.key, required this.device});

  final LightDevice device;

  @override
  State<LightRow> createState() => _LightRowState();
}

class _LightRowState extends State<LightRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    final device = widget.device;

    return DeviceRowShell(
      onTap: () => setState(() => _expanded = !_expanded),
      leading: _DimmerRingIcon(brightness: device.brightness, on: device.on),
      title: device.name,
      subtitle: device.on ? '${device.brightness}% · tap ring to dim' : 'Off',
      trailing: NexusSwitch(
        value: device.on,
        onChanged: (v) => store.toggleLight(device.id),
      ),
      expanded: _expanded,
      child: ExpandSection(
        expanded: _expanded,
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Column(
            children: [
              DragTrack(
                min: 0,
                max: 100,
                value: device.brightness.toDouble(),
                enabled: true,
                gradientColors: const [Color(0xFFFFD37A), NexusColors.amber],
                labelBuilder: (v) => '${v.round()}%',
                onChanged: (v) => store.setBrightness(device.id, v),
              ),
              const SizedBox(height: 10),
              PresetRow(
                presets: const [
                  PresetValue(10, '10%'),
                  PresetValue(25, '25%'),
                  PresetValue(50, '50%'),
                  PresetValue(75, '75%'),
                  PresetValue(100, '100%'),
                ],
                selectedValue: device.brightness.toDouble(),
                accentColor: NexusColors.amber,
                onSelect: (v) => store.setBrightness(device.id, v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DimmerRingIcon extends StatelessWidget {
  const _DimmerRingIcon({required this.brightness, required this.on});

  final int brightness;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(40, 40),
            painter: _RingPainter(fraction: on ? brightness / 100 : 0, color: NexusColors.amber),
          ),
          NexusIcon(
            NexusGlyph.bulb,
            size: 18,
            color: on ? NexusColors.amber : NexusColors.textFaint,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final track = Paint()
      ..color = const Color(0xFFE5E5EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(rect, -1.5708, 6.2832, false, track);
    if (fraction > 0) {
      final fill = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -1.5708, 6.2832 * fraction, false, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}
