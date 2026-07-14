import 'enums.dart';

/// A vehicle pin on the Home map. Vehicles are separate from zones/buildings
/// and only ever show a status card - they have no controls (Section 3).
class Vehicle {
  Vehicle({
    required this.id,
    required this.name,
    required this.status,
    required this.locationDescription,
    required this.batteryPercent,
    required this.mapX,
    required this.mapY,
  });

  final String id;
  String name;
  VehicleStatus status;
  String locationDescription;
  int batteryPercent;
  double mapX;
  double mapY;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'locationDescription': locationDescription,
        'batteryPercent': batteryPercent,
        'mapX': mapX,
        'mapY': mapY,
      };

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        name: json['name'] as String,
        status: VehicleStatus.values.byName(json['status'] as String),
        locationDescription: json['locationDescription'] as String,
        batteryPercent: json['batteryPercent'] as int,
        mapX: (json['mapX'] as num).toDouble(),
        mapY: (json['mapY'] as num).toDouble(),
      );
}
