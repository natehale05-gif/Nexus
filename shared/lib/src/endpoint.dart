/// Local-HTTP protocols NEXUS can actually drive.
///
/// All of these expose an unauthenticated HTTP API on the LAN, which is why
/// they're the realistic starting set: no cloud account, no vendor OAuth, no
/// key extraction. Zigbee/Z-Wave devices reach NEXUS through a hub that
/// itself speaks one of these.
enum DeviceProtocol {
  /// Shelly gen1 firmware: `/relay/0?turn=on`, `/light/0?brightness=50`.
  shellyGen1,

  /// Shelly gen2+ (Plus/Pro) RPC: `/rpc/Switch.Set?id=0&on=true`.
  shellyGen2,

  /// Tasmota: `/cm?cmnd=Power%20On`, `/cm?cmnd=Dimmer%2050`.
  tasmota,

  /// WLED JSON API: `POST /json/state {"on":true,"bri":128}`.
  wled,
}

/// Where a device physically lives, so a model mutation can become a real
/// request. Null on a device that's tracked but not wired to anything - the
/// UI still shows it, it just doesn't claim to control hardware.
class DeviceEndpoint {
  const DeviceEndpoint({
    required this.protocol,
    required this.host,
    this.channel = 0,
  });

  final DeviceProtocol protocol;

  /// Host or `host:port`. No scheme - these are all plain HTTP on the LAN.
  final String host;

  /// Which relay/output on a multi-channel device (a Shelly 2PM has two).
  final int channel;

  Map<String, dynamic> toJson() => {
        'protocol': protocol.name,
        'host': host,
        'channel': channel,
      };

  static DeviceEndpoint? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final protocol = json['protocol'] as String?;
    final host = json['host'] as String?;
    if (protocol == null || host == null || host.isEmpty) return null;
    for (final candidate in DeviceProtocol.values) {
      if (candidate.name == protocol) {
        return DeviceEndpoint(
          protocol: candidate,
          host: host,
          channel: json['channel'] as int? ?? 0,
        );
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceEndpoint &&
      other.protocol == protocol &&
      other.host == host &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(protocol, host, channel);
}
