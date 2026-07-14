import 'package:flutter/widgets.dart';
import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/status_pill.dart';
import 'building_content.dart';
import 'building_status.dart';

/// Full-screen building view (Section 3) - the "I want to really work in
/// this building" path, reached via long-press on a zone pin.
class BuildingView extends StatelessWidget {
  const BuildingView({super.key, required this.buildingId});

  final String buildingId;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final compound = store.compound;
        final building = compound.buildingById(buildingId);
        final status = computeBuildingStatus(compound, buildingId);
        final meshNode = compound.meshNodeOfBuilding(buildingId);

        return Container(
          color: NexusColors.background,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              NexusIcon(NexusGlyph.chevronLeft, size: 16, color: NexusColors.blue),
                              const SizedBox(width: 3),
                              Text('Map', style: NexusText.bodyMedium.copyWith(color: NexusColors.blue)),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          building.name,
                          textAlign: TextAlign.center,
                          style: NexusText.headline,
                        ),
                      ),
                      StatusPill(label: status.label, color: status.color),
                    ],
                  ),
                ),
                if (meshNode != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        NexusIcon(
                          NexusGlyph.meshNode,
                          size: 13,
                          color: meshNode.online ? NexusColors.textMuted : NexusColors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          meshNode.online
                              ? 'Mesh node active · ${meshNode.batteryPercent}% battery'
                              : 'Mesh node offline',
                          style: NexusText.footnote.copyWith(
                            color: meshNode.online ? NexusColors.textMuted : NexusColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: BuildingContent(buildingId: buildingId),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
