import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../state/compound_scope.dart';
import '../../state/compound_store.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/edit_prompts.dart';
import '../../widgets/press_scale.dart';
import '../building/building_status.dart';
import '../building/building_view.dart';

/// The buildings on this compound, docked over the map.
///
/// The map is the way into a building - and from there its rooms, and their
/// devices - so there has to be something reliable to tap. Pins alone aren't
/// enough: on web the map is a JavaScript scene that owns its own hit-testing,
/// and even on native a pin is a small target that says nothing about what's
/// inside. This is the Apple Maps idiom, and it works identically everywhere.
class BuildingDock extends StatelessWidget {
  const BuildingDock({super.key, required this.bottomInset});

  /// Space to leave for the tab bar sitting underneath.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    final compound = store.compound;
    final editor = store is CompoundStore ? store : null;

    return PointerInterceptor(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(NexusRadii.card),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: const Color(0x59101528),
                borderRadius: BorderRadius.circular(NexusRadii.card),
                border: Border.all(color: const Color(0x2EFFFFFF), width: 0.8),
                boxShadow: NexusShadows.raised,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    compound.buildings.isEmpty
                        ? 'No buildings yet'
                        : '${compound.buildings.length} '
                            'building${compound.buildings.length == 1 ? '' : 's'}',
                    style: NexusText.sectionHeader.copyWith(
                      color: const Color(0xB3FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (compound.buildings.isEmpty)
                    Text(
                      editor == null
                          ? 'Buildings appear here once your server has some.'
                          : 'Add one, then fill it with rooms and devices.',
                      style: NexusText.subhead.copyWith(color: const Color(0xB3FFFFFF)),
                    )
                  else
                    SizedBox(
                      // Two lines of text plus padding; measured rather than
                      // guessed, because 62 overflowed by a hair.
                      height: 68,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: compound.buildings.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final building = compound.buildings[index];
                          return _BuildingChip(
                            building: building,
                            status: computeBuildingStatus(compound, building.id),
                            roomCount: compound.rooms
                                .where((r) => r.buildingId == building.id)
                                .length,
                            onTap: () => Navigator.of(context).push(
                              PageRouteBuilder(
                                opaque: true,
                                transitionsBuilder: (context, animation, _, child) =>
                                    FadeTransition(opacity: animation, child: child),
                                pageBuilder: (context, animation, _) =>
                                    BuildingView(buildingId: building.id),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (editor != null) ...[
                    const SizedBox(height: 12),
                    PressScale(
                      onTap: () => _addBuilding(context, editor),
                      child: Text(
                        '+  Add a building',
                        style: NexusText.bodyMedium.copyWith(
                          color: const Color(0xFF5AC8FA),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addBuilding(BuildContext context, CompoundStore store) async {
    final name = await promptForName(
      context,
      title: 'New building',
      subtitle: 'A house, a barn, a shop - what do you call it?',
    );
    if (name == null) return;
    // Spread them around the map rather than stacking them dead centre, where
    // they would overlap and be unpickable.
    final n = store.compound.buildings.length;
    store.addBuilding(
      name,
      mapX: 0.25 + (n % 3) * 0.25,
      mapY: 0.25 + ((n ~/ 3) % 3) * 0.25,
    );
  }
}

class _BuildingChip extends StatelessWidget {
  const _BuildingChip({
    required this.building,
    required this.status,
    required this.roomCount,
    required this.onTap,
  });

  final Building building;
  final BuildingStatus status;
  final int roomCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1FFFFFFF), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: status.color),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    building.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NexusText.bodyMedium.copyWith(color: const Color(0xFFFFFFFF)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$roomCount room${roomCount == 1 ? '' : 's'} · ${status.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NexusText.caption.copyWith(color: const Color(0x99FFFFFF)),
            ),
          ],
        ),
      ),
    );
  }
}
