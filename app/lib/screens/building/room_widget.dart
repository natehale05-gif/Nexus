import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import 'device_rows/climate_row.dart';
import 'device_rows/grill_row.dart';
import 'device_rows/light_row.dart';
import 'device_rows/media_row.dart';

/// Room widget card (Section 3): header row with inline badges, then
/// device rows in order - light, climate, grill, then any other type.
class RoomWidget extends StatelessWidget {
  const RoomWidget({super.key, required this.room, required this.devices});

  final Room room;
  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    final lights = devices.whereType<LightDevice>().toList();
    final climates = devices.whereType<ClimateDevice>().toList();
    final grills = devices.whereType<GrillDevice>().toList();
    final media = devices.whereType<MediaDevice>().toList();

    final lightsOn = lights.where((l) => l.on).length;
    final grillOn = grills.any((g) => g.on);

    final rows = <Widget>[
      for (final l in lights) LightRow(device: l),
      for (final c in climates) ClimateRow(device: c),
      for (final g in grills) GrillRow(device: g),
      for (final m in media) MediaRow(device: m),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: NexusColors.surface,
        borderRadius: BorderRadius.circular(NexusRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 2),
            child: Row(
              children: [
                Expanded(child: Text(room.name, style: NexusText.headline)),
                if (lightsOn > 0) _Badge(label: '$lightsOn on', color: NexusColors.amber),
                if (climates.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _Badge(label: '${climates.first.temp.round()}°', color: NexusColors.blue),
                ],
                if (grillOn) ...[
                  const SizedBox(width: 6),
                  _Badge(label: '${grills.first.temp.round()}°', color: NexusColors.grill),
                ],
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const _RowDivider(),
            rows[i],
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Container(height: 1, color: NexusColors.separator);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(NexusRadii.pill)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
