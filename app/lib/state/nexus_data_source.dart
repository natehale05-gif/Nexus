import 'package:flutter/foundation.dart';
import 'package:nexus_shared/nexus_shared.dart';

/// Common interface for wherever the app's live [Compound] tree comes
/// from. [CompoundStore] implements this for local-demo-mode (owns the
/// state directly, runs the simulation ticker); [ServerClient] implements
/// it for live mode (mirrors whatever the Dart server pushes over
/// WebSocket and forwards mutations back to it as commands instead of
/// applying them locally). Every screen talks to whichever one is active
/// through [CompoundScope] without knowing which it is.
abstract class NexusDataSource extends ChangeNotifier {
  Compound get compound;

  void toggleLight(String id);
  void setBrightness(String id, double value);

  void setClimateMode(String id, ClimateMode mode);
  void setClimateTarget(String id, double value);
  void nudgeClimateTarget(String id, double delta);
  void setFanMode(String id, FanMode fan);
  void setHold(String id, String? hold);

  void setGrillOn(String id, bool on);
  void setGrillTarget(String id, double value);
  void setProbeTarget(String id, double? value);

  void setLocked(String id, bool locked);

  void setMediaOn(String id, bool on);
  void setNowPlayingState(bool playing);

  void turnOffAllLights();

  void addDevice(Device device);

  List<Device> devicesMatchingName(String query);
  Building? buildingMatchingName(String query);
}
