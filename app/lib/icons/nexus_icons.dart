import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Every glyph used anywhere in NEXUS. Deliberately bespoke, stroke-based
/// icons (Section 2) - no Material/Cupertino icon fonts, no emoji.
enum NexusGlyph {
  bulb,
  thermostat,
  sun,
  snowflake,
  auto,
  power,
  flame,
  lock,
  lockOpen,
  gate,
  tv,
  chevronLeft,
  chevronDown,
  plus,
  minus,
  signal,
  check,
  close,
  alertTriangle,
  camera,
  playFill,
  pauseFill,
  skipBack,
  skipForward,
  send,
  meshNode,
  vehicle,
  battery,
  wind,
  wifi,
  zigbee,
  zwave,
  cloud,
  cloudOff,
  drop,
  info,
  sparkle,
  mapPinBase,
  motion,
}

/// A single bespoke stroke icon rendered with [CustomPainter].
class NexusIcon extends StatelessWidget {
  const NexusIcon(
    this.glyph, {
    super.key,
    this.size = 20,
    this.color = const Color(0xFF1C1C1E),
    this.strokeWidth,
    this.filled = false,
  });

  final NexusGlyph glyph;
  final double size;
  final Color color;
  final double? strokeWidth;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NexusIconPainter(
          glyph: glyph,
          color: color,
          strokeWidth: strokeWidth ?? math.max(1.4, size * 0.09),
          filled: filled,
        ),
      ),
    );
  }
}

