import 'package:flutter/widgets.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/status_pill.dart';
import '../nav_menu.dart';

/// Conventional header (large title + optional status pill + the section
/// menu) above scrollable content - used by Security, Media, and NEXUS AI.
/// Home has no header; it floats the same menu over the map instead.
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
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
        child: Row(
          children: [
            Expanded(child: Text(title, style: NexusText.largeTitle)),
            if (pillLabel != null) ...[
              StatusPill(label: pillLabel!, color: pillColor ?? NexusColors.blue),
              const SizedBox(width: 10),
            ],
            const NexusMenuButton(),
          ],
        ),
      ),
    );
  }
}
