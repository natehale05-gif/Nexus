import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';

import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/status_pill.dart';
import '../building/building_status.dart';
import '../building/device_rows/lock_row.dart';
import '../building/room_widget.dart';
import '../security/tab_header.dart';

/// Buildings tab: one tab per building on the compound, each showing that
/// building's rooms as room-widget cards containing every device in the
/// room. This is the "control the house" surface - the map (Home) is for
/// spatial awareness, this is for actually working through a building
/// room by room.
class BuildingsTab extends StatefulWidget {
  const BuildingsTab({super.key});

  @override
  State<BuildingsTab> createState() => _BuildingsTabState();
}

class _BuildingsTabState extends State<BuildingsTab> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final compound = store.compound;
        final buildings = compound.buildings;
        if (buildings.isEmpty) {
          return Container(
            color: NexusColors.background,
            child: Column(
              children: [
                const TabHeader(title: 'Buildings'),
                Expanded(
                  child: Center(child: Text('No buildings on this compound yet', style: NexusText.subhead)),
                ),
              ],
            ),
          );
        }

        // Fall back to the first building if nothing is selected yet, or if
        // the selection disappeared (e.g. the server pushed new state).
        final selected = buildings.firstWhere(
          (b) => b.id == _selectedId,
          orElse: () => buildings.first,
        );
        final status = computeBuildingStatus(compound, selected.id);

        return Container(
          color: NexusColors.background,
          child: Column(
            children: [
              TabHeader(title: 'Buildings', pillLabel: status.label, pillColor: status.color),
              _BuildingTabBar(
                buildings: buildings,
                selectedId: selected.id,
                statusOf: (id) => computeBuildingStatus(compound, id),
                onSelect: (id) => setState(() => _selectedId = id),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _BuildingHeader(compound: compound, building: selected),
                    const SizedBox(height: 14),
                    ..._buildingBody(compound, selected),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Locks & gates that belong to the building rather than a room, then
  /// every room as a room-widget card.
  List<Widget> _buildingBody(Compound compound, Building building) {
    final rooms = compound.roomsOfBuilding(building.id);
    final buildingLocks = compound
        .devicesOfBuilding(building.id)
        .whereType<LockDevice>()
        .where((l) => l.roomId == null)
        .toList();

    return [
      if (buildingLocks.isNotEmpty) ...[
        Text('Locks & Gates', style: NexusText.footnote),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: NexusColors.surface,
            borderRadius: BorderRadius.circular(NexusRadii.card),
          ),
          child: Column(
            children: [
              for (var i = 0; i < buildingLocks.length; i++) ...[
                if (i > 0) Container(height: 1, color: NexusColors.separator),
                LockRow(device: buildingLocks[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
      if (rooms.isEmpty)
        Text(
          'This building has no rooms yet. Add an accessory to it from the '
          'Home map to get started.',
          style: NexusText.subhead,
        )
      else ...[
        Text('Rooms', style: NexusText.footnote),
        const SizedBox(height: 8),
        for (final room in rooms)
          RoomWidget(
            room: room,
            devices: compound.devicesOfRoom(room.id),
            showEmpty: true,
          ),
      ],
    ];
  }
}

/// Horizontally scrolling building selector - one pill per building, with a
/// status dot so problems are visible without switching tabs.
class _BuildingTabBar extends StatelessWidget {
  const _BuildingTabBar({
    required this.buildings,
    required this.selectedId,
    required this.statusOf,
    required this.onSelect,
  });

  final List<Building> buildings;
  final String selectedId;
  final BuildingStatus Function(String buildingId) statusOf;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: buildings.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final building = buildings[index];
          final selected = building.id == selectedId;
          final status = statusOf(building.id);
          return Center(
            child: PressScale(
              onTap: () => onSelect(building.id),
              child: AnimatedContainer(
                duration: NexusDurations.fast,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? NexusColors.blue.withValues(alpha: 0.12) : NexusColors.surface,
                  borderRadius: BorderRadius.circular(NexusRadii.pill),
                  border: Border.all(
                    color: selected ? NexusColors.blue : NexusColors.separator,
                    width: selected ? 1.4 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: status.color),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      building.name,
                      style: NexusText.bodyMedium.copyWith(
                        color: selected ? NexusColors.blue : NexusColors.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Summary strip for the selected building: room/device counts and mesh
/// node health, so the tab answers "how is this building doing" at a glance.
class _BuildingHeader extends StatelessWidget {
  const _BuildingHeader({required this.compound, required this.building});

  final Compound compound;
  final Building building;

  @override
  Widget build(BuildContext context) {
    final devices = compound.devicesOfBuilding(building.id);
    final rooms = compound.roomsOfBuilding(building.id);
    final lightsOn = devices.whereType<LightDevice>().where((l) => l.on).length;
    final mesh = compound.meshNodeOfBuilding(building.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NexusColors.surface,
        borderRadius: BorderRadius.circular(NexusRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(building.name, style: NexusText.title)),
              if (mesh != null)
                StatusPill(
                  label: mesh.online ? 'Mesh ${mesh.batteryPercent}%' : 'Mesh offline',
                  color: mesh.online ? NexusColors.green : NexusColors.red,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(icon: NexusGlyph.mapPinBase, label: '${rooms.length} room${rooms.length == 1 ? '' : 's'}'),
              const SizedBox(width: 18),
              _Stat(icon: NexusGlyph.signal, label: '${devices.length} device${devices.length == 1 ? '' : 's'}'),
              const SizedBox(width: 18),
              _Stat(icon: NexusGlyph.bulb, label: '$lightsOn on'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final NexusGlyph icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NexusIcon(icon, size: 13, color: NexusColors.textFaint),
        const SizedBox(width: 5),
        Text(label, style: NexusText.footnote),
      ],
    );
  }
}
