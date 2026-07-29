import 'package:nexus_shared/nexus_shared.dart';

import 'mdns_discovery.dart';
import 'ssdp_discovery.dart';

/// Runs both discovery backends and merges the results.
///
/// Discovery lives on the server rather than in the app on purpose: the
/// server sits on the LAN permanently, while the app is often remote over
/// Tailscale (where multicast doesn't reach) or on web (where raw UDP isn't
/// available at all). Scanning here means "find devices" works from any
/// paired device, not just one physically on the network.
class DiscoveryService {
  DiscoveryService({MdnsDiscovery? mdns, SsdpDiscovery? ssdp})
      : _mdns = mdns ?? MdnsDiscovery(),
        _ssdp = ssdp ?? SsdpDiscovery();

  final MdnsDiscovery _mdns;
  final SsdpDiscovery _ssdp;

  /// Scans both protocols concurrently - they're independent, and running
  /// them in series would double the wait for no benefit.
  Future<List<DiscoveredDevice>> scan({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final results = await Future.wait([
      _mdns.scan(timeout: timeout),
      _ssdp.scan(timeout: timeout),
    ]);
    return mergeDiscoveries(results.expand((list) => list));
  }
}

/// Collapses devices that both protocols found, and sorts for stable display.
///
/// A Sonos speaker answers mDNS *and* SSDP, so without this the list shows it
/// twice with different names. Same address plus same suggested type is the
/// signal - keeping the entry with the more useful name.
List<DiscoveredDevice> mergeDiscoveries(Iterable<DiscoveredDevice> devices) {
  final byKey = <String, DiscoveredDevice>{};
  for (final device in devices) {
    final key = '${device.address}|${device.suggestedType ?? ''}';
    final existing = byKey[key];
    if (existing == null || _betterName(device, existing)) {
      byKey[key] = device;
    }
  }
  final merged = byKey.values.toList()
    ..sort((a, b) {
      // Devices we can map to a NEXUS type first - those are the actionable
      // ones - then alphabetically so the list doesn't reshuffle per scan.
      final aTyped = a.suggestedType != null ? 0 : 1;
      final bTyped = b.suggestedType != null ? 0 : 1;
      if (aTyped != bTyped) return aTyped - bTyped;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return merged;
}

/// An mDNS instance name ("Living Room TV") beats an SSDP-derived one
/// ("Sonos", or a bare IP), so prefer it when both protocols saw the device.
bool _betterName(DiscoveredDevice candidate, DiscoveredDevice existing) {
  final existingIsAddress = existing.name == existing.address;
  final candidateIsAddress = candidate.name == candidate.address;
  if (existingIsAddress && !candidateIsAddress) return true;
  if (candidateIsAddress) return false;
  if (candidate.source == DiscoverySource.mdns &&
      existing.source == DiscoverySource.ssdp) {
    return true;
  }
  return false;
}
