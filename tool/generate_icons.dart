// Generates the NEXUS app icon at every size each platform needs.
//
// The mark is drawn programmatically (no binary asset to keep in the repo,
// and it regenerates identically): a deep navy rounded field - the same
// "tactical map" base the app uses - with a cyan hexagonal mesh ring and a
// glowing center node, echoing `NexusGlyph.meshNode` and the compound-network
// idea the whole app is built around. It stays legible down to 16px because
// it's one bold shape plus a dot.
//
// Run from the repo root:
//   dart run tool/generate_icons.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

// Palette lifted from app/lib/theme/tokens.dart.
const _bgOuter = [0x0B, 0x0F, 0x1E]; // deeper than mapBaseDeep, for contrast
const _bgInner = [0x1A, 0x20, 0x35]; // NexusColors.mapBase
const _cyan = [0x6E, 0xE7, 0xF7]; // NexusColors.mapCyan
const _teal = [0x5E, 0xEA, 0xD4]; // NexusColors.mapTeal

/// Where each platform wants its icons, relative to the repo root.
const _webDir = 'app/web/icons';
const _iosDir = 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _macDir = 'app/macos/Runner/Assets.xcassets/AppIcon.appiconset';
const _androidRes = 'app/android/app/src/main/res';

const _iosSizes = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

const _macSizes = <String, int>{
  'app_icon_16.png': 16,
  'app_icon_32.png': 32,
  'app_icon_64.png': 64,
  'app_icon_128.png': 128,
  'app_icon_256.png': 256,
  'app_icon_512.png': 512,
  'app_icon_1024.png': 1024,
};

/// Android launcher densities (mdpi..xxxhdpi).
const _androidSizes = <String, int>{
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

void main() {
  // Render once, large, then downsample - much cleaner edges than drawing
  // the geometry at 16px directly.
  final master = _renderIcon(1024, rounded: true);
  final square = _renderIcon(1024, rounded: false); // iOS/Android mask it themselves

  for (final entry in _iosSizes.entries) {
    _write('$_iosDir/${entry.key}', square, entry.value);
  }
  for (final entry in _macSizes.entries) {
    _write('$_macDir/${entry.key}', master, entry.value);
  }
  for (final entry in _androidSizes.entries) {
    _write('$_androidRes/${entry.key}/ic_launcher.png', square, entry.value);
  }
  _write('$_webDir/Icon-192.png', master, 192);
  _write('$_webDir/Icon-512.png', master, 512);
  // Maskable variants need the mark well inside the safe zone; the square
  // (full-bleed background) render is exactly that.
  _write('$_webDir/Icon-maskable-192.png', square, 192);
  _write('$_webDir/Icon-maskable-512.png', square, 512);
  _write('app/web/favicon.png', master, 64);

  stdout.writeln('NEXUS icons generated.');
}

void _write(String path, Image source, int size) {
  final resized = copyResize(source, width: size, height: size, interpolation: Interpolation.cubic);
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(encodePng(resized));
  stdout.writeln('  ${size.toString().padLeft(4)}px  $path');
}

Image _renderIcon(int size, {required bool rounded}) {
  final image = Image(width: size, height: size, numChannels: 4);
  final center = size / 2;
  // iOS/Android apply their own mask, so those get square (full-bleed)
  // corners; web/macOS want the rounded "app tile" look baked in.
  final radius = rounded ? size * 0.2237 : 0.0; // Apple's squircle-ish corner

  // Radial background: lighter navy in the middle, near-black at the edges.
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (rounded && !_insideRoundedRect(x + 0.5, y + 0.5, size.toDouble(), radius)) continue;
      final dx = (x + 0.5 - center) / center;
      final dy = (y + 0.5 - center) / center;
      final t = math.min(1.0, math.sqrt(dx * dx + dy * dy) / 1.05);
      final eased = t * t;
      image.setPixelRgba(
        x,
        y,
        _lerp(_bgInner[0], _bgOuter[0], eased),
        _lerp(_bgInner[1], _bgOuter[1], eased),
        _lerp(_bgInner[2], _bgOuter[2], eased),
        255,
      );
    }
  }

  // Hexagonal mesh ring + inner ring, then the glowing core node.
  final outerR = size * 0.30;
  final innerR = size * 0.165;
  _strokeHexagon(image, center, outerR, size * 0.052, _cyan);
  _strokeHexagon(image, center, innerR, size * 0.030, _teal, alpha: 165);

  // Vertices on the outer hexagon read as "nodes" on the network.
  for (var i = 0; i < 6; i++) {
    final angle = -math.pi / 2 + i * math.pi / 3;
    _fillCircle(
      image,
      center + math.cos(angle) * outerR,
      center + math.sin(angle) * outerR,
      size * 0.043,
      _cyan,
    );
  }

  // Core node with a soft glow so it still reads at 16px.
  _fillCircle(image, center, center, size * 0.115, _cyan, alpha: 46);
  _fillCircle(image, center, center, size * 0.082, _cyan);

  return image;
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);

