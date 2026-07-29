/// How a device announced itself on the network.
enum DiscoverySource {
  /// mDNS / DNS-SD (Bonjour). Chromecast, AirPlay, HomeKit, Ollama, printers.
  mdns,

  /// SSDP / UPnP. Sonos, Roku, smart TVs, media renderers, routers.
  ssdp,
}

/// A device seen on the network that isn't in the compound yet.
///
/// Deliberately protocol-agnostic: the discovery backends normalize whatever
/// they found into this, so the app can list "things on your network" without
/// knowing anything about DNS records or SSDP headers.
class DiscoveredDevice {
  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.source,
    this.port,
    this.serviceType,
    this.model,
    this.manufacturer,
    this.suggestedType,
  });

  /// Stable across scans for the same physical device, so the UI can tell
  /// "already seen" from "new" without flickering.
  final String id;

  final String name;
  final String address;
  final int? port;
  final DiscoverySource source;

  /// e.g. `_googlecast._tcp` or a UPnP device type URN.
  final String? serviceType;

  final String? model;
  final String? manufacturer;

  /// Best guess at which NEXUS device type this maps to (`light`, `media`,
  /// ...), or null when the announcement isn't specific enough to say. A
  /// guess, not a claim - the user confirms before anything is added.
  final String? suggestedType;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'port': port,
        'source': source.name,
        'serviceType': serviceType,
        'model': model,
        'manufacturer': manufacturer,
        'suggestedType': suggestedType,
      };

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) => DiscoveredDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        port: json['port'] as int?,
        source: DiscoverySource.values.byName(json['source'] as String),
        serviceType: json['serviceType'] as String?,
        model: json['model'] as String?,
        manufacturer: json['manufacturer'] as String?,
        suggestedType: json['suggestedType'] as String?,
      );
}

/// Maps a discovered service/model onto a NEXUS device type.
///
/// Kept in `shared/` so the server and the app agree, and so it's testable
/// without a network. Returns null rather than guessing wildly - an unknown
/// device still gets listed, it just doesn't pre-select a type.
String? suggestDeviceType({String? serviceType, String? model, String? manufacturer}) {
  final haystack = [serviceType, model, manufacturer]
      .whereType<String>()
      .join(' ')
      .toLowerCase();
  if (haystack.isEmpty) return null;

  bool has(List<String> needles) => needles.any(haystack.contains);

  // Media renderers and speakers.
  if (has([
    '_googlecast',
    '_airplay',
    '_raop', // AirPlay audio
    '_spotify-connect',
    '_sonos',
    'mediarenderer',
    'roku',
    'chromecast',
    'appletv',
    'sonos',
    'shield',
  ])) {
    return 'media';
  }
  // Thermostats.
  if (has(['ecobee', 'thermostat', 'nest', 'honeywell'])) return 'climate';
  // Locks and gates.
  if (has(['lock', 'august', 'schlage', 'yale', 'garage', 'gate'])) return 'lock';
  // Lights and bridges that mostly mean lights.
  if (has(['hue', '_hue._tcp', 'lifx', 'nanoleaf', 'wled', 'light'])) return 'light';
  // Grills.
  if (has(['traeger', 'grill', 'smoker'])) return 'grill';
  return null;
}
