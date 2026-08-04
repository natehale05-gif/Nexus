import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// The app's standard raised surface.
///
/// Exists so elevation is defined once: cards used to be bare
/// `Container(color: surface)` fills, which on a near-white background left
/// them with no edge at all. A shared widget also means a future change to
/// shadow or radius lands everywhere instead of in the fifteen places that
/// each spelled the decoration out.
class NexusCard extends StatelessWidget {
  const NexusCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.raised = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Use for things that float over content (sheets, dialogs).
  final bool raised;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? NexusColors.surface,
        borderRadius: BorderRadius.circular(raised ? NexusRadii.sheet : NexusRadii.card),
        border: Border.all(color: NexusColors.cardBorder, width: 0.5),
        boxShadow: raised ? NexusShadows.raised : NexusShadows.card,
      ),
      child: child,
    );
  }
}
