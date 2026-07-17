import 'alert.dart';
import 'building.dart';
import 'device.dart';
import 'insight.dart';
import 'media.dart';
import 'mesh_node.dart';
import 'vehicle.dart';
import 'weather.dart';

/// The full compound state tree - the single source of truth shared between
/// the server's in-memory model and the app's local-demo-mode bootstrap
/// state. This is also the shape pushed wholesale (or diffed) over the
/// WebSocket state-sync channel described in Section 8.
class Compound {
  Compound({
    required this.zones,
    required this.buildings,
    required this.rooms,
    required this.devices,
    required this.vehicles,
    required this.meshNodes,
    required this.alerts,
    List<Insight>? insights,
    NowPlaying? nowPlaying,
    MediaLibraryStats? mediaStats,
    List<ContinueWatchingItem>? continueWatching,
    Map<String, double>? playbackPositions,
    WeatherInfo? weather,
  })  : insights = insights ?? [],
        nowPlaying = nowPlaying,
        mediaStats = mediaStats ??
            MediaLibraryStats(movieCount: 0, showCount: 0, episodeCount: 0),
        continueWatching = continueWatching ?? [],
        playbackPositions = playbackPositions ?? {},
        weather = weather;

  final List<Zone> zones;
  final List<Building> buildings;
  final List<Room> rooms;
  final List<Device> devices;
  final List<Vehicle> vehicles;
  final List<MeshNode> meshNodes;
  final List<Alert> alerts;
  List<Insight> insights;
  NowPlaying? nowPlaying;
  MediaLibraryStats mediaStats;
  List<ContinueWatchingItem> continueWatching;

  /// Playback position (seconds) per library item id - the persisted source
  /// of truth for "where did I leave off," survives server restarts and
  /// library rescans (see `server/lib/media/`).
  Map<String, double> playbackPositions;
  WeatherInfo? weather;

  Building buildingById(String id) => buildings.firstWhere((b) => b.id == id);

  Zone? zoneOfBuilding(String buildingId) {
    for (final z in zones) {
      if (z.buildingIds.contains(buildingId)) return z;
    }
    return null;
  }

  List<Room> roomsOfBuilding(String buildingId) =>
      rooms.where((r) => r.buildingId == buildingId).toList();

  List<Device> devicesOfBuilding(String buildingId) =>
      devices.where((d) => d.buildingId == buildingId).toList();

  List<Device> devicesOfRoom(String roomId) =>
      devices.where((d) => d.roomId == roomId).toList();

  List<Device> devicesOfZone(String zoneId) {
    final zone = zones.firstWhere((z) => z.id == zoneId);
    return devices.where((d) => zone.buildingIds.contains(d.buildingId)).toList();
  }

  MeshNode? meshNodeOfBuilding(String buildingId) {
    final building = buildingById(buildingId);
    if (building.meshNodeId == null) return null;
    for (final m in meshNodes) {
      if (m.id == building.meshNodeId) return m;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'zones': zones.map((z) => z.toJson()).toList(),
        'buildings': buildings.map((b) => b.toJson()).toList(),
        'rooms': rooms.map((r) => r.toJson()).toList(),
        'devices': devices.map((d) => d.toJson()).toList(),
        'vehicles': vehicles.map((v) => v.toJson()).toList(),
        'meshNodes': meshNodes.map((m) => m.toJson()).toList(),
        'alerts': alerts.map((a) => a.toJson()).toList(),
        'insights': insights.map((i) => i.toJson()).toList(),
        'nowPlaying': nowPlaying?.toJson(),
        'mediaStats': mediaStats.toJson(),
        'continueWatching': continueWatching.map((c) => c.toJson()).toList(),
        'playbackPositions': playbackPositions,
        'weather': weather?.toJson(),
      };

  factory Compound.fromJson(Map<String, dynamic> json) => Compound(
        zones: (json['zones'] as List)
            .map((e) => Zone.fromJson(e as Map<String, dynamic>))
            .toList(),
        buildings: (json['buildings'] as List)
            .map((e) => Building.fromJson(e as Map<String, dynamic>))
            .toList(),
        rooms: (json['rooms'] as List)
            .map((e) => Room.fromJson(e as Map<String, dynamic>))
            .toList(),
        devices: (json['devices'] as List)
            .map((e) => Device.fromJson(e as Map<String, dynamic>))
            .toList(),
        vehicles: (json['vehicles'] as List)
            .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
            .toList(),
        meshNodes: (json['meshNodes'] as List)
            .map((e) => MeshNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        alerts: (json['alerts'] as List)
            .map((e) => Alert.fromJson(e as Map<String, dynamic>))
            .toList(),
        insights: (json['insights'] as List? ?? [])
            .map((e) => Insight.fromJson(e as Map<String, dynamic>))
            .toList(),
        nowPlaying: json['nowPlaying'] == null
            ? null
            : NowPlaying.fromJson(json['nowPlaying'] as Map<String, dynamic>),
        mediaStats: json['mediaStats'] == null
            ? null
            : MediaLibraryStats.fromJson(
                json['mediaStats'] as Map<String, dynamic>),
        continueWatching: (json['continueWatching'] as List? ?? [])
            .map((e) => ContinueWatchingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        playbackPositions: (json['playbackPositions'] as Map?)
                ?.map((k, v) => MapEntry(k as String, (v as num).toDouble())) ??
            {},
        weather: json['weather'] == null
            ? null
            : WeatherInfo.fromJson(json['weather'] as Map<String, dynamic>),
      );
}
