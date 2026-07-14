import 'enums.dart';

/// A proactive-insight produced by `computeInsights` (Section 6). Only
/// `crit` insights surface as a floating pill on the Home map; everything
/// else lives in the NEXUS AI tab's context and the Security insights feed.
class Insight {
  Insight({
    required this.id,
    required this.level,
    required this.message,
    this.relatedDeviceId,
    this.relatedZoneId,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final String id;
  final Level level;
  final String message;
  final String? relatedDeviceId;
  final String? relatedZoneId;
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level.name,
        'message': message,
        'relatedDeviceId': relatedDeviceId,
        'relatedZoneId': relatedZoneId,
        'time': time.toIso8601String(),
      };

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
        id: json['id'] as String,
        level: Level.values.byName(json['level'] as String),
        message: json['message'] as String,
        relatedDeviceId: json['relatedDeviceId'] as String?,
        relatedZoneId: json['relatedZoneId'] as String?,
        time: DateTime.parse(json['time'] as String),
      );
}
