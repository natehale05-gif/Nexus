import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';
import 'package:nexus_shared/nexus_shared.dart';

/// mDNS / DNS-SD (Bonjour) discovery.
///
/// Covers the half of the smart-home world that doesn't speak SSDP:
/// Chromecast, AirPlay, HomeKit accessories, Hue bridges, printers, and a
/// self-hosted Ollama. Uses the Dart team's `multicast_dns` rather than
/// hand-rolling DNS record parsing - unlike SSDP's plain-text headers, mDNS
/// is real binary DNS and not worth reimplementing.
class MdnsDiscovery {
  /// Service types worth asking about. DNS-SD has no "list everything" query
  /// that all stacks answer reliably, so this enumerates the types that map
  /// onto something NEXUS can actually control, plus the generic `_http`
  /// catch-all a lot of hardware advertises.
  static const serviceTypes = <String>[
    '_googlecast._tcp',
    '_airplay._tcp',
    '_raop._tcp', // AirPlay audio
    '_spotify-connect._tcp',
    '_sonos._tcp',
    '_hap._tcp', // HomeKit accessories
    '_hue._tcp',
    '_ipp._tcp', // printers
    '_ollama._tcp',
    '_http._tcp',
  ];

  Future<List<DiscoveredDevice>> scan({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final found = <String, DiscoveredDevice>{};
    final client = MDnsClient();
    try {
      await client.start();
      for (final type in serviceTypes) {
        await _scanType(client, type, timeout, found);
      }
    } on SocketException {
      // Multicast unavailable (containers, restrictive networks). Same
      // reasoning as SSDP: an empty list is the honest answer.
    } catch (_) {
      // Never let a discovery failure take down the request.
    } finally {
      client.stop();
    }
    return found.values.toList();
  }

  Future<void> _scanType(
    MDnsClient client,
    String type,
    Duration timeout,
    Map<String, DiscoveredDevice> found,
  ) async {
    // Budget the timeout across service types so a full scan stays bounded
    // rather than taking timeout * serviceTypes.length.
    final perType = Duration(
      milliseconds: (timeout.inMilliseconds / serviceTypes.length).round().clamp(200, 2000),
    );
    final ptrStream = client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer('$type.local'),
      timeout: perType,
    );

    await for (final ptr in ptrStream) {
      try {
        await for (final srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
          timeout: perType,
        )) {
          String? address;
          await for (final ip in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
            timeout: perType,
          )) {
            address = ip.address.address;
            break;
          }
          if (address == null) continue;

          // "Living Room TV._googlecast._tcp.local" -> "Living Room TV"
          final instance = ptr.domainName.split('.$type').first;
          final name = instance.replaceAll(r'\032', ' ').trim();

          final device = DiscoveredDevice(
            id: 'mdns:${ptr.domainName}',
            name: name.isEmpty ? srv.target : name,
            address: address,
            port: srv.port,
            source: DiscoverySource.mdns,
            serviceType: type,
            suggestedType: suggestDeviceType(serviceType: type, model: name),
          );
          found[device.id] = device;
        }
      } catch (_) {
        // Skip this record, keep scanning the rest.
      }
    }
  }
}
