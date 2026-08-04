import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../state/compound_scope.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import 'device_rows/lock_row.dart';
import 'room_widget.dart';

/// Locks & Gates section (if any) as a card list with toggles, followed by
/// Rooms as a vertical stack of room-widget cards (Section 3, Building
/// view). Shared between the full-screen Building view and the zone
/// bottom sheet.
class BuildingContent extends StatelessWidget {
  const BuildingContent({super.key, required this.buildingId, this.showBuildingLabel = false});

  final String buildingId;
  final bool showBuildingLabel;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    final compound = store.compound;
    final building = compound.buildingById(buildingId);
    final locks = compound.devicesOfBuilding(buildingId).whereType<LockDevice>().toList();
    final rooms = compound.roomsOfBuilding(buildingId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBuildingLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(building.name, style: NexusText.headline),
          ),
        if (locks.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: NexusColors.surface,
              borderRadius: BorderRadius.circular(NexusRadii.card),
              border: Border.all(color: NexusColors.cardBorder, width: 0.5),
              boxShadow: NexusShadows.card,
            ),
            child: Column(
              children: [
                for (var i = 0; i < locks.length; i++) ...[
                  if (i > 0) Container(height: 1, color: NexusColors.separator),
                  LockRow(device: locks[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final room in rooms)
          RoomWidget(room: room, devices: compound.devicesOfRoom(room.id)),
      ],
    );
  }
}
