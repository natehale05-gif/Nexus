import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../../icons/nexus_icons.dart';
import '../../../state/compound_scope.dart';
import '../../../theme/text_styles.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/nexus_switch.dart';

/// Lock/Gate row (Section 4) - a simple binary control, no expansion.
class LockRow extends StatelessWidget {
  const LockRow({super.key, required this.device});

  final LockDevice device;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    final locked = device.locked;
    final color = locked ? NexusColors.green : NexusColors.red;
    final label = device.isGate ? (locked ? 'Closed' : 'Open') : (locked ? 'Locked' : 'Unlocked');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
            child: Center(
              child: NexusIcon(
                device.isGate ? NexusGlyph.gate : (locked ? NexusGlyph.lock : NexusGlyph.lockOpen),
                size: 18,
                color: color,
              ),
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
                Text(label, style: NexusText.footnote.copyWith(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          NexusSwitch(value: locked, onChanged: (v) => store.setLocked(device.id, v)),
        ],
      ),
    );
  }
}
