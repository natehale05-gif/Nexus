import 'package:flutter/widgets.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'press_scale.dart';

/// Button styles, so a primary action looks the same everywhere.
enum NexusButtonStyle {
  /// Filled blue. One per screen - the thing you're most likely to want.
  primary,

  /// Tinted. Secondary actions that are still additive.
  tinted,

  /// Plain grey. Cancel, dismiss, neutral.
  plain,

  /// Tinted red. Delete and disconnect.
  destructive,
}

/// The app's standard button.
///
/// The same filled-blue-container-with-centered-text was spelled out by hand
/// in a dozen places, each with slightly different padding, radius and
/// disabled behaviour. Centralising it also gives every button one honest
/// disabled state instead of an onTap that silently does nothing.
class NexusButton extends StatelessWidget {
  const NexusButton({
    super.key,
    required this.label,
    required this.onTap,
    this.style = NexusButtonStyle.primary,
    this.compact = false,
    this.expand = true,
  });

  final String label;

  /// Null renders the button visibly disabled, rather than live-looking but
  /// inert.
  final VoidCallback? onTap;

  final NexusButtonStyle style;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    // Disabled is its own colour rather than a faded version of the enabled
    // one: a 40%-opacity blue button still reads as a blue button, just a
    // paler one, so people tap it and nothing happens.
    final (background, foreground) = !enabled
        ? (NexusColors.secondarySurface, NexusColors.textFaint)
        : switch (style) {
            NexusButtonStyle.primary => (NexusColors.blue, const Color(0xFFFFFFFF)),
            NexusButtonStyle.tinted => (
                NexusColors.blue.withValues(alpha: 0.12),
                NexusColors.blue,
              ),
            NexusButtonStyle.plain => (NexusColors.secondarySurface, NexusColors.textPrimary),
            NexusButtonStyle.destructive => (
                NexusColors.red.withValues(alpha: 0.12),
                NexusColors.red,
              ),
          };

    return Opacity(
      opacity: enabled ? 1 : 0.85,
      child: PressScale(
        onTap: onTap ?? () {},
        child: Container(
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 9 : 14,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(compact ? NexusRadii.pill : 14),
            // Only the filled button lifts; tinted ones sit in the surface.
            boxShadow: style == NexusButtonStyle.primary && enabled
                ? NexusShadows.card
                : null,
          ),
          child: Center(
            widthFactor: expand ? null : 1,
            child: Text(
              label,
              style: (compact ? NexusText.bodyMedium : NexusText.headline)
                  .copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
