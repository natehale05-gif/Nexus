import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../../icons/nexus_icons.dart';
import '../../../state/compound_scope.dart';
import '../../../theme/text_styles.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/nexus_switch.dart';

/// Media device row (Section 4) - on/off only in the Room widget context;
/// the Media tab has the full transport controls.
class MediaRow extends StatelessWidget {
  const MediaRow({super.key, required this.device});

  final MediaDevice device;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: device.on ? NexusColors.purple.withValues(alpha: 0.14) : NexusColors.secondarySurface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: NexusIcon(NexusGlyph.tv, size: 18, color: device.on ? NexusColors.purple : NexusColors.textFaint),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(device.name, style: NexusText.bodyMedium),
                const SizedBox(height: 2),
                Text(device.on ? 'On' : 'Off', style: NexusText.footnote),
              ],
            ),
          ),
          NexusSwitch(value: device.on, onChanged: (v) => store.setMediaOn(device.id, v)),
        ],
      ),
    );
  }
}