class _NexusIconPainter extends CustomPainter {
  _NexusIconPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
    required this.filled,
  });

  final NexusGlyph glyph;
  final Color color;
  final double strokeWidth;
  final bool filled;

  Paint get _stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get _fill => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final rect = Rect.fromLTWH(0, 0, s, s);
    switch (glyph) {
      case NexusGlyph.bulb:
        _paintBulb(canvas, rect);
      case NexusGlyph.thermostat:
        _paintThermostat(canvas, rect);
      case NexusGlyph.sun:
        _paintSun(canvas, rect);
      case NexusGlyph.snowflake:
        _paintSnowflake(canvas, rect);
      case NexusGlyph.auto:
        _paintAuto(canvas, rect);
      case NexusGlyph.power:
        _paintPower(canvas, rect);
      case NexusGlyph.flame:
        _paintFlame(canvas, rect);
      case NexusGlyph.lock:
        _paintLock(canvas, rect, locked: true);
      case NexusGlyph.lockOpen:
        _paintLock(canvas, rect, locked: false);
      case NexusGlyph.gate:
        _paintGate(canvas, rect);
      case NexusGlyph.tv:
        _paintTv(canvas, rect);
      case NexusGlyph.chevronLeft:
        _paintChevron(canvas, rect, math.pi);
      case NexusGlyph.chevronDown:
        _paintChevron(canvas, rect, math.pi / 2);
      case NexusGlyph.plus:
        _paintPlus(canvas, rect);
      case NexusGlyph.minus:
        _paintMinus(canvas, rect);
      case NexusGlyph.signal:
        _paintSignal(canvas, rect);
      case NexusGlyph.check:
        _paintCheck(canvas, rect);
      case NexusGlyph.close:
        _paintClose(canvas, rect);
      case NexusGlyph.alertTriangle:
        _paintAlertTriangle(canvas, rect);
      case NexusGlyph.camera:
        _paintCamera(canvas, rect);
      case NexusGlyph.playFill:
        _paintPlay(canvas, rect);
      case NexusGlyph.pauseFill:
        _paintPause(canvas, rect);
      case NexusGlyph.skipBack:
        _paintSkip(canvas, rect, back: true);
      case NexusGlyph.skipForward:
        _paintSkip(canvas, rect, back: false);
      case NexusGlyph.send:
        _paintSend(canvas, rect);
      case NexusGlyph.meshNode:
        _paintMeshNode(canvas, rect);
      case NexusGlyph.vehicle:
        _paintVehicle(canvas, rect);
      case NexusGlyph.battery:
        _paintBattery(canvas, rect);
      case NexusGlyph.wind:
        _paintWind(canvas, rect);
      case NexusGlyph.wifi:
        _paintWifi(canvas, rect);
      case NexusGlyph.zigbee:
        _paintZigbee(canvas, rect);
      case NexusGlyph.zwave:
        _paintZwave(canvas, rect);
      case NexusGlyph.cloud:
        _paintCloud(canvas, rect, slash: false);
      case NexusGlyph.cloudOff:
        _paintCloud(canvas, rect, slash: true);
      case NexusGlyph.drop:
        _paintDrop(canvas, rect);
      case NexusGlyph.info:
        _paintInfo(canvas, rect);
      case NexusGlyph.sparkle:
        _paintSparkle(canvas, rect);
      case NexusGlyph.mapPinBase:
        _paintMapPinBase(canvas, rect);
      case NexusGlyph.motion:
        _paintMotion(canvas, rect);
    }
    canvas.restore();
  }

  void _paintBulb(Canvas canvas, Rect r) {
    final c = r.center;
    final radius = r.width * 0.32;
    canvas.drawCircle(Offset(c.dx, r.top + radius + r.height * 0.06), radius, _stroke);
    final baseTop = r.top + radius * 2 + r.height * 0.02;
    final path = Path()
      ..moveTo(c.dx - radius * 0.55, baseTop)
      ..lineTo(c.dx + radius * 0.55, baseTop)
      ..lineTo(c.dx + radius * 0.4, r.bottom - r.height * 0.08)
      ..lineTo(c.dx - radius * 0.4, r.bottom - r.height * 0.08)
      ..close();
    canvas.drawPath(path, _stroke);
    canvas.drawLine(
      Offset(c.dx - radius * 0.28, r.bottom - r.height * 0.02),
      Offset(c.dx + radius * 0.28, r.bottom - r.height * 0.02),
      _stroke,
    );
  }

  void _paintThermostat(Canvas canvas, Rect r) {
    canvas.drawCircle(r.center, r.width * 0.42, _stroke);
    canvas.drawCircle(r.center, r.width * 0.12, _fill);
    final start = -math.pi * 0.7;
    canvas.drawArc(r.deflate(r.width * 0.08), start, math.pi * 1.1, false, _stroke);
  }

  void _paintSun(Canvas canvas, Rect r) {
    canvas.drawCircle(r.center, r.width * 0.24, _stroke);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final inner = Offset(r.center.dx + math.cos(angle) * r.width * 0.36,
          r.center.dy + math.sin(angle) * r.width * 0.36);
      final outer = Offset(r.center.dx + math.cos(angle) * r.width * 0.48,
          r.center.dy + math.sin(angle) * r.width * 0.48);
      canvas.drawLine(inner, outer, _stroke);
    }
  }

  void _paintSnowflake(Canvas canvas, Rect r) {
    for (var i = 0; i < 3; i++) {
      final angle = i * math.pi / 3;
      final a = Offset(r.center.dx + math.cos(angle) * r.width * 0.42,
          r.center.dy + math.sin(angle) * r.width * 0.42);
      final b = Offset(r.center.dx - math.cos(angle) * r.width * 0.42,
          r.center.dy - math.sin(angle) * r.width * 0.42);
      canvas.drawLine(a, b, _stroke);
    }
  }

  void _paintAuto(Canvas canvas, Rect r) {
    canvas.drawCircle(r.center, r.width * 0.42, _stroke);
    final path = Path()
      ..moveTo(r.center.dx - r.width * 0.18, r.center.dy + r.height * 0.14)
      ..lineTo(r.center.dx, r.center.dy - r.height * 0.2)
      ..lineTo(r.center.dx + r.width * 0.18, r.center.dy + r.height * 0.14);
    canvas.drawPath(path, _stroke);
    canvas.drawLine(
      Offset(r.center.dx - r.width * 0.09, r.center.dy + r.height * 0.02),
      Offset(r.center.dx + r.width * 0.09, r.center.dy + r.height * 0.02),
      _stroke,
    );
  }

  void _paintPower(Canvas canvas, Rect r) {
    canvas.drawArc(
        r.deflate(r.width * 0.14), -math.pi * 0.65, math.pi * 1.3, false, _stroke);
    canvas.drawLine(Offset(r.center.dx, r.top + r.height * 0.14),
        Offset(r.center.dx, r.center.dy), _stroke);
  }

  void _paintFlame(Canvas canvas, Rect r) {
    final path = Path()
      ..moveTo(r.center.dx, r.top + r.height * 0.04)
      ..cubicTo(r.right * 0.95, r.height * 0.42, r.center.dx + r.width * 0.22,
          r.height * 0.5, r.center.dx + r.width * 0.14, r.bottom - r.height * 0.18)
      ..cubicTo(r.center.dx + r.width * 0.3, r.bottom - r.height * 0.05,
          r.center.dx - r.width * 0.3, r.bottom - r.height * 0.05,
          r.center.dx - r.width * 0.14, r.bottom - r.height * 0.18)
      ..cubicTo(r.center.dx - r.width * 0.22, r.height * 0.5, r.left * 1.05 + r.width * 0.05,
          r.height * 0.42, r.center.dx, r.top + r.height * 0.04)
      ..close();
    canvas.drawPath(path, filled ? _fill : _stroke);
    canvas.drawCircle(Offset(r.center.dx, r.bottom - r.height * 0.28), r.width * 0.08,
        filled ? (Paint()..color = const Color(0xFFFFFFFF)) : _stroke);
  }

  void _paintLock(Canvas canvas, Rect r, {required bool locked}) {
    final bodyTop = r.top + r.height * 0.42;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(r.left + r.width * 0.18, bodyTop, r.right - r.width * 0.18, r.bottom - r.height * 0.06),
      Radius.circular(r.width * 0.08),
    );
    canvas.drawRRect(body, _stroke);
    canvas.drawCircle(Offset(r.center.dx, bodyTop + r.height * 0.2), r.width * 0.05, _fill);
    final shackleRadius = r.width * 0.22;
    if (locked) {
      final path = Path()
        ..moveTo(r.center.dx - shackleRadius, bodyTop)
        ..lineTo(r.center.dx - shackleRadius, r.top + r.height * 0.28)
        ..arcToPoint(Offset(r.center.dx + shackleRadius, r.top + r.height * 0.28),
            radius: Radius.circular(shackleRadius), clockwise: true)
        ..lineTo(r.center.dx + shackleRadius, bodyTop);
      canvas.drawPath(path, _stroke);
    } else {
      final path = Path()
        ..moveTo(r.center.dx - shackleRadius, bodyTop)
        ..lineTo(r.center.dx - shackleRadius, r.top + r.height * 0.2)
        ..arcToPoint(Offset(r.center.dx + shackleRadius, r.top + r.height * 0.2),
            radius: Radius.circular(shackleRadius), clockwise: true)
        ..lineTo(r.center.dx + shackleRadius, bodyTop + r.height * 0.1);
      canvas.drawPath(path, _stroke);
    }
  }

  void _paintGate(Canvas canvas, Rect r) {
    canvas.drawLine(Offset(r.left + r.width * 0.1, r.top), Offset(r.left + r.width * 0.1, r.bottom), _stroke);
    canvas.drawLine(Offset(r.right - r.width * 0.1, r.top), Offset(r.right - r.width * 0.1, r.bottom), _stroke);
    for (var i = 0; i < 3; i++) {
      final y = r.top + r.height * (0.22 + i * 0.28);
      canvas.drawLine(Offset(r.left + r.width * 0.1, y), Offset(r.right - r.width * 0.1, y), _stroke);
    }
  }

  void _paintTv(Canvas canvas, Rect r) {
    final screen = RRect.fromRectAndRadius(
      Rect.fromLTRB(r.left, r.top + r.height * 0.06, r.right, r.bottom - r.height * 0.28),
      Radius.circular(r.width * 0.08),
    );
    canvas.drawRRect(screen, _stroke);
    canvas.drawLine(Offset(r.center.dx - r.width * 0.18, r.bottom - r.height * 0.06),
        Offset(r.center.dx + r.width * 0.18, r.bottom - r.height * 0.06), _stroke);
    final playPath = Path()
      ..moveTo(r.center.dx - r.width * 0.08, r.center.dy - r.height * 0.14)
      ..lineTo(r.center.dx - r.width * 0.08, r.center.dy + r.height * 0.06)
      ..lineTo(r.center.dx + r.width * 0.1, r.center.dy - r.height * 0.04)
      ..close();
    canvas.drawPath(playPath, _fill);
  }

  void _paintChevron(Canvas canvas, Rect r, double rotation) {
    canvas.save();
    canvas.translate(r.center.dx, r.center.dy);
    canvas.rotate(rotation == math.pi ? 0 : rotation - math.pi / 2);
    final path = Path()
      ..moveTo(r.width * 0.14, -r.height * 0.24)
      ..lineTo(-r.width * 0.14, 0)
      ..lineTo(r.width * 0.14, r.height * 0.24);
    canvas.drawPath(path, _stroke);
    canvas.restore();
  }

  void _paintPlus(Canvas canvas, Rect r) {
    canvas.drawLine(Offset(r.center.dx, r.top + r.height * 0.14),
        Offset(r.center.dx, r.bottom - r.height * 0.14), _stroke);
    canvas.drawLine(Offset(r.left + r.width * 0.14, r.center.dy),
        Offset(r.right - r.width * 0.14, r.center.dy), _stroke);
  }

  void _paintMinus(Canvas canvas, Rect r) {
    canvas.drawLine(Offset(r.left + r.width * 0.14, r.center.dy),
        Offset(r.right - r.width * 0.14, r.center.dy), _stroke);
  }

  void _paintSignal(Canvas canvas, Rect r) {
    for (var i = 0; i < 3; i++) {
      final radius = r.width * (0.16 + i * 0.14);
      canvas.drawArc(Rect.fromCircle(center: r.center, radius: radius),
          -math.pi * 0.75, math.pi * 0.5, false, _stroke);
    }
    canvas.drawCircle(r.center, r.width * 0.06, _fill);
  }

  void _paintCheck(Canvas canvas, Rect r) {
    final path = Path()
      ..moveTo(r.left + r.width * 0.18, r.center.dy)
      ..lineTo(r.center.dx - r.width * 0.04, r.bottom - r.height * 0.22)
      ..lineTo(r.right - r.width * 0.16, r.top + r.height * 0.24);
    canvas.drawPath(path, _stroke);
  }

  void _paintClose(Canvas canvas, Rect r) {
    canvas.drawLine(Offset(r.left + r.width * 0.22, r.top + r.height * 0.22),
        Offset(r.right - r.width * 0.22, r.bottom - r.height * 0.22), _stroke);
    canvas.drawLine(Offset(r.right - r.width * 0.22, r.top + r.height * 0.22),
        Offset(r.left + r.width * 0.22, r.bottom - r.height * 0.22), _stroke);
  }

  void _paintAlertTriangle(Canvas canvas, Rect r) {
    final path = Path()
      ..moveTo(r.center.dx, r.top + r.height * 0.08)
      ..lineTo(r.right - r.width * 0.08, r.bottom - r.height * 0.1)
      ..lineTo(r.left + r.width * 0.08, r.bottom - r.height * 0.1)
      ..close();
    canvas.drawPath(path, _stroke);
    canvas.drawLine(Offset(r.center.dx, r.top + r.height * 0.36),
        Offset(r.center.dx, r.bottom - r.height * 0.36), _stroke);
    canvas.drawCircle(Offset(r.center.dx, r.bottom - r.height * 0.22), r.width * 0.03, _fill);
  }

  void _paintCamera(Canvas canvas, Rect r) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(r.left, r.top + r.height * 0.2, r.right, r.bottom - r.height * 0.06),
      Radius.circular(r.width * 0.1),
    );
    canvas.drawRRect(body, _stroke);
    canvas.drawPath(
      Path()
        ..moveTo(r.center.dx - r.width * 0.12, r.top + r.height * 0.2)
        ..lineTo(r.center.dx - r.width * 0.05, r.top + r.height * 0.06)
        ..lineTo(r.center.dx + r.width * 0.05, r.top + r.height * 0.06)
        ..lineTo(r.center.dx + r.width * 0.12, r.top + r.height * 0.2),
      _stroke,
    );
    canvas.drawCircle(r.center + Offset(0, r.height * 0.08), r.width * 0.16, _stroke);
  }

  void _paintPlay(Canvas canvas, Rect r) {
    final path = Path()
      ..moveTo(r.left + r.width * 0.24, r.top + r.height * 0.14)
      ..lineTo(r.right - r.width * 0.2, r.center.dy)
      ..lineTo(r.left + r.width * 0.24, r.bottom - r.height * 0.14)
      ..close();
    canvas.drawPath(path, _fill);
  }

  void _paintPause(Canvas canvas, Rect r) {
    final barWidth = r.width * 0.18;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left + r.width * 0.22, r.top + r.height * 0.14, barWidth, r.height * 0.72),
            Radius.circular(2)),
        _fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(r.right - r.width * 0.22 - barWidth, r.top + r.height * 0.14, barWidth,
                r.height * 0.72),
            Radius.circular(2)),
        _fill);
  }

  void _paintSkip(Canvas canvas, Rect r, {required bool back}) {
    canvas.save();
    if (back) {
      canvas.translate(r.width, 0);
      canvas.scale(-1, 1);
    }
    final path = Path()
      ..moveTo(r.left + r.width * 0.2, r.top + r.height * 0.16)
      ..lineTo(r.center.dx, r.center.dy)
      ..lineTo(r.left + r.width * 0.2, r.bottom - r.height * 0.16)
      ..close();
    canvas.drawPath(path, _fill);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(r.right - r.width * 0.26, r.top + r.height * 0.16, r.width * 0.1, r.height * 0.68),
            Radius.circular(1.5)),
        _fill);
    canvas.restore();
  }

  void _paintSend(Canvas canvas, Rect r) {
    final path = Path()
      ..moveTo(r.left + r.width * 0.1, r.top + r.height * 0.16)
      ..lineTo(r.right - r.width * 0.08, r.center.dy)
      ..lineTo(r.left + r.width * 0.1, r.bottom - r.height * 0.16)
      ..lineTo(r.left + r.width * 0.28, r.center.dy)
      ..close();
    canvas.drawPath(path, _fill);
  }

  void _paintMeshNode(Canvas canvas, Rect r) {
    canvas.drawCircle(r.center, r.width * 0.1, _fill);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(r.center, r.width * (0.2 + i * 0.12), _stroke);
    }
  }

  void _paintVehicle(Canvas canvas, Rect r) {
    final body = Path()
      ..moveTo(r.left + r.width * 0.08, r.bottom - r.height * 0.3)
      ..lineTo(r.left + r.width * 0.2, r.top + r.height * 0.36)
      ..lineTo(r.right - r.width * 0.2, r.top + r.height * 0.36)
      ..lineTo(r.right - r.width * 0.08, r.bottom - r.height * 0.3)
      ..lineTo(r.left + r.width * 0.08, r.bottom - r.height * 0.3);
    canvas.drawPath(body, _stroke);
    canvas.drawLine(Offset(r.left + r.width * 0.08, r.bottom - r.height * 0.3),
        Offset(r.right - r.width * 0.08, r.bottom - r.height * 0.3), _stroke);
    canvas.drawCircle(Offset(r.left + r.width * 0.28, r.bottom - r.height * 0.22), r.width * 0.1, _stroke);
    canvas.drawCircle(Offset(r.right - r.width * 0.28, r.bottom - r.height * 0.22), r.width * 0.1, _stroke);
  }

  void _paintBattery(Canvas canvas, Rect r) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTRB(r.left, r.top + r.height * 0.24, r.right - r.width * 0.12, r.bottom - r.height * 0.24),
        Radius.circular(r.width * 0.08));
    canvas.drawRRect(body, _stroke);
    canvas.drawRect(
        Rect.fromLTWH(r.right - r.width * 0.12, r.center.dy - r.height * 0.08, r.width * 0.08, r.height * 0.16),
        _fill);
  }

  void _paintWind(Canvas canvas, Rect r) {
    canvas.drawPath(
      Path()
        ..moveTo(r.left + r.width * 0.1, r.top + r.height * 0.3)
        ..lineTo(r.right - r.width * 0.3, r.top + r.height * 0.3)
        ..cubicTo(r.right, r.top + r.height * 0.3, r.right, r.top + r.height * 0.05,
            r.right - r.width * 0.2, r.top + r.height * 0.14),
      _stroke,
    );
    canvas.drawLine(Offset(r.left + r.width * 0.1, r.center.dy),
        Offset(r.right - r.width * 0.14, r.center.dy), _stroke);
    canvas.drawPath(
      Path()
        ..moveTo(r.left + r.width * 0.1, r.bottom - r.height * 0.3)
        ..lineTo(r.right - r.width * 0.42, r.bottom - r.height * 0.3)
        ..cubicTo(r.right - r.width * 0.1, r.bottom - r.height * 0.3, r.right - r.width * 0.1,
            r.bottom - r.height * 0.06, r.right - r.width * 0.3, r.bottom - r.height * 0.1),
      _stroke,
    );
  }

  void _paintWifi(Canvas canvas, Rect r) {
    for (var i = 0; i < 3; i++) {
      final radius = r.width * (0.14 + i * 0.15);
      canvas.drawArc(Rect.fromCircle(center: Offset(r.center.dx, r.bottom - r.height * 0.14), radius: radius),
          -math.pi * 0.78, math.pi * 0.56, false, _stroke);
    }
    canvas.drawCircle(Offset(r.center.dx, r.bottom - r.height * 0.14), r.width * 0.045, _fill);
  }

  void _paintZigbee(Canvas canvas, Rect r) {
    final pts = <Offset>[
      Offset(r.center.dx, r.top + r.height * 0.06),
      Offset(r.left + r.width * 0.14, r.center.dy),
      Offset(r.center.dx, r.bottom - r.height * 0.06),
      Offset(r.right - r.width * 0.14, r.center.dy),
    ];
    canvas.drawPath(Path()..addPolygon(pts, true), _stroke);
    canvas.drawCircle(r.center, r.width * 0.07, _fill);
  }

  void _paintZwave(Canvas canvas, Rect r) {
    for (var i = 0; i < 3; i++) {
      final radius = r.width * (0.14 + i * 0.15);
      canvas.drawArc(Rect.fromCircle(center: r.center, radius: radius), -math.pi * 0.35, math.pi * 0.7,
          false, _stroke);
      canvas.drawArc(Rect.fromCircle(center: r.center, radius: radius), math.pi * 0.65, math.pi * 0.7,
          false, _stroke);
    }
  }

  void _paintCloud(Canvas canvas, Rect r, {required bool slash}) {
    final path = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(r.center.dx - r.width * 0.16, r.center.dy + r.height * 0.06), radius: r.width * 0.18))
      ..addOval(Rect.fromCircle(
          center: Offset(r.center.dx + r.width * 0.1, r.center.dy - r.height * 0.02), radius: r.width * 0.22))
      ..addOval(Rect.fromCircle(
          center: Offset(r.center.dx + r.width * 0.3, r.center.dy + r.height * 0.1), radius: r.width * 0.14));
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(r.left, r.top, r.right, r.bottom + r.height * 0.2));
    canvas.drawPath(path, _stroke);
    canvas.restore();
    if (slash) {
      canvas.drawLine(Offset(r.left + r.width * 0.1, r.top + r.height * 0.1),
          Offset(r.right - r.width * 0.1, r.bottom - r.height * 0.1), _stroke);
    }
  }

  void _paintDrop(Canvas canvas, Rect r) {
    final path = Path()
      ..moveTo(r.center.dx, r.top + r.height * 0.08)
      ..cubicTo(r.right - r.width * 0.04, r.center.dy - r.height * 0.05, r.right - r.width * 0.1,
          r.bottom - r.height * 0.1, r.center.dx, r.bottom - r.height * 0.08)
      ..cubicTo(r.left + r.width * 0.1, r.bottom - r.height * 0.1, r.left + r.width * 0.04,
          r.center.dy - r.height * 0.05, r.center.dx, r.top + r.height * 0.08)
      ..close();
    canvas.drawPath(path, _stroke);
  }

  void _paintInfo(Canvas canvas, Rect r) {
    canvas.drawCircle(r.center, r.width * 0.42, _stroke);
    canvas.drawCircle(Offset(r.center.dx, r.top + r.height * 0.3), r.width * 0.04, _fill);
    canvas.drawLine(Offset(r.center.dx, r.center.dy - r.height * 0.02),
        Offset(r.center.dx, r.bottom - r.height * 0.28), _stroke);
  }

  void _paintSparkle(Canvas canvas, Rect r) {
    final path = Path()
      ..moveTo(r.center.dx, r.top)
      ..cubicTo(r.center.dx, r.center.dy - r.height * 0.1, r.center.dx + r.width * 0.1, r.center.dy,
          r.right, r.center.dy)
      ..cubicTo(r.center.dx + r.width * 0.1, r.center.dy, r.center.dx, r.center.dy + r.height * 0.1,
          r.center.dx, r.bottom)
      ..cubicTo(r.center.dx, r.center.dy + r.height * 0.1, r.center.dx - r.width * 0.1, r.center.dy,
          r.left, r.center.dy)
      ..cubicTo(r.center.dx - r.width * 0.1, r.center.dy, r.center.dx, r.center.dy - r.height * 0.1,
          r.center.dx, r.top)
      ..close();
    canvas.drawPath(path, _fill);
  }

  void _paintMapPinBase(Canvas canvas, Rect r) {
    canvas.drawCircle(r.center, r.width * 0.42, _fill);
  }

  void _paintMotion(Canvas canvas, Rect r) {
    for (var i = 0; i < 3; i++) {
      final dx = r.width * (0.16 + i * 0.22);
      canvas.drawLine(Offset(r.left + dx, r.top + r.height * 0.2),
          Offset(r.left + dx - r.width * 0.14, r.bottom - r.height * 0.2), _stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _NexusIconPainter oldDelegate) {
    return oldDelegate.glyph != glyph ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.filled != filled;
  }
}
