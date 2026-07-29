import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';

import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../state/compound_store.dart';
import '../../state/nexus_data_source.dart';
import '../../widgets/edit_prompts.dart';
import 'discover_sheet.dart';
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
        final editor = store is CompoundStore ? store : null;
        if (buildings.isEmpty) {
          return Container(
            color: NexusColors.background,
            child: Column(
              children: [
                const TabHeader(title: 'Buildings'),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('No buildings yet', style: NexusText.headline),
                          const SizedBox(height: 6),
                          Text(
                            editor == null
                                ? 'Buildings appear here once your server has some.'
                                : 'Add the first building on your compound - a house, '
                                    'a barn, a shop - then fill it with rooms and devices.',
                            textAlign: TextAlign.center,
                            style: NexusText.subhead.copyWith(color: NexusColors.textMuted),
                          ),
                          if (editor != null) ...[
                            const SizedBox(height: 18),
                            _AddButton(label: 'Add a building', onTap: () => _addBuilding(editor)),
                          ],
                        ],
                      ),
                    ),
                  ),
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
                onAdd: editor == null ? null : () => _addBuilding(editor),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _BuildingHeader(compound: compound, building: selected),
                    const SizedBox(height: 14),
                    ..._buildingBody(compound, selected, editor),
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
  // ---- Editing -----------------------------------------------------------
  // Only offered when this device owns the compound. Against a server the
  // server is the source of truth, so a local edit would be silently
  // overwritten by the next state push - better to not present the option.

  Future<void> _addBuilding(CompoundStore store) async {
    final name = await promptForName(
      context,
      title: 'New building',
      subtitle: 'What do you call it?',
    );
    if (name == null) return;
    // Spread new buildings around the map instead of stacking them dead
    // centre, where they'd overlap and be unpickable.
    final n = store.compound.buildings.length;
    final building = store.addBuilding(
      name,
      mapX: 0.25 + (n % 3) * 0.25,
      mapY: 0.25 + ((n ~/ 3) % 3) * 0.25,
    );
    if (mounted) setState(() => _selectedId = building.id);
  }

  Future<void> _addRoom(CompoundStore store, Building building) async {
    final name = await promptForName(
      context,
      title: 'New room in ${building.name}',
      subtitle: 'Kitchen, Loft, Bay 2 - whatever you call it.',
    );
    if (name != null) store.addRoom(building.id, name);
  }

  Future<void> _addDevice(CompoundStore store, Building building, Room? room) async {
    final type = await promptForDeviceType(context);
    if (type == null || !mounted) return;
    final name = await promptForName(
      context,
      title: 'Name this device',
      subtitle: room == null ? building.name : '${building.name} · ${room.name}',
    );
    if (name == null) return;
    store.addDeviceOfType(
      type: type,
      name: name,
      buildingId: building.id,
      // Locks ignore roomId anyway, but pass null so the intent is explicit.
      roomId: type == DeviceType.lock ? null : room?.id,
    );
  }

  /// Adds a device the server found on the network. The scan proposes a name
  /// and type; the user confirms both, because discovery knows a Chromecast
  /// exists but not that you call it "Living Room TV".
  Future<void> _discover(CompoundStore store, Building building, NexusDataSource source) async {
    final pick = await showDiscoverySheet(context, source);
    if (pick == null || !mounted) return;
    final (device, type) = pick;
    final name = await promptForName(
      context,
      title: 'Add ${device.name}',
      subtitle: 'Found at ${device.address} - name it and it joins ${building.name}.',
      initialValue: device.name,
    );
    if (name == null) return;
    store.addDeviceOfType(type: type, name: name, buildingId: building.id);
  }

  Future<void> _renameBuilding(CompoundStore store, Building building) async {
    final name = await promptForName(
      context,
      title: 'Rename building',
      initialValue: building.name,
      confirmLabel: 'Rename',
    );
    if (name != null) store.renameBuilding(building.id, name);
  }

  Future<void> _removeBuilding(CompoundStore store, Building building) async {
    final rooms = store.compound.roomsOfBuilding(building.id).length;
    final devices = store.compound.devicesOfBuilding(building.id).length;
    final ok = await confirmDelete(
      context,
      title: 'Delete ${building.name}?',
      detail: 'This also removes its $rooms room(s) and $devices device(s). '
          'It cannot be undone.',
    );
    if (ok) {
      store.removeBuilding(building.id);
      if (mounted) setState(() => _selectedId = null);
    }
  }

  Future<void> _removeRoom(CompoundStore store, Room room) async {
    final devices = store.compound.devicesOfRoom(room.id).length;
    final ok = await confirmDelete(
      context,
      title: 'Delete ${room.name}?',
      detail: devices == 0
          ? 'This room is empty. It cannot be undone.'
          : 'This also removes its $devices device(s). It cannot be undone.',
    );
    if (ok) store.removeRoom(room.id);
  }

  List<Widget> _buildingBody(Compound compound, Building building, CompoundStore? editor) {
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
          editor == null
              ? 'This building has no rooms yet.'
              : 'No rooms in ${building.name} yet. Add one, then put devices in it.',
          style: NexusText.subhead,
        )
      else ...[
        Text('Rooms', style: NexusText.footnote),
        const SizedBox(height: 8),
        for (final room in rooms) ...[
          RoomWidget(
            room: room,
            devices: compound.devicesOfRoom(room.id),
            showEmpty: true,
          ),
          if (editor != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  _AddButton(
                    label: 'Add device',
                    compact: true,
                    onTap: () => _addDevice(editor, building, room),
                  ),
                  const SizedBox(width: 8),
                  _AddButton(
                    label: 'Delete room',
                    compact: true,
                    destructive: true,
                    onTap: () => _removeRoom(editor, room),
                  ),
                ],
              ),
            ),
        ],
      ],
      if (editor != null) ...[
        const SizedBox(height: 10),
        _AddButton(label: 'Add a room', onTap: () => _addRoom(editor, building)),
        const SizedBox(height: 10),
        _AddButton(
          label: 'Add a lock or gate',
          onTap: () => _addDevice(editor, building, null),
        ),
        const SizedBox(height: 10),
        _AddButton(
          label: 'Find devices on my network',
          onTap: () => _discover(editor, building, CompoundScope.of(context)),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _AddButton(
              label: 'Rename building',
              compact: true,
              onTap: () => _renameBuilding(editor, building),
            ),
            const SizedBox(width: 8),
            _AddButton(
              label: 'Delete building',
              compact: true,
              destructive: true,
              onTap: () => _removeBuilding(editor, building),
            ),
          ],
        ),
      ],
    ];
  }
}

