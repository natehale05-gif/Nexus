import 'package:flutter/widgets.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Small colored status pill used in tab headers and building-view headers
/// (Section 3/5) - e.g. "Locked", "Gate open", "3 on", "All off".
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(NexusRadii.pill),
      ),
      child: Text(
        label,
        style: NexusText.footnote.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: dense ? 11 : 12,
        ),
      ),
    );
  }
}