bool _insideRoundedRect(double x, double y, double size, double radius) {
  final left = radius, top = radius, right = size - radius, bottom = size - radius;
  final cx = x < left ? left : (x > right ? right : x);
  final cy = y < top ? top : (y > bottom ? bottom : y);
  if (cx == x || cy == y) return x >= 0 && y >= 0 && x <= size && y <= size;
  final dx = x - cx, dy = y - cy;
  return dx * dx + dy * dy <= radius * radius;
}

/// Anti-aliased hexagon outline, drawn by distance-to-edge testing.
void _strokeHexagon(Image image, double center, double radius, double stroke, List<int> color, {int alpha = 255}) {
  final points = <List<double>>[
    for (var i = 0; i < 6; i++)
      [
        center + math.cos(-math.pi / 2 + i * math.pi / 3) * radius,
        center + math.sin(-math.pi / 2 + i * math.pi / 3) * radius,
      ],
  ];
  for (var i = 0; i < 6; i++) {
    final a = points[i];
    final b = points[(i + 1) % 6];
    _strokeLine(image, a[0], a[1], b[0], b[1], stroke, color, alpha);
  }
}

/// Anti-aliased thick line segment (round caps), blended over the canvas.
void _strokeLine(Image image, double x1, double y1, double x2, double y2, double width, List<int> color, int alpha) {
  final half = width / 2;
  final minX = math.max(0, (math.min(x1, x2) - half - 2).floor());
  final maxX = math.min(image.width - 1, (math.max(x1, x2) + half + 2).ceil());
  final minY = math.max(0, (math.min(y1, y2) - half - 2).floor());
  final maxY = math.min(image.height - 1, (math.max(y1, y2) + half + 2).ceil());
  final dx = x2 - x1, dy = y2 - y1;
  final lenSq = dx * dx + dy * dy;

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final px = x + 0.5, py = y + 0.5;
      var t = lenSq == 0 ? 0.0 : ((px - x1) * dx + (py - y1) * dy) / lenSq;
      t = t.clamp(0.0, 1.0);
      final cx = x1 + t * dx, cy = y1 + t * dy;
      final dist = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
      final coverage = (half - dist + 0.5).clamp(0.0, 1.0);
      if (coverage > 0) _blend(image, x, y, color, (alpha * coverage).round());
    }
  }
}

/// Anti-aliased filled circle, blended over the canvas.
void _fillCircle(Image image, double cx, double cy, double radius, List<int> color, {int alpha = 255}) {
  final minX = math.max(0, (cx - radius - 2).floor());
  final maxX = math.min(image.width - 1, (cx + radius + 2).ceil());
  final minY = math.max(0, (cy - radius - 2).floor());
  final maxY = math.min(image.height - 1, (cy + radius + 2).ceil());
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
      final dist = math.sqrt(dx * dx + dy * dy);
      final coverage = (radius - dist + 0.5).clamp(0.0, 1.0);
      if (coverage > 0) _blend(image, x, y, color, (alpha * coverage).round());
    }
  }
}

void _blend(Image image, int x, int y, List<int> color, int alpha) {
  if (alpha <= 0) return;
  final dst = image.getPixel(x, y);
  final a = alpha / 255.0;
  image.setPixelRgba(
    x,
    y,
    (color[0] * a + dst.r * (1 - a)).round().clamp(0, 255),
    (color[1] * a + dst.g * (1 - a)).round().clamp(0, 255),
    (color[2] * a + dst.b * (1 - a)).round().clamp(0, 255),
    math.max(dst.a.toInt(), alpha),
  );
}
