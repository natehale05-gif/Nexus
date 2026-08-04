import 'map_position.dart';

/// A room inside a [Building]. Devices reference rooms by id; rooms don't
/// hold device objects directly so the compound's device list stays the
/// single source of truth.
class Room {
  Room({
    required this.id,
    required this.buildingId,
    required this.name,
  });

  final String id;
  final String buildingId;
  String name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'buildingId': buildingId,
        'name': name,
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        buildingId: json['buildingId'] as String,
        name: json['name'] as String,
      );
}

/// A physical building on the compound, e.g. `main`, `barn`, `shop`,
/// `cabin`, `gn` (North Gate), `ge` (East Gate).
class Building {
  Building({
    required this.id,
    required this.name,
    required this.zoneId,
    this.meshNodeId,
  });

  final String id;
  String name;
  final String zoneId;

  /// Id of the [MeshNode] that maps to this building, if any (Section 3,
  /// Building view node-health line).
  String? meshNodeId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'zoneId': zoneId,
        'meshNodeId': meshNodeId,
      };

  factory Building.fromJson(Map<String, dynamic> json) => Building(
        id: json['id'] as String,
        name: json['name'] as String,
        zoneId: json['zoneId'] as String,
        meshNodeId: json['meshNodeId'] as String?,
      );
}

/// A geographic/logical grouping of buildings shown as a single pin on the
/// Home map (Section 3) - e.g. the Gates zone covers both `gn` and `ge`.
class Zone {
  Zone({
    required this.id,
    required this.name,
    required this.buildingIds,
    required this.mapX,
    required this.mapY,
    this.primaryBuildingId,
  });

  final String id;
  String name;
  List<String> buildingIds;

  /// Normalized (0.0-1.0) position on the map canvas.
  double mapX;
  double mapY;

  /// Puts this zone somewhere, keeping it on the canvas.
  ///
  /// Clamped rather than rejected: a drag that ends past the edge means "as
  /// far over as it goes", not "cancel the move". The inset keeps the pin's
  /// own label from being half off-screen, which is what happens at a true
  /// 0 or 1.
  void moveTo(double x, double y) {
    mapX = clampMapPosition(x);
    mapY = clampMapPosition(y);
  }

  /// Which building the long-press "jump straight to full-screen building
  /// view" gesture opens (Section 3). Defaults to the first building.
  String? primaryBuildingId;

  String get resolvedPrimaryBuildingId =>
      primaryBuildingId ?? buildingIds.first;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'buildingIds': buildingIds,
        'mapX': mapX,
        'mapY': mapY,
        'primaryBuildingId': primaryBuildingId,
      };

  factory Zone.fromJson(Map<String, dynamic> json) => Zone(
        id: json['id'] as String,
        name: json['name'] as String,
        buildingIds: (json['buildingIds'] as List).cast<String>(),
        mapX: (json['mapX'] as num).toDouble(),
        mapY: (json['mapY'] as num).toDouble(),
        primaryBuildingId: json['primaryBuildingId'] as String?,
      );
}
