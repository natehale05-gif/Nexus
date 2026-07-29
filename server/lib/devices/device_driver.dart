import 'dart:convert';
import 'dart:io';

import 'package:nexus_shared/nexus_shared.dart';

/// One HTTP call to a device. Split out from the sending so URL and body
/// construction can be unit-tested without a device on the bench - which is
/// the whole difficulty with hardware integrations.
class DeviceRequest {
  const DeviceRequest({required this.method, required this.uri, this.body});

  final String method;
  final Uri uri;
  final String? body;

  @override
  String toString() => '$method $uri${body == null ? '' : ' $body'}';
}

/// Builds the request that turns a device on or off.
///
/// Returns null when the endpoint can't express the command (there's no
/// on/off for a thermostat here), so callers can tell "nothing to send" from
/// "send failed".
DeviceRequest? buildPowerRequest(DeviceEndpoint endpoint, bool on) {
  final host = endpoint.host;
  final channel = endpoint.channel;
  return switch (endpoint.protocol) {
    DeviceProtocol.shellyGen1 =>
      DeviceRequest(method: 'GET', uri: Uri.parse('http://$host/relay/$channel?turn=${on ? 'on' : 'off'}')),
    // Gen2 is JSON-RPC over GET query params; `id` selects the switch.
    DeviceProtocol.shellyGen2 => DeviceRequest(
        method: 'GET',
        uri: Uri.parse('http://$host/rpc/Switch.Set?id=$channel&on=$on'),
      ),
    // Tasmota indexes outputs from 1, and bare `Power` means output 1.
    DeviceProtocol.tasmota => DeviceRequest(
        method: 'GET',
        uri: Uri.parse('http://$host/cm').replace(queryParameters: {
          'cmnd': 'Power${channel == 0 ? '' : channel + 1} ${on ? 'On' : 'Off'}',
        }),
      ),
    DeviceProtocol.wled => DeviceRequest(
        method: 'POST',
        uri: Uri.parse('http://$host/json/state'),
        body: jsonEncode({'on': on}),
      ),
  };
}

/// Builds the request that sets brightness, given a NEXUS 0-100 percentage.
///
/// The scales genuinely differ: Shelly and Tasmota take 0-100, WLED takes
/// 0-255. Converting here rather than at the call site keeps the percentage
/// the single representation everywhere else in the app.
DeviceRequest? buildBrightnessRequest(DeviceEndpoint endpoint, int percent) {
  final clamped = percent.clamp(0, 100);
  final host = endpoint.host;
  final channel = endpoint.channel;
  return switch (endpoint.protocol) {
    // 0% would leave a dimmer on at its floor, so treat it as off.
    DeviceProtocol.shellyGen1 => DeviceRequest(
        method: 'GET',
        uri: Uri.parse(
          'http://$host/light/$channel?turn=${clamped == 0 ? 'off' : 'on'}&brightness=$clamped',
        ),
      ),
    DeviceProtocol.shellyGen2 => DeviceRequest(
        method: 'GET',
        uri: Uri.parse('http://$host/rpc/Light.Set?id=$channel'
            '&on=${clamped > 0}&brightness=$clamped'),
      ),
    DeviceProtocol.tasmota => DeviceRequest(
        method: 'GET',
        uri: Uri.parse('http://$host/cm').replace(queryParameters: {'cmnd': 'Dimmer $clamped'}),
      ),
    DeviceProtocol.wled => DeviceRequest(
        method: 'POST',
        uri: Uri.parse('http://$host/json/state'),
        // WLED's brightness is 0-255; round-trip 100% to exactly 255.
        body: jsonEncode({'on': clamped > 0, 'bri': (clamped * 255 / 100).round()}),
      ),
  };
}

/// Sends [DeviceRequest]s. Kept tiny and separate so the request-building
/// logic above stays free of I/O.
class DeviceDriver {
  DeviceDriver({HttpClient? client, this.timeout = const Duration(seconds: 4)})
      : _client = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 3));

  final HttpClient _client;
  final Duration timeout;

  /// Returns true if the device accepted the command.
  ///
  /// A device being unreachable is expected, not exceptional - it might be
  /// unplugged. The caller keeps NEXUS's own state either way, so the UI
  /// stays responsive and the next poll reconciles.
  Future<bool> send(DeviceRequest request) async {
    try {
      final http = await _client.openUrl(request.method, request.uri);
      if (request.body != null) {
        http.headers.contentType = ContentType.json;
        http.write(request.body);
      }
      final response = await http.close().timeout(timeout);
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  void close() => _client.close(force: true);
}
