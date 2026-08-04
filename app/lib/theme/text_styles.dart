import 'package:flutter/widgets.dart';
import 'tokens.dart';

/// SF Pro / system font stack (Section 2). `.notoSans`/`system-ui`-style
/// fallback so this also reads correctly on Linux/web dev builds where SF
/// Pro isn't installed.
const _fontFamilyFallback = [
  '.SF Pro Text',
  'SF Pro Text',
  'Roboto',
  'system-ui',
];

class NexusText {
  NexusText._();

  static const _base = TextStyle(
    fontFamilyFallback: _fontFamilyFallback,
    color: NexusColors.textPrimary,
    decoration: TextDecoration.none,
  );

  // Letter-spacing values below follow Apple's San Francisco optical tracking
  // (tight negative tracking on body/headline sizes, a hair of positive on the
  // large display title) so the app reads like a native Apple product.
  static final largeTitle = _base.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
  );

  static final title = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
  );

  static final headline = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  static final body = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
  );

  static final bodyMedium = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );

  static final subhead = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.15,
    color: NexusColors.textSecondary,
  );

  static final footnote = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: NexusColors.textMuted,
  );

  static final caption = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: NexusColors.textFaint,
    letterSpacing: 0.4,
  );

  /// Group label above a card, iOS-style: small, uppercase, tracked, muted.
  /// Previously these were plain footnotes, so a section title looked
  /// identical to the helper text underneath it.
  static final sectionHeader = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: NexusColors.textFaint,
  );

  static final dialReadout = _base.copyWith(
    fontSize: 46,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
}
