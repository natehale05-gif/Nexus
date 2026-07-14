import 'package:flutter/widgets.dart';
import '../../../icons/nexus_icons.dart';
import '../../../theme/text_styles.dart';
import '../../../theme/tokens.dart';

/// Shared header-row layout for every device row type (Section 4): a
/// leading icon/chip, name + one-line summary, a trailing control, and an
/// optional chevron affordance when the row is expandable. The expanded
/// body itself is passed in as [child] (already wrapped in `ExpandSection`
/// by the caller) so this shell stays a dumb layout container.
class DeviceRowShell extends StatelessWidget {
  const DeviceRowShell({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.expanded = false,
    this.expandable = true,
    this.child,
    this.titleBadge,
    this.subtitleColor,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool expanded;
  final bool expandable;
  final Widget? child;
  final Widget? titleBadge;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: expandable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title, style: NexusText.bodyMedium, overflow: TextOverflow.ellipsis),
                          ),
                          if (titleBadge != null) ...[const SizedBox(width: 6), titleBadge!],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: NexusText.footnote.copyWith(color: subtitleColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing,
                if (expandable) ...[
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: NexusDurations.fast,
                    child: NexusIcon(NexusGlyph.chevronDown, size: 13, color: NexusColors.textFaint),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}
