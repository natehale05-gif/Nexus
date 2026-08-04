import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

import '../theme/tokens.dart';

/// A QR code, painted.
///
/// Pure Dart end to end - `package:qr` does the encoding, this does the
/// drawing. No platform channel, so it renders the same on a desktop window
/// and a phone and can't break a build for a platform some plugin forgot
/// about.
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, this.size = 220});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final QrCode code;
    try {
      // Lowest error correction that still scans reliably in hand: the
      // payload can carry several addresses, and higher correction levels
      // spend their extra modules on redundancy rather than capacity, which
      // makes the code denser and harder for a phone to read.
      code = QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.low,
      );
    } catch (_) {
      // Too much data for any version. Callers show the text code instead.
      return SizedBox(width: size, height: size);
    }
    final image = QrImage(code);

    return Container(
      width: size,
      height: size,
      // The quiet zone is part of the spec, not padding for looks - scanners
      // need the light border to find the code's edges.
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(NexusRadii.chip),
        boxShadow: NexusShadows.card,
      ),
      child: CustomPaint(painter: _QrPainter(image), child: const SizedBox.expand()),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    if (count == 0) return;
    final module = size.shortestSide / count;
    final paint = Paint()
      ..color = NexusColors.textPrimary
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (var y = 0; y < count; y++) {
      for (var x = 0; x < count; x++) {
        if (!image.isDark(y, x)) continue;
        // Ceil the size rather than the position: rounding both ways leaves
        // hairline gaps between modules at fractional scales, and a scanner
        // reads those gaps as light.
        canvas.drawRect(
          Rect.fromLTWH(x * module, y * module, module.ceilToDouble(), module.ceilToDouble()),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.image != image;
}
