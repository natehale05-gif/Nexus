import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/status_pill.dart';
import '../add_accessory/add_accessory_flow.dart';
import '../building/building_content.dart';

/// Zone bottom sheet content (Section 3) - the "quick check" path: shows
/// the zone's buildings, locks/gates first, then each building's rooms as
/// room-widget cards.
class ZoneSheetContent extends StatelessWidget {
  const ZoneSheetContent({super.key, required this.zone});

  final Zone zone;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final compound = store.compound;
        final status = computeZoneStatus(compound, zone.id);
        final label = switch (status.state) {
          ZonePinState.alert => 'Gate open',
          ZonePinState.caution => 'Active',
          ZonePinState.secure => 'Secured',
        };
        final color = switch (status.state) {
          ZonePinState.alert => NexusColors.red,
          ZonePinState.caution => NexusColors.amber,
          ZonePinState.secure => NexusColors.blue,
        };

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(zone.name, style: NexusText.title)),
                  StatusPill(label: label, color: color),
                ],
              ),
              const SizedBox(height: 16),
              for (final buildingId in zone.buildingIds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BuildingContent(
                    buildingId: buildingId,
                    showBuildingLabel: zone.buildingIds.length > 1,
                  ),
                ),
              const SizedBox(height: 4),
              PressScale(
                onTap: () {
                  Navigator.of(context).maybePop();
                  showAddAccessoryFlow(context, defaultBuildingId: zone.resolvedPrimaryBuildingId);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: NexusColors.secondarySurface,
                    borderRadius: BorderRadius.circular(NexusRadii.card),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      NexusIcon(NexusGlyph.plus, size: 14, color: NexusColors.blue),
                      const SizedBox(width: 6),
                      Text('Add Accessory', style: NexusText.bodyMedium.copyWith(color: NexusColors.blue)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
