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

  static final largeTitle = _base.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static final title = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static final headline = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  static final body = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400);

  static final bodyMedium =
      _base.copyWith(fontSize: 15, fontWeight: FontWeight.w500);

  static final subhead = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
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

  static final dialReadout = _base.copyWith(
    fontSize: 46,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
}
