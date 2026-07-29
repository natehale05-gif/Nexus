import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nexus_shared/nexus_shared.dart';

/// SSDP (the discovery half of UPnP) - how Sonos, Roku, smart TVs and most
/// media renderers announce themselves.
///
/// The protocol is small enough to implement directly: multicast an M-SEARCH
/// to 239.255.255.250:1900 and collect the HTTP-shaped unicast replies. No
/// package needed, and hand-rolling keeps the parsing testable without a
/// network.
class SsdpDiscovery {
  static const _address = '239.255.255.250';
  static const _port = 1900;

  /// Broadcasts an M-SEARCH and gathers replies until [timeout] elapses.
  ///
  /// `MX:2` asks devices to stagger their responses over 2 seconds so a busy
  /// network doesn't answer in one burst and drop packets; the listen window
  /// has to outlast it, hence the 4s default.
  Future<List<DiscoveredDevice>> scan({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final found = <String, DiscoveredDevice>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final search = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: $_address:$_port\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: ssdp:all\r\n'
          '\r\n';

      final done = Completer<void>();
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket!.receive();
        if (datagram == null) return;
        try {
          final device = parseSsdpResponse(
            utf8.decode(datagram.data, allowMalformed: true),
            datagram.address.address,
          );
          if (device != null) found[device.id] = device;
        } catch (_) {
          // One malformed reply shouldn't end the scan.
        }
      }, onError: (_) {});

      socket.send(utf8.encode(search), InternetAddress(_address), _port);
      Timer(timeout, () {
        if (!done.isCompleted) done.complete();
      });
      await done.future;
    } on SocketException {
      // No network, or multicast is blocked (common in containers). An empty
      // result is the honest answer - the caller reports "nothing found"
      // rather than surfacing a crash.
    } finally {
      socket?.close();
    }
    return found.values.toList();
  }
}

/// Parses an SSDP reply into a [DiscoveredDevice], or null if it isn't one.
///
/// Split out from the socket work so the header handling can be tested
/// directly against captured payloads.
DiscoveredDevice? parseSsdpResponse(String payload, String address) {
  final lines = payload.split(RegExp(r'\r?\n'));
  if (lines.isEmpty) return null;
  // Both the M-SEARCH reply and unsolicited NOTIFY announcements are useful.
  final start = lines.first.toUpperCase();
  if (!start.startsWith('HTTP/1.1 200') && !start.startsWith('NOTIFY')) return null;

  final headers = <String, String>{};
  for (final line in lines.skip(1)) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    headers[line.substring(0, colon).trim().toUpperCase()] =
        line.substring(colon + 1).trim();
  }

  // USN is the unique service name and the only stable identifier here;
  // without it, repeated scans would produce duplicate entries.
  final usn = headers['USN'];
  if (usn == null || usn.isEmpty) return null;

  final serviceType = headers['ST'] ?? headers['NT'];
  final server = headers['SERVER'];
  final location = headers['LOCATION'];

  int? port;
  if (location != null) {
    port = Uri.tryParse(location)?.port;
    if (port == 0) port = null;
  }

  return DiscoveredDevice(
    id: 'ssdp:$usn',
    name: _friendlyName(usn, serviceType, server, address),
    address: address,
    port: port,
    source: DiscoverySource.ssdp,
    serviceType: serviceType,
    model: server,
    suggestedType: suggestDeviceType(serviceType: serviceType, model: server),
  );
}

/// SSDP has no dedicated name field, so build the most human thing available
/// out of what it does send.
String _friendlyName(String usn, String? serviceType, String? server, String address) {
  // Many devices put a readable product string in SERVER, e.g.
  // "Linux/4.4 UPnP/1.0 Sonos/70.1-12345".
  if (server != null) {
    for (final token in server.split(RegExp(r'[\s,]+'))) {
      final slash = token.indexOf('/');
      final word = slash == -1 ? token : token.substring(0, slash);
      if (word.length < 3) continue;
      final lower = word.toLowerCase();
      if (lower == 'upnp' || lower == 'linux' || lower == 'windows') continue;
      return word;
    }
  }
  if (serviceType != null && serviceType.contains(':')) {
    final parts = serviceType.split(':');
    // urn:schemas-upnp-org:device:MediaRenderer:1 -> MediaRenderer
    if (parts.length >= 4 && parts[3].isNotEmpty) return parts[3];
  }
  return address;
}
