import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';
import 'discovered_accessory.dart';

NexusGlyph _protocolGlyph(DiscoveredAccessory a) {
  switch (a.protocol) {
    case AccessoryProtocol.wifi:
      return NexusGlyph.wifi;
    case AccessoryProtocol.zigbee:
      return NexusGlyph.zigbee;
    case AccessoryProtocol.zwave:
      return NexusGlyph.zwave;
    case AccessoryProtocol.mesh:
      return NexusGlyph.meshNode;
    case AccessoryProtocol.cloud:
      return NexusGlyph.cloud;
  }
}

/// Add Accessory step 2 (Section 7): discovered devices, streamed in with
/// a staggered fade/slide-in, tap to select. Falls back to manual entry.
class ResultsStep extends StatelessWidget {
  const ResultsStep({
    super.key,
    required this.onSelect,
    required this.onManualEntry,
  });

  final ValueChanged<DiscoveredAccessory> onSelect;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Discovered accessories', style: NexusText.title),
        const SizedBox(height: 4),
        Text('${demoDiscoveredAccessories.length} found nearby', style: NexusText.subhead),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: demoDiscoveredAccessories.length,
            itemBuilder: (context, index) {
              final accessory = demoDiscoveredAccessories[index];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + index * 90),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PressScale(
                    onTap: () => onSelect(accessory),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NexusColors.surface,
                        borderRadius: BorderRadius.circular(NexusRadii.card),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: NexusColors.secondarySurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(child: NexusIcon(_protocolGlyph(accessory), size: 17, color: NexusColors.textSecondary)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(accessory.name, style: NexusText.bodyMedium),
                                const SizedBox(height: 2),
                                Text('${accessory.protocolLabel} · ${accessory.signalLabel} signal', style: NexusText.footnote),
                              ],
                            ),
                          ),
                          Transform.rotate(
                            angle: 3.14159,
                            child: NexusIcon(NexusGlyph.chevronLeft, size: 12, color: NexusColors.textFaint),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: PressScale(
            onTap: onManualEntry,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                "Don't see your device? Add manually",
                style: NexusText.bodyMedium.copyWith(color: NexusColors.blue),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
