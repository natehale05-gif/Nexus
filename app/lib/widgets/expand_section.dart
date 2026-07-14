import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';

/// Slide-down expand/collapse wrapper for device rows (Section 3, Room
/// widget: "tap row -> expands the control inline with a slide-down
/// animation; multiple rows can be expanded simultaneously").
class ExpandSection extends StatelessWidget {
  const ExpandSection({super.key, required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: NexusDurations.expand,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: AnimatedOpacity(
          duration: NexusDurations.expand,
          opacity: expanded ? 1 : 0,
          child: expanded ? child : const SizedBox(width: double.infinity),
        ),
      ),
    );
  }
}
