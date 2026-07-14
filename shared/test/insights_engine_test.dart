import 'package:nexus_shared/nexus_shared.dart';
import 'package:test/test.dart';

void main() {
  group('computeInsights', () {
    test('flags an offline mesh node as crit', () {
      final compound = buildDemoCompound();
      final shopNode = compound.meshNodes.firstWhere((n) => n.id == 'mesh_shop');
      expect(shopNode.online, isFalse);

      final insights = computeInsights(compound);
      expect(insights.any((i) => i.level == Level.crit && i.message.contains('offline')), isTrue);
    });

    test('flags a low mesh battery as warn', () {
      final compound = buildDemoCompound();
      final insights = computeInsights(compound);
      expect(insights.any((i) => i.level == Level.warn && i.message.contains('battery')), isTrue);
    });

    test('flags an open gate/lock as warn', () {
      final compound = buildDemoCompound();
      final insights = computeInsights(compound);
      expect(insights.any((i) => i.level == Level.warn && i.message.contains('Shop Roller Door')), isTrue);
    });

    test('flags a running grill as warn, including probe status when connected', () {
      final compound = buildDemoCompound();
      final grill = compound.devices.whereType<GrillDevice>().first;
      grill.on = true;
      grill.probe = 140;

      final insights = computeInsights(compound);
      expect(insights.any((i) => i.level == Level.warn && i.message.contains(grill.name)), isTrue);
    });

    test('flags low pellets as info', () {
      final compound = buildDemoCompound();
      final grill = compound.devices.whereType<GrillDevice>().first;
      grill.on = true;
      grill.pellets = 15;

      final insights = computeInsights(compound);
      expect(insights.any((i) => i.level == Level.info && i.message.contains('pellet')), isTrue);
    });

    test('flags 4+ lights on as info', () {
      final compound = buildDemoCompound();
      var turnedOn = 0;
      for (final light in compound.devices.whereType<LightDevice>()) {
        light.on = true;
        turnedOn++;
        if (turnedOn >= 4) break;
      }

      final insights = computeInsights(compound);
      expect(insights.any((i) => i.level == Level.info && i.message.contains('lights are on')), isTrue);
    });

    test('sorts crit before warn before info', () {
      final compound = buildDemoCompound();
      final insights = computeInsights(compound);
      for (var i = 1; i < insights.length; i++) {
        expect(insights[i - 1].level.index, greaterThanOrEqualTo(insights[i].level.index));
      }
    });
  });

  group('computeZoneStatus', () {
    test('a zone with an open gate is alert state with no offline mesh node', () {
      final compound = buildDemoCompound();
      final status = computeZoneStatus(compound, 'shop');
      expect(status.state, ZonePinState.alert);
      expect(status.hasOfflineMeshNode, isTrue);
    });

    test('a zone with lights on but no open locks is caution state', () {
      final compound = buildDemoCompound();
      final status = computeZoneStatus(compound, 'barn');
      expect(status.state, ZonePinState.caution);
    });

    test('a fully secured zone is secure state', () {
      final compound = buildDemoCompound();
      final status = computeZoneStatus(compound, 'cabin');
      expect(status.state, ZonePinState.secure);
    });
  });

  group('tickCompoundSimulation', () {
    test('an ignited grill climbs toward its set point over multiple ticks', () {
      final compound = buildDemoCompound();
      final grill = compound.devices.whereType<GrillDevice>().first
        ..on = true
        ..temp = 72
        ..set = 225;

      final tempsOverTime = <double>[grill.temp];
      for (var i = 0; i < 30; i++) {
        tickCompoundSimulation(compound);
        tempsOverTime.add(grill.temp);
      }

      expect(tempsOverTime.last, greaterThan(tempsOverTime.first));
      expect(grill.temp, lessThanOrEqualTo(225));
      // Should not jump instantly to the set point on the very first tick.
      expect(tempsOverTime[1], lessThan(225));
    });

    test('the probe only connects once the chamber is up to temperature', () {
      final compound = buildDemoCompound();
      final grill = compound.devices.whereType<GrillDevice>().first
        ..on = true
        ..temp = 72
        ..set = 225
        ..probeTarget = 203
        ..probe = null;

      // Chamber still cold - probe should not connect yet even though we
      // force a temp above 150 but far from set point.
      grill.temp = 160;
      tickCompoundSimulation(compound);
      expect(grill.probe, isNull);

      // Chamber within 10 degrees of set point - probe should connect.
      grill.temp = 220;
      tickCompoundSimulation(compound);
      expect(grill.probe, isNotNull);
    });
  });
}
