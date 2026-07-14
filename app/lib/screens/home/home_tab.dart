import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/nexus_sheet.dart';
import '../../widgets/press_scale.dart';
import '../add_accessory/add_accessory_flow.dart';
import '../building/building_view.dart';
import 'crit_insight_pill.dart';
import 'map_painter.dart';
import 'nexus_heartbeat.dart';
import 'vehicle_pin.dart';
import 'zone_pin.dart';
import 'zone_sheet.dart';

/// Home tab (Section 3): the map *is* Home - full bleed, edge to edge, no
/// header chrome above it. There is no separate Map/Compound tab.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _selectedZoneId;
  String? _activeVehicleId;
  final Set<String> _dismissedInsightIds = {};

  void _openZoneSheet(BuildContext context, Zone zone) async {
    setState(() => _selectedZoneId = zone.id);
    await showNexusSheet(
      context: context,
      builder: (context) => NexusSheet(child: ZoneSheetContent(zone: zone)),
    );
    if (mounted) setState(() => _selectedZoneId = null);
  }

  void _openBuildingView(BuildContext context, Zone zone) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionsBuilder: (context, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
        pageBuilder: (context, animation, secondary) => BuildingView(buildingId: zone.resolvedPrimaryBuildingId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final compound = store.compound;
        final activeVehicle = _activeVehicleId == null
            ? null
            : compound.vehicles.where((v) => v.id == _activeVehicleId).firstOrNull;
        final critInsight = compound.insights
            .where((i) => i.level == Level.crit && !_dismissedInsightIds.contains(i.id))
            .firstOrNull;

        return LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: const MapBackgroundPainter()),
                ),
                for (final zone in compound.zones)
                  Positioned(
                    left: zone.mapX * size.width - NexusTapTargets.mapPin / 2,
                    top: zone.mapY * size.height - NexusTapTargets.mapPin / 2,
                    child: ZonePin(
                      zone: zone,
                      status: computeZoneStatus(compound, zone.id),
                      selected: zone.id == _selectedZoneId,
                      onTap: () => _openZoneSheet(context, zone),
                      onLongPress: () => _openBuildingView(context, zone),
                    ),
                  ),
                for (final vehicle in compound.vehicles)
                  Positioned(
                    left: vehicle.mapX * size.width - NexusTapTargets.mapPin / 2,
                    top: vehicle.mapY * size.height - NexusTapTargets.mapPin / 2,
                    child: VehiclePin(
                      vehicle: vehicle,
                      onTap: () => setState(() => _activeVehicleId = _activeVehicleId == vehicle.id ? null : vehicle.id),
                    ),
                  ),
                if (activeVehicle != null)
                  Positioned(
                    top: 14,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      bottom: false,
                      child: VehicleStatusCard(
                        vehicle: activeVehicle,
                        onClose: () => setState(() => _activeVehicleId = null),
                      ),
                    ),
                  ),
                if (critInsight != null)
                  Positioned(
                    top: 14,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Center(
                        child: CritInsightPill(
                          insight: critInsight,
                          onDismiss: () => setState(() => _dismissedInsightIds.add(critInsight.id)),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: SafeArea(top: false, child: const NexusHeartbeat()),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: PressScale(
                      onTap: () => showAddAccessoryFlow(context),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: NexusColors.blue,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
                          ],
                        ),
                        child: const Center(child: NexusIcon(NexusGlyph.plus, size: 20, color: Color(0xFFFFFFFF))),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
