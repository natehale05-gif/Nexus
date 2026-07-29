import 'endpoint.dart';
import 'enums.dart';

/// Sealed base class for every controllable accessory in the compound.
///
/// A `type` discriminator field (via the subclass + [DeviceType] getter)
/// keeps this friendly to JSON wire encoding for the WebSocket protocol
/// between the Dart server and the Flutter app.
sealed class Device {
  Device({
    required this.id,
    required this.name,
    required this.buildingId,
    this.roomId,
    this.endpoint,
  });

  final String id;
  String name;
  final String buildingId;

  /// Null for accessories that attach directly to a building rather than a
  /// room - this is always the case for [LockDevice]s (locks/gates attach to
  /// the building itself per Section 3/7).
  final String? roomId;

  /// Where the real hardware is, when there is any. Null means the device is
  /// tracked in the compound but not wired to anything - mutations then only
  /// update NEXUS's own state, which is what the demo compound does.
  DeviceEndpoint? endpoint;

  DeviceType get type;

  Map<String, dynamic> toJson();

  static Device fromJson(Map<String, dynamic> json) {
    final type = DeviceType.values.byName(json['type'] as String);
    switch (type) {
      case DeviceType.light:
        return LightDevice.fromJson(json);
      case DeviceType.climate:
        return ClimateDevice.fromJson(json);
      case DeviceType.grill:
        return GrillDevice.fromJson(json);
      case DeviceType.lock:
        return LockDevice.fromJson(json);
      case DeviceType.media:
        return MediaDevice.fromJson(json);
    }
  }
}

class LightDevice extends Device {
  LightDevice({
    required super.id,
    required super.name,
    required super.buildingId,
    super.roomId,
    super.endpoint,
    this.on = false,
    this.brightness = 100,
  });

  bool on;

  /// 0-100.
  int brightness;

  @override
  DeviceType get type => DeviceType.light;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'name': name,
        'buildingId': buildingId,
        'roomId': roomId,
        'endpoint': endpoint?.toJson(),
        'on': on,
        'brightness': brightness,
      };

  factory LightDevice.fromJson(Map<String, dynamic> json) => LightDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        buildingId: json['buildingId'] as String,
        roomId: json['roomId'] as String?,
        endpoint: DeviceEndpoint.fromJson(json['endpoint'] as Map<String, dynamic>?),
        on: json['on'] as bool? ?? false,
        brightness: json['brightness'] as int? ?? 100,
      );
}

class ClimateDevice extends Device {
  ClimateDevice({
    required super.id,
    required super.name,
    required super.buildingId,
    super.roomId,
    super.endpoint,
    this.temp = 68,
    this.set = 70,
    this.mode = ClimateMode.off,
    this.fan = FanMode.auto,
    this.hold,
  });

  /// Current measured temperature (F).
  double temp;

  /// Target/set temperature (F), 55-85 range per the arc dial spec.
  double set;

  ClimateMode mode;
  FanMode fan;

  /// Null => "Follow schedule". Otherwise a short human description, e.g.
  /// "until 6:00 PM", "for 2 hours", "permanently".
  String? hold;

  @override
  DeviceType get type => DeviceType.climate;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'name': name,
        'buildingId': buildingId,
        'roomId': roomId,
        'endpoint': endpoint?.toJson(),
        'temp': temp,
        'set': set,
        'mode': mode.name,
        'fan': fan.name,
        'hold': hold,
      };

  factory ClimateDevice.fromJson(Map<String, dynamic> json) => ClimateDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        buildingId: json['buildingId'] as String,
        roomId: json['roomId'] as String?,
        endpoint: DeviceEndpoint.fromJson(json['endpoint'] as Map<String, dynamic>?),
        temp: (json['temp'] as num?)?.toDouble() ?? 68,
        set: (json['set'] as num?)?.toDouble() ?? 70,
        mode: ClimateMode.values.byName(json['mode'] as String? ?? 'off'),
        fan: FanMode.values.byName(json['fan'] as String? ?? 'auto'),
        hold: json['hold'] as String?,
      );
}

