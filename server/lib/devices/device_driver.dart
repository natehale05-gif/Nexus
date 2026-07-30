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

  /// Like [send], but returns the response body - used for status reads.
  /// Null means unreachable or a non-2xx reply, which the poller treats as
  /// "no reading" rather than as a state change.
  Future<String?> fetch(DeviceRequest request) async {
    try {
      final http = await _client.openUrl(request.method, request.uri);
      final response = await http.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        return null;
      }
      return await response.transform(const Utf8Decoder(allowMalformed: true)).join();
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close(force: true);
}

/// What a device reports about itself. Null fields mean "this protocol didn't
/// tell us", which is different from a known value - a relay with no dimmer
/// reports no brightness at all.
class DeviceState {
  const DeviceState({this.on, this.brightness});

  final bool? on;
  final int? brightness;

  @override
  String toString() => 'DeviceState(on: $on, brightness: $brightness)';
}

/// Builds the request that asks a device what state it's actually in.
DeviceRequest buildStatusRequest(DeviceEndpoint endpoint) {
  final host = endpoint.host;
  final channel = endpoint.channel;
  return switch (endpoint.protocol) {
    // One /status covers relays and dimmers on gen1.
    DeviceProtocol.shellyGen1 =>
      DeviceRequest(method: 'GET', uri: Uri.parse('http://$host/status')),
    // Light.GetStatus also answers for plain switches on gen2, and carries
    // brightness when the device has a dimmer.
    DeviceProtocol.shellyGen2 => DeviceRequest(
        method: 'GET',
        uri: Uri.parse('http://$host/rpc/Shelly.GetStatus?id=$channel'),
      ),
    DeviceProtocol.tasmota => DeviceRequest(
        method: 'GET',
        uri: Uri.parse('http://$host/cm').replace(queryParameters: {'cmnd': 'State'}),
      ),
    DeviceProtocol.wled =>
      DeviceRequest(method: 'GET', uri: Uri.parse('http://$host/json/state')),
  };
}

/// Parses a status response into a [DeviceState].
///
/// Pure so every vendor's JSON shape can be tested against captured payloads -
/// these differ more than the control endpoints do, and getting one wrong
/// means the UI quietly reports the opposite of reality.
DeviceState? parseStatusResponse(DeviceEndpoint endpoint, String body) {
  try {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return null;
    final channel = endpoint.channel;

    switch (endpoint.protocol) {
      case DeviceProtocol.shellyGen1:
        // Dimmers report under `lights`, plain relays under `relays`.
        final lights = json['lights'] as List<dynamic>?;
        if (lights != null && channel < lights.length) {
          final light = lights[channel] as Map<String, dynamic>;
          return DeviceState(
            on: light['ison'] as bool?,
            brightness: (light['brightness'] as num?)?.round(),
          );
        }
        final relays = json['relays'] as List<dynamic>?;
        if (relays != null && channel < relays.length) {
          return DeviceState(on: (relays[channel] as Map<String, dynamic>)['ison'] as bool?);
        }
        return null;

      case DeviceProtocol.shellyGen2:
        // Gen2 keys components as "switch:0" / "light:0".
        for (final prefix in ['light', 'switch']) {
          final component = json['$prefix:$channel'];
          if (component is Map<String, dynamic>) {
            return DeviceState(
              on: component['output'] as bool?,
              brightness: (component['brightness'] as num?)?.round(),
            );
          }
        }
        return null;

      case DeviceProtocol.tasmota:
        // Tasmota reports POWER for output 1 and POWER2.. beyond it.
        final key = channel == 0 ? 'POWER' : 'POWER${channel + 1}';
        final power = json[key] ?? json['POWER'];
        if (power == null) return null;
        return DeviceState(
          on: '$power'.toUpperCase() == 'ON',
          brightness: (json['Dimmer'] as num?)?.round(),
        );

      case DeviceProtocol.wled:
        final bri = (json['bri'] as num?)?.toDouble();
        return DeviceState(
          on: json['on'] as bool?,
          // Back from WLED's 0-255 to the 0-100 NEXUS uses everywhere else.
          brightness: bri == null ? null : (bri * 100 / 255).round(),
        );
    }
  } catch (_) {
    // Unparseable payload - treat as "no reading" rather than guessing.
    return null;
  }
}
