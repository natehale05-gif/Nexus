import 'package:flutter/foundation.dart';
import 'package:nexus_shared/nexus_shared.dart';

/// Where the active [NexusDataSource] currently stands with its backing
/// server, so any screen can show a consistent status regardless of which
/// implementation is active. [CompoundStore] (local-demo-mode) is always
/// [demo]; only [ServerClient] (live mode) moves through the others.
enum ConnectionStatus {
  /// Local-only demo mode - there is no real server to be connected to.
  demo,

  /// A live connection is being established (first attempt).
  connecting,

  /// Connected and authenticated; [NexusDataSource.compound] reflects the
  /// server's real state.
  connected,

  /// A previously-working connection dropped and is being retried.
  reconnecting,
}

/// Common interface for wherever the app's live [Compound] tree comes
/// from. [CompoundStore] implements this for local-demo-mode (owns the
/// state directly, runs the simulation ticker); [ServerClient] implements
/// it for live mode (mirrors whatever the Dart server pushes over
/// WebSocket and forwards mutations back to it as commands instead of
/// applying them locally). Every screen talks to whichever one is active
/// through [CompoundScope] without knowing which it is.
abstract class NexusDataSource extends ChangeNotifier {
  Compound get compound;

  ConnectionStatus get connectionStatus;

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

  /// Starts playing a library item (e.g. a tapped Continue Watching tile),
  /// making it the new "now playing".
  void playLibraryItem(String itemId);

  /// Reports the real player's current position for [itemId], so it
  /// persists server-side and survives a restart/reconnect. Called
  /// periodically during playback, not every frame.
  void reportPlaybackPosition(String itemId, double positionSeconds);

  /// Re-scans the server's media library folder for new/removed files.
  /// No-op in local-demo-mode (nothing to scan).
  void rescanLibrary();

  /// Scans the network for devices that aren't in the compound yet.
  ///
  /// Only a paired server can do this - it's the thing actually sitting on
  /// the LAN, while the app is often remote (Tailscale) or on web (no raw
  /// UDP at all). Local/demo modes return an empty list rather than
  /// pretending to scan.
  Future<List<DiscoveredDevice>> discoverDevices() async => const [];

  /// The URL to stream [itemId]'s file from, or null if there's no real
  /// server to stream from (local-demo-mode) - callers should fall back to
  /// a placeholder rather than attempting playback.
  Uri? mediaStreamUri(String itemId);

  void turnOffAllLights();

  void addDevice(Device device);

  List<Device> devicesMatchingName(String query);
  Building? buildingMatchingName(String query);
}
