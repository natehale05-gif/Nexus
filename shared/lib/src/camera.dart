/// A security camera on the compound.
///
/// Cameras are configured server-side (see `NEXUS_CAMERAS` in
/// `server/lib/config.dart`) and pushed to every client as part of the
/// compound, so the app renders whatever the server actually has rather
/// than a hardcoded list.
class Camera {
  Camera({
    required this.id,
    required this.name,
    this.buildingId,
    this.streamUrl,
    this.hasMotion = false,
  });

  final String id;
  final String name;

  /// Which building this camera watches, when it maps to one.
  final String? buildingId;

  /// A browser/player-playable stream URL (HLS `.m3u8` is the portable
  /// choice - see the README on putting go2rtc in front of RTSP cameras).
  /// Null means the camera is known but has no playable stream configured,
  /// and the app shows an honest "no stream configured" state instead of a
  /// dead tile.
  final String? streamUrl;

  bool hasMotion;

  bool get isStreamable => (streamUrl ?? '').isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'buildingId': buildingId,
        'streamUrl': streamUrl,
        'hasMotion': hasMotion,
      };

  factory Camera.fromJson(Map<String, dynamic> json) => Camera(
        id: json['id'] as String,
        name: json['name'] as String,
        buildingId: json['buildingId'] as String?,
        streamUrl: json['streamUrl'] as String?,
        hasMotion: json['hasMotion'] as bool? ?? false,
      );
}
