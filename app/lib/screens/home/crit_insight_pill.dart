import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';

/// Critical-only floating pill, top-center of the map (Section 3). Appears
/// only when an insight is `level: crit` - anything less severe stays out
/// of the map entirely.
class CritInsightPill extends StatelessWidget {
  const CritInsightPill({super.key, required this.insight, required this.onDismiss});

  final Insight insight;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
      decoration: BoxDecoration(
        color: NexusColors.red,
        borderRadius: BorderRadius.circular(NexusRadii.pill),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NexusIcon(NexusGlyph.alertTriangle, size: 15, color: Color(0xFFFFFFFF)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              insight.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NexusText.footnote.copyWith(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: NexusIcon(NexusGlyph.close, size: 12, color: Color(0xFFFFFFFF)),
            ),
          ),
        ],
      ),
    );
  }
}
