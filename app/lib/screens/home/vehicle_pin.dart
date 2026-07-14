import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';

/// Vehicle pin on the Home map - separate from zones, no controls, just a
/// status card overlay when tapped (Section 3).
class VehiclePin extends StatelessWidget {
  const VehiclePin({super.key, required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: NexusTapTargets.mapPin,
        height: NexusTapTargets.mapPin,
        child: Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NexusColors.mapBaseDeep.withValues(alpha: 0.9),
              border: Border.all(color: NexusColors.mapTeal.withValues(alpha: 0.6), width: 1.4),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Center(child: NexusIcon(NexusGlyph.vehicle, size: 16, color: NexusColors.mapTeal)),
          ),
        ),
      ),
    );
  }
}

/// Floating card that overlays near the top of the map when a vehicle pin
/// is tapped: name, parked/moving, location description, battery %.
class VehicleStatusCard extends StatelessWidget {
  const VehicleStatusCard({super.key, required this.vehicle, required this.onClose});

  final Vehicle vehicle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: NexusColors.surface,
        borderRadius: BorderRadius.circular(NexusRadii.card),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NexusColors.secondarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: NexusIcon(NexusGlyph.vehicle, size: 20, color: NexusColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(vehicle.name, style: NexusText.headline),
                const SizedBox(height: 2),
                Text(
                  '${vehicle.status == VehicleStatus.parked ? "Parked" : "Moving"} · ${vehicle.locationDescription.replaceFirst(RegExp('^(Parked|Moving)\\s*·\\s*'), '')}',
                  style: NexusText.footnote,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NexusIcon(NexusGlyph.battery, size: 14, color: NexusColors.textMuted),
                  const SizedBox(width: 3),
                  Text('${vehicle.batteryPercent}%', style: NexusText.footnote),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onClose,
                child: NexusIcon(NexusGlyph.close, size: 14, color: NexusColors.textFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