class GrillDevice extends Device {
  GrillDevice({
    required super.id,
    required super.name,
    required super.buildingId,
    super.roomId,
    super.endpoint,
    this.on = false,
    this.temp = 72,
    this.set = 225,
    this.probe,
    this.probeTarget,
    this.pellets = 80,
    this.cloudOnline = true,
  });

  bool on;

  /// Current chamber temp (F).
  double temp;

  /// Target chamber temp (F), 165-500 range.
  double set;

  /// Null until the grill has been running long enough for a probe to be
  /// considered "connected" - see simulated behavior in Section 4.
  double? probe;

  /// Target internal meat temperature, e.g. 203 for pulled pork.
  double? probeTarget;

  /// Hopper level 0-100.
  int pellets;

  /// Whether the cloud/MQTT-over-WSS bridge to the Traeger account is
  /// currently reachable. This is a hard dependency unique to the grill
  /// integration (Section 8) - unlike local WiFi/Zigbee/Z-Wave devices.
  bool cloudOnline;

  @override
  DeviceType get type => DeviceType.grill;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'name': name,
        'buildingId': buildingId,
        'roomId': roomId,
        'endpoint': endpoint?.toJson(),
        'on': on,
        'temp': temp,
        'set': set,
        'probe': probe,
        'probeTarget': probeTarget,
        'pellets': pellets,
        'cloudOnline': cloudOnline,
      };

  factory GrillDevice.fromJson(Map<String, dynamic> json) => GrillDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        buildingId: json['buildingId'] as String,
        roomId: json['roomId'] as String?,
        endpoint: DeviceEndpoint.fromJson(json['endpoint'] as Map<String, dynamic>?),
        on: json['on'] as bool? ?? false,
        temp: (json['temp'] as num?)?.toDouble() ?? 72,
        set: (json['set'] as num?)?.toDouble() ?? 225,
        probe: (json['probe'] as num?)?.toDouble(),
        probeTarget: (json['probeTarget'] as num?)?.toDouble(),
        pellets: json['pellets'] as int? ?? 80,
        cloudOnline: json['cloudOnline'] as bool? ?? true,
      );
}

class LockDevice extends Device {
  LockDevice({
    required super.id,
    required super.name,
    required super.buildingId,
    super.endpoint,
    this.locked = true,
    this.isGate = false,
    this.openSince,
  }) : super(roomId: null);

  bool locked;

  /// True renders "gate" language ("Open"/"Closed") instead of lock
  /// language ("Locked"/"Unlocked") in the UI.
  bool isGate;

  /// When the lock/gate was last opened - lets the insights engine flag
  /// "open longer than expected" per Section 6, rather than just current
  /// state.
  DateTime? openSince;

  @override
  DeviceType get type => DeviceType.lock;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'name': name,
        'buildingId': buildingId,
        'roomId': roomId,
        'endpoint': endpoint?.toJson(),
        'locked': locked,
        'isGate': isGate,
        'openSince': openSince?.toIso8601String(),
      };

  factory LockDevice.fromJson(Map<String, dynamic> json) => LockDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        buildingId: json['buildingId'] as String,
        endpoint: DeviceEndpoint.fromJson(json['endpoint'] as Map<String, dynamic>?),
        locked: json['locked'] as bool? ?? true,
        isGate: json['isGate'] as bool? ?? false,
        openSince: json['openSince'] == null
            ? null
            : DateTime.parse(json['openSince'] as String),
      );
}

class MediaDevice extends Device {
  MediaDevice({
    required super.id,
    required super.name,
    required super.buildingId,
    super.roomId,
    super.endpoint,
    this.on = false,
  });

  bool on;

  @override
  DeviceType get type => DeviceType.media;

  @override
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'id': id,
        'name': name,
        'buildingId': buildingId,
        'roomId': roomId,
        'endpoint': endpoint?.toJson(),
        'on': on,
      };

  factory MediaDevice.fromJson(Map<String, dynamic> json) => MediaDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        buildingId: json['buildingId'] as String,
        roomId: json['roomId'] as String?,
        endpoint: DeviceEndpoint.fromJson(json['endpoint'] as Map<String, dynamic>?),
        on: json['on'] as bool? ?? false,
      );
}
