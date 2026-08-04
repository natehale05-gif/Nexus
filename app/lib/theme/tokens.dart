import 'package:flutter/widgets.dart';

/// Design tokens for NEXUS - Section 2 of the build prompt.
///
/// Everything else in the app should reference these constants rather than
/// hardcoding colors/curves/durations, so the "iOS system colors + dark
/// tactical map" look stays consistent.
class NexusColors {
  NexusColors._();

  static const background = Color(0xFFF2F2F7);
  static const surface = Color(0xFFFFFFFF);
  static const secondarySurface = Color(0xFFF0F0F5);

  static const blue = Color(0xFF007AFF);
  static const green = Color(0xFF34C759);
  static const amber = Color(0xFFFF9F0A);
  static const red = Color(0xFFFF3B30);
  static const purple = Color(0xFFAF52DE);

  /// Grill/Traeger accent - deliberately distinct from [amber].
  static const grill = Color(0xFFFF6B35);

  static const textPrimary = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF3A3A3C);
  static const textMuted = Color(0xFF636366);
  static const textFaint = Color(0xFF8E8E93);

  /// The map is the one dark/"operational" surface in an otherwise light
  /// app.
  static const mapBase = Color(0xFF1A2035);
  static const mapBaseDeep = Color(0xFF12172A);
  static const mapCyan = Color(0xFF6EE7F7);
  static const mapTeal = Color(0xFF5EEAD4);

  /// Hairline between rows. Light enough to read as a separator rather than
  /// a drawn line - the old 0x33 grey looked like a border on every row.
  static const separator = Color(0x1F3C3C43);

  /// Hairline around raised surfaces, so cards keep an edge on white.
  static const cardBorder = Color(0x14000000);
  static const overlayScrim = Color(0x66000000);
}

/// Elevation. Cards were flat fills, which is the main thing that made the
/// app read as unfinished: with no shadow and no border, a white card on a
/// near-white background has no edge at all.
///
/// Two levels only - resting content and things that float above it - because
/// a longer ramp invites inconsistency without adding meaning.
class NexusShadows {
  NexusShadows._();

  /// Resting cards, list rows, panels.
  static const card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 3)),
  ];

  /// Sheets, dialogs, anything overlapping content.
  static const raised = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1F000000), blurRadius: 32, offset: Offset(0, 12)),
  ];
}

class NexusRadii {
  NexusRadii._();

  static const card = 16.0;
  static const sheet = 20.0;
  static const chip = 12.0;
  static const pill = 100.0;
}

class NexusSpacing {
  NexusSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

class NexusDurations {
  NexusDurations._();

  static const fast = Duration(milliseconds: 160);
  static const sheet = Duration(milliseconds: 340);
  static const expand = Duration(milliseconds: 260);
  static const pulse = Duration(milliseconds: 1600);
}

class NexusCurves {
  NexusCurves._();

  /// `cubic-bezier(.32,.72,0,1)` per spec, used for bottom-sheet slide ups.
  static const sheetUp = Cubic(0.32, 0.72, 0.0, 1.0);
  static const pressScale = Curves.easeOut;
}

/// Layout breakpoint above which the app reflows from a single-column
/// phone layout to a sidebar + detail-pane layout (Section 1, "Platform
/// priority").
class NexusBreakpoints {
  NexusBreakpoints._();

  static const wide = 900.0;
}

/// Tap-target sizing rules (Section 2).
class NexusTapTargets {
  NexusTapTargets._();

  static const minimum = 44.0;

  /// Invisible hit target for anything placed over the map - pins are
  /// visually much smaller than this but must hit-test against it.
  static const mapPin = 64.0;
}
