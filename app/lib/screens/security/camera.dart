import 'package:nexus_shared/nexus_shared.dart';

/// Cameras shown in local-demo-mode, so the Security tab has something
/// representative before a real server is paired. A live server replaces
/// these wholesale with whatever `NEXUS_CAMERAS` declares (see
/// `server/lib/config.dart`) - none of these have a stream URL, so they
/// render as "no stream configured" rather than pretending to be live.
final List<Camera> demoCameras = [
  Camera(id: 'cam_front_door', name: 'Front Door', buildingId: 'main'),
  Camera(id: 'cam_barn_north', name: 'Barn North', buildingId: 'barn', hasMotion: true),
  Camera(id: 'cam_driveway', name: 'Driveway', buildingId: 'main'),
  Camera(id: 'cam_shop_bay', name: 'Shop Bay', buildingId: 'shop'),
  Camera(id: 'cam_cabin_trail', name: 'Cabin Trail', buildingId: 'cabin'),
  Camera(id: 'cam_east_gate', name: 'East Gate', buildingId: 'ge'),
];
