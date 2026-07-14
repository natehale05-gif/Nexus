import 'package:flutter/widgets.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/status_pill.dart';

/// Conventional header (title + status pill) above scrollable content -
/// used by Security, Media, and NEXUS AI, unlike Home which has no header
/// chrome (Section 3).
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.pillLabel, this.pillColor});

  final String title;
  final String? pillLabel;
  final Color? pillColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(
          children: [
            Expanded(child: Text(title, style: NexusText.largeTitle)),
            if (pillLabel != null) StatusPill(label: pillLabel!, color: pillColor ?? NexusColors.blue),
          ],
        ),
      ),
    );
  }
}
