/// A Meshtastic LoRa mesh node (Section 8). Powers the red offline badge on
/// zone pins and the node-health line in the Building view.
class MeshNode {
  MeshNode({
    required this.id,
    required this.name,
    this.buildingId,
    this.online = true,
    this.batteryPercent = 100,
  });

  final String id;
  String name;
  String? buildingId;
  bool online;
  int batteryPercent;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'buildingId': buildingId,
        'online': online,
        'batteryPercent': batteryPercent,
      };

  factory MeshNode.fromJson(Map<String, dynamic> json) => MeshNode(
        id: json['id'] as String,
        name: json['name'] as String,
        buildingId: json['buildingId'] as String?,
        online: json['online'] as bool? ?? true,
        batteryPercent: json['batteryPercent'] as int? ?? 100,
      );
}
