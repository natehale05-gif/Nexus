import 'alert.dart';
import 'building.dart';
import 'compound.dart';
import 'device.dart';
import 'enums.dart';
import 'media.dart';
import 'mesh_node.dart';
import 'vehicle.dart';
import 'weather.dart';

/// Canonical demo/seed compound state, shared by the app's local-demo-mode
/// (build order step 5: "wired to local state first, no server yet") and
/// the Dart server's in-memory state, so both start from the identical
/// compound before the server's real protocol bridges (Section 8) take
/// over populating it.
Compound buildDemoCompound() {
  final zones = [
    Zone(id: 'main', name: 'Main House', buildingIds: ['main'], mapX: 0.50, mapY: 0.52),
    Zone(id: 'barn', name: 'Barn', buildingIds: ['barn'], mapX: 0.27, mapY: 0.30),
    Zone(id: 'shop', name: 'Shop', buildingIds: ['shop'], mapX: 0.74, mapY: 0.28),
    Zone(id: 'cabin', name: 'Cabin', buildingIds: ['cabin'], mapX: 0.20, mapY: 0.72),
    Zone(
      id: 'gates',
      name: 'Gates',
      buildingIds: ['gn', 'ge'],
      mapX: 0.58,
      mapY: 0.86,
      primaryBuildingId: 'gn',
    ),
  ];

  final buildings = [
    Building(id: 'main', name: 'Main House', zoneId: 'main', meshNodeId: 'mesh_main'),
    Building(id: 'barn', name: 'Barn', zoneId: 'barn', meshNodeId: 'mesh_barn'),
    Building(id: 'shop', name: 'Shop', zoneId: 'shop', meshNodeId: 'mesh_shop'),
    Building(id: 'cabin', name: 'Cabin', zoneId: 'cabin', meshNodeId: 'mesh_cabin'),
    Building(id: 'gn', name: 'North Gate', zoneId: 'gates'),
    Building(id: 'ge', name: 'East Gate', zoneId: 'gates'),
  ];

  final rooms = [
    Room(id: 'main_living', buildingId: 'main', name: 'Living Room'),
    Room(id: 'main_kitchen', buildingId: 'main', name: 'Kitchen'),
    Room(id: 'main_primary', buildingId: 'main', name: 'Primary Bedroom'),
    Room(id: 'main_office', buildingId: 'main', name: 'Office'),
    Room(id: 'main_patio', buildingId: 'main', name: 'Patio'),
    Room(id: 'barn_main', buildingId: 'barn', name: 'Main Floor'),
    Room(id: 'barn_loft', buildingId: 'barn', name: 'Loft'),
    Room(id: 'shop_floor', buildingId: 'shop', name: 'Shop Floor'),
    Room(id: 'cabin_main', buildingId: 'cabin', name: 'Cabin'),
  ];

  final devices = <Device>[
    LightDevice(id: 'lt_living', name: 'Living Room Lamps', buildingId: 'main', roomId: 'main_living', on: true, brightness: 62),
    LightDevice(id: 'lt_kitchen', name: 'Kitchen Ceiling', buildingId: 'main', roomId: 'main_kitchen', on: true, brightness: 88),
    LightDevice(id: 'lt_primary', name: 'Bedroom Lamp', buildingId: 'main', roomId: 'main_primary', on: false, brightness: 40),
    LightDevice(id: 'lt_office', name: 'Office Desk Light', buildingId: 'main', roomId: 'main_office', on: false, brightness: 100),
    MediaDevice(id: 'md_appletv', name: 'Apple TV', buildingId: 'main', roomId: 'main_living', on: true),
    ClimateDevice(id: 'cl_main', name: 'Main Thermostat', buildingId: 'main', roomId: 'main_living', temp: 68, set: 72, mode: ClimateMode.heat, fan: FanMode.auto),
    GrillDevice(
      id: 'gr_traeger',
      name: 'Traeger Ironwood 885',
      buildingId: 'main',
      roomId: 'main_patio',
      on: true,
      temp: 118,
      set: 225,
      probe: null,
      probeTarget: 203,
      pellets: 64,
      cloudOnline: true,
    ),
    LockDevice(id: 'lk_front', name: 'Front Door', buildingId: 'main', locked: true),

    LightDevice(id: 'lt_barn_main', name: 'Barn Main Floor', buildingId: 'barn', roomId: 'barn_main', on: true, brightness: 100),
    LightDevice(id: 'lt_barn_loft', name: 'Barn Loft', buildingId: 'barn', roomId: 'barn_loft', on: false, brightness: 70),
    LockDevice(id: 'lk_barn', name: 'Barn Door', buildingId: 'barn', locked: true),

    LightDevice(id: 'lt_shop', name: 'Shop Floor Lights', buildingId: 'shop', roomId: 'shop_floor', on: false, brightness: 100),
    ClimateDevice(id: 'cl_shop', name: 'Shop Heater', buildingId: 'shop', roomId: 'shop_floor', temp: 54, set: 60, mode: ClimateMode.off, fan: FanMode.auto),
    LockDevice(id: 'lk_shop', name: 'Shop Roller Door', buildingId: 'shop', locked: false, openSince: DateTime.now().subtract(const Duration(minutes: 47))),

    LightDevice(id: 'lt_cabin', name: 'Cabin Lights', buildingId: 'cabin', roomId: 'cabin_main', on: false, brightness: 55),
    ClimateDevice(id: 'cl_cabin', name: 'Cabin Thermostat', buildingId: 'cabin', roomId: 'cabin_main', temp: 61, set: 65, mode: ClimateMode.auto, fan: FanMode.auto),
    LockDevice(id: 'lk_cabin', name: 'Cabin Door', buildingId: 'cabin', locked: true),

    LockDevice(id: 'lk_gn', name: 'North Gate', buildingId: 'gn', locked: true, isGate: true),
    LockDevice(id: 'lk_ge', name: 'East Gate', buildingId: 'ge', locked: true, isGate: true),
  ];

  final vehicles = [
    Vehicle(
      id: 'veh_f250',
      name: 'F-250',
      status: VehicleStatus.parked,
      locationDescription: 'Parked · Shop bay',
      batteryPercent: 100,
      mapX: 0.70,
      mapY: 0.40,
    ),
    Vehicle(
      id: 'veh_modely',
      name: 'Model Y',
      status: VehicleStatus.parked,
      locationDescription: 'Parked · Main house driveway',
      batteryPercent: 78,
      mapX: 0.44,
      mapY: 0.60,
    ),
  ];

  final meshNodes = [
    MeshNode(id: 'mesh_main', name: 'Main House', buildingId: 'main', online: true, batteryPercent: 92),
    MeshNode(id: 'mesh_barn', name: 'Barn', buildingId: 'barn', online: true, batteryPercent: 24),
    MeshNode(id: 'mesh_shop', name: 'Shop', buildingId: 'shop', online: false, batteryPercent: 0),
    MeshNode(id: 'mesh_cabin', name: 'Cabin', buildingId: 'cabin', online: true, batteryPercent: 81),
  ];

  final alerts = [
    Alert(
      id: 'al_1',
      level: Level.warn,
      source: 'Barn Camera',
      message: 'Motion detected near the north entrance',
      time: DateTime.now().subtract(const Duration(minutes: 6)),
    ),
    Alert(
      id: 'al_2',
      level: Level.crit,
      source: 'Shop Mesh Node',
      message: 'Node has been offline for 18 minutes',
      time: DateTime.now().subtract(const Duration(minutes: 18)),
    ),
    Alert(
      id: 'al_3',
      level: Level.info,
      source: 'Front Door',
      message: 'Locked automatically at sunset',
      time: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  return Compound(
    zones: zones,
    buildings: buildings,
    rooms: rooms,
    devices: devices,
    vehicles: vehicles,
    meshNodes: meshNodes,
    alerts: alerts,
    nowPlaying: NowPlaying(
      title: 'The Bear',
      year: 2024,
      genre: 'Drama · Comedy',
      runtimeMinutes: 28,
      progress: 0.42,
      isPlaying: true,
    ),
    mediaStats: MediaLibraryStats(movieCount: 214, showCount: 38, episodeCount: 1642),
    continueWatching: [
      ContinueWatchingItem(id: 'cw1', title: 'The Bear', progress: 0.42),
      ContinueWatchingItem(id: 'cw2', title: 'Dune: Part Two', progress: 0.18),
      ContinueWatchingItem(id: 'cw3', title: 'Fallout', progress: 0.75),
      ContinueWatchingItem(id: 'cw4', title: 'Shogun', progress: 0.6),
      ContinueWatchingItem(id: 'cw5', title: 'Civil War', progress: 0.05),
      ContinueWatchingItem(id: 'cw6', title: 'The Boys', progress: 0.88),
    ],
    weather: WeatherInfo(tempF: 58, condition: 'Overcast', highF: 64, lowF: 46),
  );
}
