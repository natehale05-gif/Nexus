import 'package:nexus_server/discovery/discovery_service.dart';
import 'package:nexus_server/discovery/ssdp_discovery.dart';
import 'package:nexus_shared/nexus_shared.dart';
import 'package:test/test.dart';

/// A realistic Sonos M-SEARCH reply.
const _sonosReply = 'HTTP/1.1 200 OK\r\n'
    'CACHE-CONTROL: max-age=1800\r\n'
    'LOCATION: http://192.168.1.40:1400/xml/device_description.xml\r\n'
    'SERVER: Linux UPnP/1.0 Sonos/70.1-12345\r\n'
    'ST: urn:schemas-upnp-org:device:ZonePlayer:1\r\n'
    'USN: uuid:RINCON_ABC123::urn:schemas-upnp-org:device:ZonePlayer:1\r\n'
    '\r\n';

void main() {
  group('SSDP parsing', () {
    test('pulls address, port, service and a readable name', () {
      final device = parseSsdpResponse(_sonosReply, '192.168.1.40')!;
      expect(device.address, '192.168.1.40');
      expect(device.port, 1400);
      expect(device.source, DiscoverySource.ssdp);
      expect(device.serviceType, 'urn:schemas-upnp-org:device:ZonePlayer:1');
      // Not "Linux" or "UPnP" - those are skipped as noise.
      expect(device.name, 'Sonos');
      expect(device.suggestedType, 'media');
    });

    test('ignores replies with no USN, which cannot be de-duplicated', () {
      const noUsn = 'HTTP/1.1 200 OK\r\nST: upnp:rootdevice\r\n\r\n';
      expect(parseSsdpResponse(noUsn, '10.0.0.5'), isNull);
    });

    test('ignores payloads that are not SSDP at all', () {
      expect(parseSsdpResponse('', '10.0.0.5'), isNull);
      expect(parseSsdpResponse('GET / HTTP/1.1\r\n\r\n', '10.0.0.5'), isNull);
    });

    test('accepts unsolicited NOTIFY announcements too', () {
      const notify = 'NOTIFY * HTTP/1.1\r\n'
          'NT: urn:roku-com:device:player:1-0\r\n'
          'USN: uuid:roku:ecp:X1\r\n'
          'SERVER: Roku/12.0.0\r\n'
          '\r\n';
      final device = parseSsdpResponse(notify, '192.168.1.55')!;
      expect(device.id, 'ssdp:uuid:roku:ecp:X1');
      expect(device.suggestedType, 'media');
    });

    test('falls back to the UPnP device class, then the address, for a name', () {
      const bare = 'HTTP/1.1 200 OK\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
          'USN: uuid:x::y\r\n\r\n';
      expect(parseSsdpResponse(bare, '10.0.0.9')!.name, 'MediaRenderer');

      const nameless = 'HTTP/1.1 200 OK\r\nST: upnp:rootdevice\r\nUSN: uuid:z\r\n\r\n';
      expect(parseSsdpResponse(nameless, '10.0.0.9')!.name, '10.0.0.9');
    });
  });

  group('suggestDeviceType', () {
    test('maps the common service types onto NEXUS device types', () {
      expect(suggestDeviceType(serviceType: '_googlecast._tcp'), 'media');
      expect(suggestDeviceType(serviceType: '_airplay._tcp'), 'media');
      expect(suggestDeviceType(model: 'ecobee3 lite'), 'climate');
      expect(suggestDeviceType(model: 'August Smart Lock'), 'lock');
      expect(suggestDeviceType(serviceType: '_hue._tcp'), 'light');
      expect(suggestDeviceType(model: 'Traeger Ironwood'), 'grill');
    });

    test('returns null rather than guessing at something unrecognized', () {
      expect(suggestDeviceType(serviceType: '_ipp._tcp', model: 'Brother HL-L2340'), isNull);
      expect(suggestDeviceType(), isNull);
    });
  });

  group('mergeDiscoveries', () {
    DiscoveredDevice device(
      String id,
      String name,
      String address,
      DiscoverySource source, {
      String? type,
    }) =>
        DiscoveredDevice(
          id: id,
          name: name,
          address: address,
          source: source,
          suggestedType: type,
        );

    test('collapses a device both protocols found, keeping the better name', () {
      final merged = mergeDiscoveries([
        device('ssdp:1', 'Sonos', '192.168.1.40', DiscoverySource.ssdp, type: 'media'),
        device('mdns:1', 'Living Room', '192.168.1.40', DiscoverySource.mdns, type: 'media'),
      ]);
      expect(merged, hasLength(1));
      // The mDNS instance name is the one a person recognizes.
      expect(merged.single.name, 'Living Room');
    });

    test('prefers any real name over a bare address', () {
      final merged = mergeDiscoveries([
        device('mdns:2', '10.0.0.7', '10.0.0.7', DiscoverySource.mdns, type: 'media'),
        device('ssdp:2', 'Roku', '10.0.0.7', DiscoverySource.ssdp, type: 'media'),
      ]);
      expect(merged.single.name, 'Roku');
    });

    test('keeps distinct devices apart', () {
      final merged = mergeDiscoveries([
        device('a', 'TV', '10.0.0.1', DiscoverySource.mdns, type: 'media'),
        device('b', 'Thermostat', '10.0.0.2', DiscoverySource.mdns, type: 'climate'),
      ]);
      expect(merged, hasLength(2));
    });

    test('sorts recognized devices first, then alphabetically', () {
      final merged = mergeDiscoveries([
        device('a', 'Zebra Printer', '10.0.0.1', DiscoverySource.mdns),
        device('b', 'Speaker', '10.0.0.2', DiscoverySource.mdns, type: 'media'),
        device('c', 'Attic Light', '10.0.0.3', DiscoverySource.mdns, type: 'light'),
      ]);
      expect(merged.map((d) => d.name), ['Attic Light', 'Speaker', 'Zebra Printer']);
    });
  });

  test('DiscoveredDevice survives a JSON round trip', () {
    final original = parseSsdpResponse(_sonosReply, '192.168.1.40')!;
    final restored = DiscoveredDevice.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.port, original.port);
    expect(restored.source, DiscoverySource.ssdp);
    expect(restored.suggestedType, 'media');
  });
}
