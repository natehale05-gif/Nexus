import 'package:flutter/widgets.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/status_pill.dart';

/// Conventional header (large title + optional status pill) above scrollable
/// content - used by Buildings, Security, Media, NEXUS AI and Settings.
///
/// Navigation used to live here as a pop-up menu; it's a permanent tab bar
/// now, so the header is free to be just a title.
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
            if (pillLabel != null)
              StatusPill(label: pillLabel!, color: pillColor ?? NexusColors.blue),
          ],
        ),
      ),
    );
  }
}