/// Horizontally scrolling building selector - one pill per building, with a
/// status dot so problems are visible without switching tabs.
/// A restrained pill button - the compound-editing affordances shouldn't
/// compete visually with the device controls they sit beneath.
class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.label,
    required this.onTap,
    this.compact = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? NexusColors.red : NexusColors.blue;
    return PressScale(
      onTap: onTap,
      child: Container(
        width: compact ? null : double.infinity,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16, vertical: compact ? 9 : 13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(compact ? NexusRadii.pill : 14),
        ),
        child: Center(
          widthFactor: compact ? 1 : null,
          child: Text(label, style: NexusText.bodyMedium.copyWith(color: color)),
        ),
      ),
    );
  }
}

class _BuildingTabBar extends StatelessWidget {
  const _BuildingTabBar({
    required this.buildings,
    required this.selectedId,
    required this.statusOf,
    required this.onSelect,
    this.onAdd,
  });

  final List<Building> buildings;
  final String selectedId;
  final BuildingStatus Function(String buildingId) statusOf;
  final ValueChanged<String> onSelect;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        // One trailing slot for the "+" when editing is available, so adding
        // a building is reachable from the same strip you switch them in.
        itemCount: buildings.length + (onAdd == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == buildings.length) {
            return Center(child: _AddButton(label: '+  Building', compact: true, onTap: onAdd!));
          }
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
