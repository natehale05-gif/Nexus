import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';

/// The climate arc dial (Section 4) - the most complex control in the app.
///
/// Range 55-85F mapped across a 240deg arc, "clock degrees" 150->390
/// (measuring clockwise from 12 o'clock), leaving a 120deg gap at the top
/// right. Drag math always reads the *actual* rendered [RenderBox.size] at
/// gesture time via `globalToLocal` - never a hardcoded assumed viewBox -
/// per the precision requirement in the spec.
class ArcDial extends StatefulWidget {
  const ArcDial({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.currentTemp,
    required this.color,
    required this.enabled,
    required this.onChanged,
    this.size = 232,
  });

  final double min;
  final double max;
  final double value;
  final double currentTemp;
  final Color color;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final double size;

  static const startClockDeg = 150.0;
  static const sweepDeg = 240.0;

  @override
  State<ArcDial> createState() => _ArcDialState();
}

class _ArcDialState extends State<ArcDial> {
  final _key = GlobalKey();

  double _fractionFor(double value) => ((value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  double _clockDegFor(double fraction) => ArcDial.startClockDeg + fraction * ArcDial.sweepDeg;

  void _handlePan(Offset globalPosition) {
    if (!widget.enabled) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final center = Offset(box.size.width / 2, box.size.height / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    var canvasDeg = math.atan2(dy, dx) * 180 / math.pi;
    if (canvasDeg < 0) canvasDeg += 360;
    var clockDeg = canvasDeg + 90;
    if (clockDeg >= 360) clockDeg -= 360;

    // The dead-zone gap is (sweepEnd, 360)+[0, sweepStart) i.e. roughly the
    // top-right 120deg; clamp to whichever edge of the live arc is nearer.
    final sweepEndDeg = (ArcDial.startClockDeg + ArcDial.sweepDeg) % 360; // 30
    final inGap = clockDeg > sweepEndDeg && clockDeg < ArcDial.startClockDeg;
    double effectiveDeg;
    if (inGap) {
      final distToStart = (clockDeg - ArcDial.startClockDeg).abs();
      final distToEnd = (clockDeg - sweepEndDeg).abs();
      effectiveDeg = distToStart < distToEnd
          ? ArcDial.startClockDeg
          : ArcDial.startClockDeg + ArcDial.sweepDeg;
    } else {
      effectiveDeg = clockDeg < ArcDial.startClockDeg ? clockDeg + 360 : clockDeg;
    }

    final fraction = ((effectiveDeg - ArcDial.startClockDeg) / ArcDial.sweepDeg).clamp(0.0, 1.0);
    final rawValue = widget.min + fraction * (widget.max - widget.min);
    widget.onChanged(rawValue.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final fraction = _fractionFor(widget.value);
    final thumbClockDeg = _clockDegFor(fraction);
    final thumbCanvasRad = (thumbClockDeg - 90) * math.pi / 180;
    final radius = widget.size / 2 - 18;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.4,
      child: GestureDetector(
        onPanDown: (d) => _handlePan(d.globalPosition),
        onPanUpdate: (d) => _handlePan(d.globalPosition),
        child: SizedBox(
          key: _key,
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _ArcDialPainter(fraction: fraction, color: widget.color),
              ),
              Positioned(
                left: widget.size / 2 + math.cos(thumbCanvasRad) * radius - 15,
                top: widget.size / 2 + math.sin(thumbCanvasRad) * radius - 15,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.color, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: widget.size * 0.32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.value.round()}°',
                      style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w700,
                        color: NexusColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcDialPainter extends CustomPainter {
  _ArcDialPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  static double _clockToCanvasRad(double clockDeg) => (clockDeg - 90) * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final startRad = _clockToCanvasRad(ArcDial.startClockDeg);
    final sweepRad = ArcDial.sweepDeg * math.pi / 180;

    final trackPaint = Paint()
      ..color = const Color(0xFFE5E5EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startRad, sweepRad, false, trackPaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startRad, sweepRad * fraction, false, fillPaint);

    final tickPaint = Paint()
      ..color = const Color(0xFFC7C7CC)
      ..strokeWidth = 2;
    const tickCount = 6;
    for (var i = 0; i <= tickCount; i++) {
      final deg = ArcDial.startClockDeg + (ArcDial.sweepDeg / tickCount) * i;
      final rad = _clockToCanvasRad(deg);
      final outer = center + Offset(math.cos(rad), math.sin(rad)) * (radius + 12);
      final inner = center + Offset(math.cos(rad), math.sin(rad)) * (radius + 6);
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcDialPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}
