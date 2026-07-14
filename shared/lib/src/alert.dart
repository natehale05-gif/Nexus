import 'enums.dart';

/// A Security-tab alert (Section 5) - camera motion, sensor trip, etc.
/// Distinct from [Insight] which is the compound-wide proactive-insights
/// feed (Section 6); alerts are Frigate/UniFi-sourced security events.
class Alert {
  Alert({
    required this.id,
    required this.level,
    required this.source,
    required this.message,
    required this.time,
  });

  final String id;
  Level level;
  String source;
  String message;
  DateTime time;

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level.name,
        'source': source,
        'message': message,
        'time': time.toIso8601String(),
      };

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as String,
        level: Level.values.byName(json['level'] as String),
        source: json['source'] as String,
        message: json['message'] as String,
        time: DateTime.parse(json['time'] as String),
      );
}
