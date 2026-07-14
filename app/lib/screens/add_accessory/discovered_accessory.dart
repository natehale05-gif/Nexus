import 'package:nexus_shared/nexus_shared.dart';

/// A simulated discovery-scan result (Section 7, step 2). Real build:
/// mDNS/WiFi + Zigbee2MQTT/Z-Wave JS UI discovery bridged by the server.
class DiscoveredAccessory {
  const DiscoveredAccessory({
    required this.name,
    required this.protocol,
    required this.type,
    required this.signalDbm,
  });

  final String name;
  final AccessoryProtocol protocol;
  final DeviceType type;
  final int signalDbm;

  String get protocolLabel {
    switch (protocol) {
      case AccessoryProtocol.wifi:
        return 'WiFi';
      case AccessoryProtocol.zigbee:
        return 'Zigbee';
      case AccessoryProtocol.zwave:
        return 'Z-Wave';
      case AccessoryProtocol.mesh:
        return 'Mesh';
      case AccessoryProtocol.cloud:
        return 'Cloud';
    }
  }

  String get signalLabel {
    if (signalDbm >= -50) return 'Excellent';
    if (signalDbm >= -65) return 'Good';
    return 'Fair';
  }
}

const demoDiscoveredAccessories = [
  DiscoveredAccessory(name: 'Traeger Ironwood 885', protocol: AccessoryProtocol.wifi, type: DeviceType.grill, signalDbm: -48),
  DiscoveredAccessory(name: 'Shelly Plug · Porch Light', protocol: AccessoryProtocol.wifi, type: DeviceType.light, signalDbm: -52),
  DiscoveredAccessory(name: 'Sengled Bulb · Hallway', protocol: AccessoryProtocol.zigbee, type: DeviceType.light, signalDbm: -61),
  DiscoveredAccessory(name: 'Z-Wave Thermostat · Guest Room', protocol: AccessoryProtocol.zwave, type: DeviceType.climate, signalDbm: -58),
  DiscoveredAccessory(name: 'Zigbee Contact Sensor · Side Door', protocol: AccessoryProtocol.zigbee, type: DeviceType.lock, signalDbm: -67),
  DiscoveredAccessory(name: 'Apple TV · Loft', protocol: AccessoryProtocol.wifi, type: DeviceType.media, signalDbm: -44),
];
