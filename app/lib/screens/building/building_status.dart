import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../theme/tokens.dart';

class BuildingStatus {
  const BuildingStatus(this.label, this.color);
  final String label;
  final Color color;
}

/// Building-view status pill (Section 3): "Locked", "Gate open", "N on",
/// or "All off".
BuildingStatus computeBuildingStatus(Compound compound, String buildingId) {
  final devices = compound.devicesOfBuilding(buildingId);
  final locks = devices.whereType<LockDevice>().toList();
  final openLock = locks.where((l) => !l.locked).toList();

  if (openLock.isNotEmpty) {
    final anyGate = openLock.any((l) => l.isGate);
    return BuildingStatus(anyGate ? 'Gate open' : 'Unlocked', NexusColors.red);
  }

  final onCount = devices.whereType<LightDevice>().where((l) => l.on).length +
      devices.whereType<GrillDevice>().where((g) => g.on).length +
      devices.whereType<MediaDevice>().where((m) => m.on).length;
  if (onCount > 0) {
    return BuildingStatus('$onCount on', NexusColors.amber);
  }

  if (locks.isNotEmpty) {
    return const BuildingStatus('Locked', NexusColors.green);
  }

  return const BuildingStatus('All off', NexusColors.blue);
}
