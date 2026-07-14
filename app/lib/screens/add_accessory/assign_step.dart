import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';

/// Add Accessory step 4 (Section 7): pick building, then room (skipped
/// for lock/gate, which attach to the building itself).
class AssignStep extends StatefulWidget {
  const AssignStep({
    super.key,
    required this.compound,
    required this.deviceType,
    this.initialBuildingId,
    required this.onConfirm,
  });

  final Compound compound;
  final DeviceType deviceType;
  final String? initialBuildingId;
  final void Function(String buildingId, String? roomId) onConfirm;

  @override
  State<AssignStep> createState() => _AssignStepState();
}

class _AssignStepState extends State<AssignStep> {
  String? _buildingId;
  String? _roomId;

  @override
  void initState() {
    super.initState();
    _buildingId = widget.initialBuildingId ?? widget.compound.buildings.first.id;
  }

  bool get _needsRoom => widget.deviceType != DeviceType.lock;

  @override
  Widget build(BuildContext context) {
    final rooms = _buildingId == null ? <Room>[] : widget.compound.roomsOfBuilding(_buildingId!);
    final canConfirm = _buildingId != null && (!_needsRoom || _roomId != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assign', style: NexusText.title),
        const SizedBox(height: 20),
        Text('Building', style: NexusText.footnote),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final building in widget.compound.buildings)
              _Chip(
                label: building.name,
                selected: building.id == _buildingId,
                onTap: () => setState(() {
                  _buildingId = building.id;
                  _roomId = null;
                }),
              ),
          ],
        ),
        if (_needsRoom) ...[
          const SizedBox(height: 20),
          Text('Room', style: NexusText.footnote),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final room in rooms)
                _Chip(
                  label: room.name,
                  selected: room.id == _roomId,
                  onTap: () => setState(() => _roomId = room.id),
                ),
            ],
          ),
        ],
        const Spacer(),
        PressScale(
          onTap: canConfirm ? () => widget.onConfirm(_buildingId!, _needsRoom ? _roomId : null) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: canConfirm ? NexusColors.blue : NexusColors.secondarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'Confirm',
                style: NexusText.headline.copyWith(color: canConfirm ? const Color(0xFFFFFFFF) : NexusColors.textFaint),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? NexusColors.blue : NexusColors.surface,
          borderRadius: BorderRadius.circular(NexusRadii.pill),
          border: Border.all(color: selected ? NexusColors.blue : NexusColors.separator),
        ),
        child: Text(
          label,
          style: NexusText.bodyMedium.copyWith(color: selected ? const Color(0xFFFFFFFF) : NexusColors.textPrimary),
        ),
      ),
    );
  }
}
