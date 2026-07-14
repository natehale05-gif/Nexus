import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../../theme/tokens.dart';

/// Home tab's full-bleed dark "tactical" map background (Section 3):
/// topographic contour rings, a creek line, a dashed access road, a dashed
/// property-boundary rectangle, sparse tree-cluster dots, and a soft
/// radial vignette - all at very low opacity so they read as texture, not
/// clutter.
class MapBackgroundPainter extends CustomPainter {
  const MapBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [NexusColors.mapBase, NexusColors.mapBaseDeep],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    _paintContours(canvas, size);
    _paintCreek(canvas, size);
    _paintAccessRoad(canvas, size);
    _paintPropertyBoundary(canvas, size);
    _paintTreeClusters(canvas, size);
    _paintVignette(canvas, size);
  }

  void _paintContours(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NexusColors.mapCyan.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final centers = [
      Offset(size.width * 0.28, size.height * 0.28),
      Offset(size.width * 0.72, size.height * 0.26),
      Offset(size.width * 0.20, size.height * 0.7),
    ];
    for (final center in centers) {
      for (var i = 1; i <= 3; i++) {
        canvas.drawOval(
          Rect.fromCenter(center: center, width: 70.0 * i, height: 46.0 * i),
          paint,
        );
      }
    }
  }

  void _paintCreek(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NexusColors.mapTeal.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.1)
      ..cubicTo(
        size.width * 0.25, size.height * 0.22,
        size.width * 0.15, size.height * 0.42,
        size.width * 0.34, size.height * 0.55,
      )
      ..cubicTo(
        size.width * 0.5, size.height * 0.66,
        size.width * 0.42, size.height * 0.82,
        size.width * 0.6, size.height * 0.95,
      );
    canvas.drawPath(path, paint);
  }

  void _paintAccessRoad(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NexusColors.mapCyan.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 1.02)
      ..lineTo(size.width * 0.54, size.height * 0.7)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.4, size.height * 0.3);
    _drawDashedPath(canvas, path, paint, dashLength: 8, gapLength: 6);
  }

  void _paintPropertyBoundary(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NexusColors.mapTeal.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rect = Rect.fromLTWH(size.width * 0.06, size.height * 0.08, size.width * 0.88, size.height * 0.86);
    _drawDashedPath(canvas, Path()..addRect(rect), paint, dashLength: 6, gapLength: 5);
  }

  void _paintTreeClusters(Canvas canvas, Size size) {
    final paint = Paint()..color = NexusColors.mapTeal.withValues(alpha: 0.1);
    final rand = math.Random(7);
    for (var i = 0; i < 46; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 1.6, paint);
    }
  }

  void _paintVignette(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [const Color(0x00000000), NexusColors.mapBaseDeep.withValues(alpha: 0.65)],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {required double dashLength, required double gapLength}) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
