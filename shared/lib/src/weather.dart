/// Minimal weather snapshot fed into the NEXUS AI system-prompt context
/// (Section 5).
class WeatherInfo {
  WeatherInfo({
    required this.tempF,
    required this.condition,
    required this.highF,
    required this.lowF,
  });

  double tempF;
  String condition;
  double highF;
  double lowF;

  Map<String, dynamic> toJson() => {
        'tempF': tempF,
        'condition': condition,
        'highF': highF,
        'lowF': lowF,
      };

  factory WeatherInfo.fromJson(Map<String, dynamic> json) => WeatherInfo(
        tempF: (json['tempF'] as num).toDouble(),
        condition: json['condition'] as String,
        highF: (json['highF'] as num).toDouble(),
        lowF: (json['lowF'] as num).toDouble(),
      );
}
