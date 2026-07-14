import 'dart:math';

import 'compound.dart';
import 'device.dart';
import 'enums.dart';

/// One simulation tick (Section 4's "Simulated behavior for a demo/offline
/// mode"): grills climb toward their set point over several ticks rather
/// than jumping instantly, probes only "connect" and climb once the
/// chamber is up to temperature, and climate devices drift slowly toward
/// their target. Shared by the app's local-demo-mode ticker and the
/// server's ticker so both behave identically.
///
/// Returns true if anything actually changed (callers use this to avoid
/// redundant insight recomputation/broadcast on a no-op tick).
bool tickCompoundSimulation(Compound compound, {Random? random}) {
  final rand = random ?? Random();
  var changed = false;

  for (final grill in compound.devices.whereType<GrillDevice>()) {
    if (grill.on) {
      if (grill.temp < grill.set) {
        final remaining = grill.set - grill.temp;
        final step = max(2.0, remaining * 0.09);
        grill.temp = min(grill.set, grill.temp + step);
        changed = true;
      } else if (grill.temp > grill.set) {
        grill.temp = max(grill.set, grill.temp - 3);
        changed = true;
      } else {
        grill.temp += (rand.nextDouble() - 0.5) * 2;
        changed = true;
      }

      final chamberNearSet = (grill.temp - grill.set).abs() <= 10;
      if (grill.temp >= 150 && grill.probeTarget != null) {
        if (grill.probe == null && chamberNearSet) {
          grill.probe = 92;
          changed = true;
        } else if (grill.probe != null && chamberNearSet) {
          final target = grill.probeTarget!;
          if (grill.probe! < target) {
            grill.probe = min(target, grill.probe! + 0.6);
            changed = true;
          }
        }
      }

      if (grill.pellets > 0 && rand.nextDouble() < 0.15) {
        grill.pellets = max(0, grill.pellets - 1);
        changed = true;
      }
    } else if (grill.temp > 72) {
      grill.temp = max(72, grill.temp - 4);
      changed = true;
    }
  }

  for (final climate in compound.devices.whereType<ClimateDevice>()) {
    if (climate.mode == ClimateMode.off) continue;
    final target = climate.set;
    if ((climate.temp - target).abs() < 0.3) continue;
    climate.temp += (target > climate.temp ? 1 : -1) * 0.25;
    changed = true;
  }

  return changed;
}
