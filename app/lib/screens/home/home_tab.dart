import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../state/compound_scope.dart';
import '../../state/server_client.dart';
import '../../theme/tokens.dart';
import '../../widgets/nexus_sheet.dart';
import '../building/building_view.dart';
import 'building_dock.dart';
import '../nav_menu.dart';
import 'cesium_map.dart';
import 'crit_insight_pill.dart';
import 'map_painter.dart';
import 'nexus_heartbeat.dart';
import 'vehicle_pin.dart';
import 'zone_pin.dart';
import 'zone_sheet.dart';

/// Home tab (Section 3): the map *is* Home - full bleed, edge to edge. The
/// only chrome is a floating brand/status pill (top-left) and the section
/// menu (top-right), Apple-Maps style.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _selectedZoneId;
  String? _activeVehicleId;
  final Set<String> _dismissedInsightIds = {};

  /// While true the pins are drag handles rather than buttons.
  ///
  /// A mode rather than always-on dragging: on a map you tap pins constantly,
  /// and a stray finger that nudges the barn thirty feet north is a change
  /// nobody asked for and might not notice.
  bool _arranging = false;

  /// Turns a drag in pixels into a new normalized position and pushes it to
  /// whichever store is live - the local compound or the server.
  void _drag(
    Offset delta,
    Size canvas, {
    required double x,
    required double y,
    required void Function(double, double) apply,
  }) {
    if (canvas.width <= 0 || canvas.height <= 0) return;
    apply(x + delta.dx / canvas.width, y + delta.dy / canvas.height);
  }

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
        final connection = switch (store) {
          ServerClient(isConnected: true) => HeartbeatConnection.live,
          ServerClient() => HeartbeatConnection.liveConnecting,
          _ => HeartbeatConnection.demo,
        };

        return LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          // On web the map *is* a live CesiumJS scene (photorealistic 3D
          // tiles + terrain, colored compound buildings, and 3D vehicles),
          // which owns its own building/vehicle interaction in 3D. Every
          // other platform keeps the painted tactical map with Flutter pins.
          final useCesium = cesiumMapSupported;
          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: useCesium
                      ? buildCesiumMap()
                      : CustomPaint(painter: const MapBackgroundPainter()),
                ),
                if (!useCesium)
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
                        arranging: _arranging,
                        onDragged: (delta) => _drag(
                          delta,
                          size,
                          x: zone.mapX,
                          y: zone.mapY,
                          apply: (x, y) => store.moveBuilding(
                            zone.resolvedPrimaryBuildingId,
                            x,
                            y,
                          ),
                        ),
                      ),
                    ),
                if (!useCesium)
                  for (final vehicle in compound.vehicles)
                    Positioned(
                      left: vehicle.mapX * size.width - NexusTapTargets.mapPin / 2,
                      top: vehicle.mapY * size.height - NexusTapTargets.mapPin / 2,
                      child: VehiclePin(
                        vehicle: vehicle,
                        onTap: () => setState(() => _activeVehicleId = _activeVehicleId == vehicle.id ? null : vehicle.id),
                        arranging: _arranging,
                        onDragged: (delta) => _drag(
                          delta,
                          size,
                          x: vehicle.mapX,
                          y: vehicle.mapY,
                          apply: (x, y) => store.moveVehicle(vehicle.id, x, y),
                        ),
                      ),
                    ),

                // Floating brand + connection status (top-left).
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 12),
                      child: _MapChip(
                        child: NexusHeartbeat(connectionState: connection),
                      ),
                    ),
                  ),
                ),

                // The buildings on this compound, and the way into their
                // rooms and devices. Docked rather than left to the pins:
                // on web the map is a JavaScript scene that owns its own
                // hit-testing, so pins alone are not a reliable way in.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: BuildingDock(
                    bottomInset: kNexusTabBarHeight,
                    arranging: _arranging,
                    // Dragging pins is only possible where pins are Flutter
                    // widgets. The web map is a JavaScript scene that draws
                    // and hit-tests its own markers.
                    canArrange: !useCesium,
                    onToggleArrange: () => setState(() => _arranging = !_arranging),
                  ),
                ),

                if (activeVehicle != null)
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 62),
                        child: PointerInterceptor(
                          child: VehicleStatusCard(
                            vehicle: activeVehicle,
                            onClose: () => setState(() => _activeVehicleId = null),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (critInsight != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 62),
                        child: Center(
                          child: PointerInterceptor(
                            child: CritInsightPill(
                              insight: critInsight,
                              onDismiss: () => setState(() => _dismissedInsightIds.add(critInsight.id)),
                            ),
                          ),
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

/// A translucent, blurred capsule for floating chrome over the map - the
/// frosted-glass "material" that makes the Home map feel like Apple Maps.
class _MapChip extends StatelessWidget {
  const _MapChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(NexusRadii.pill),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x40101528),
            borderRadius: BorderRadius.circular(NexusRadii.pill),
            border: Border.all(color: const Color(0x33FFFFFF), width: 0.8),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
