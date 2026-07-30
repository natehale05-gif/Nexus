import 'dart:convert';
import 'dart:io';

import 'package:nexus_server/devices/device_driver.dart';
import 'package:nexus_server/state/server_compound.dart';
import 'package:nexus_shared/nexus_shared.dart';
import 'package:test/test.dart';

DeviceEndpoint endpoint(DeviceProtocol protocol, {int channel = 0}) =>
    DeviceEndpoint(protocol: protocol, host: '192.168.1.50', channel: channel);

void main() {
  group('power requests', () {
    test('Shelly gen1 uses the relay endpoint', () {
      final on = buildPowerRequest(endpoint(DeviceProtocol.shellyGen1), true)!;
      expect(on.method, 'GET');
      expect(on.uri.toString(), 'http://192.168.1.50/relay/0?turn=on');
      final off = buildPowerRequest(endpoint(DeviceProtocol.shellyGen1), false)!;
      expect(off.uri.toString(), 'http://192.168.1.50/relay/0?turn=off');
    });

    test('Shelly gen2 uses the RPC endpoint', () {
      final request = buildPowerRequest(endpoint(DeviceProtocol.shellyGen2), true)!;
      expect(request.uri.toString(), 'http://192.168.1.50/rpc/Switch.Set?id=0&on=true');
    });

    test('channel selects the right output on multi-relay hardware', () {
      expect(
        buildPowerRequest(endpoint(DeviceProtocol.shellyGen1, channel: 1), true)!.uri.path,
        '/relay/1',
      );
      // Tasmota indexes outputs from 1, so channel 0 is bare "Power".
      expect(
        buildPowerRequest(endpoint(DeviceProtocol.tasmota), true)!.uri.queryParameters['cmnd'],
        'Power On',
      );
      expect(
        buildPowerRequest(endpoint(DeviceProtocol.tasmota, channel: 1), true)!
            .uri
            .queryParameters['cmnd'],
        'Power2 On',
      );
    });

    test('WLED posts JSON rather than using query params', () {
      final request = buildPowerRequest(endpoint(DeviceProtocol.wled), true)!;
      expect(request.method, 'POST');
      expect(request.uri.toString(), 'http://192.168.1.50/json/state');
      expect(jsonDecode(request.body!), {'on': true});
    });
  });

  group('brightness requests', () {
    test('Shelly and Tasmota take a 0-100 percentage unchanged', () {
      expect(
        buildBrightnessRequest(endpoint(DeviceProtocol.shellyGen1), 40)!.uri.query,
        contains('brightness=40'),
      );
      expect(
        buildBrightnessRequest(endpoint(DeviceProtocol.tasmota), 40)!.uri.queryParameters['cmnd'],
        'Dimmer 40',
      );
    });

    test('WLED is rescaled to 0-255, with 100% landing exactly on 255', () {
      expect(jsonDecode(buildBrightnessRequest(endpoint(DeviceProtocol.wled), 100)!.body!),
          {'on': true, 'bri': 255});
      expect(jsonDecode(buildBrightnessRequest(endpoint(DeviceProtocol.wled), 50)!.body!),
          {'on': true, 'bri': 128});
    });

    test('0% turns the light off instead of leaving it at its dimmer floor', () {
      expect(
        buildBrightnessRequest(endpoint(DeviceProtocol.shellyGen1), 0)!.uri.query,
        contains('turn=off'),
      );
      expect(
        jsonDecode(buildBrightnessRequest(endpoint(DeviceProtocol.wled), 0)!.body!)['on'],
        false,
      );
    });

    test('out-of-range percentages are clamped, not passed through', () {
      expect(
        buildBrightnessRequest(endpoint(DeviceProtocol.tasmota), 150)!.uri.queryParameters['cmnd'],
        'Dimmer 100',
      );
      expect(
        buildBrightnessRequest(endpoint(DeviceProtocol.tasmota), -20)!.uri.queryParameters['cmnd'],
        'Dimmer 0',
      );
    });
  });

  test('an endpoint survives a JSON round trip on every device type', () {
    final light = LightDevice(
      id: 'l1',
      name: 'Porch',
      buildingId: 'main',
      endpoint: endpoint(DeviceProtocol.wled, channel: 2),
    );
    // Locks take no roomId, so their JSON shape differs - worth covering.
    final lock = LockDevice(
      id: 'k1',
      name: 'Gate',
      buildingId: 'main',
      endpoint: endpoint(DeviceProtocol.shellyGen2),
    );

    for (final device in [light, lock]) {
      final restored = Device.fromJson(device.toJson());
      expect(restored.endpoint, device.endpoint, reason: '${device.type} lost its endpoint');
    }
  });

  _statusTests();

  group('end to end against a stub device', () {
    late HttpServer stub;
    final hits = <String>[];

    setUp(() async {
      hits.clear();
      stub = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      stub.listen((request) async {
        hits.add('${request.method} ${request.uri}');
        await request.drain<void>();
        request.response.statusCode = 200;
        await request.response.close();
      });
    });

    tearDown(() => stub.close(force: true));

    test('toggling a wired light actually sends the HTTP request', () async {
      final light = LightDevice(
        id: 'porch',
        name: 'Porch',
        buildingId: 'main',
        endpoint: DeviceEndpoint(
          protocol: DeviceProtocol.shellyGen1,
          host: '127.0.0.1:${stub.port}',
        ),
      );
      final compound = buildEmptyCompound()..devices.add(light);
      final server = ServerCompound(seed: compound);

      server.toggleLight('porch');
      expect(light.on, isTrue, reason: 'local state updates immediately');
      // The send is fire-and-forget so the UI never waits on hardware.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(hits, ['GET /relay/0?turn=on']);

      server.toggleLight('porch');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(hits.last, 'GET /relay/0?turn=off');
      server.dispose();
    });

    test('a device with no endpoint sends nothing but still updates state', () async {
      final light = LightDevice(id: 'x', name: 'Unwired', buildingId: 'main');
      final server = ServerCompound(seed: buildEmptyCompound()..devices.add(light));
      server.toggleLight('x');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(light.on, isTrue);
      expect(hits, isEmpty);
      server.dispose();
    });

    test('an unreachable device does not break the command', () async {
      final light = LightDevice(
        id: 'gone',
        name: 'Unplugged',
        buildingId: 'main',
        // Reserved-for-documentation address: nothing answers.
        endpoint: const DeviceEndpoint(protocol: DeviceProtocol.wled, host: '192.0.2.1'),
      );
      final server = ServerCompound(seed: buildEmptyCompound()..devices.add(light));
      server.toggleLight('gone');
      expect(light.on, isTrue, reason: 'an unplugged device must not block the UI');
      server.dispose();
    });
  });
}

// --- Status reads -----------------------------------------------------------
// Captured payload shapes, because every vendor reports differently and a
// wrong reading makes the UI state the opposite of reality.

void _statusTests() {
  group('status parsing', () {
    test('Shelly gen1 relay', () {
      const body = '{"relays":[{"ison":true},{"ison":false}]}';
      expect(parseStatusResponse(endpoint(DeviceProtocol.shellyGen1), body)!.on, isTrue);
      expect(
        parseStatusResponse(endpoint(DeviceProtocol.shellyGen1, channel: 1), body)!.on,
        isFalse,
      );
    });

    test('Shelly gen1 dimmer reports brightness and takes priority over relays', () {
      const body = '{"lights":[{"ison":true,"brightness":42}],"relays":[{"ison":false}]}';
      final state = parseStatusResponse(endpoint(DeviceProtocol.shellyGen1), body)!;
      expect(state.on, isTrue);
      expect(state.brightness, 42);
    });

    test('Shelly gen2 keys components by type and index', () {
      const body = '{"switch:0":{"output":true},"light:1":{"output":true,"brightness":70}}';
      expect(parseStatusResponse(endpoint(DeviceProtocol.shellyGen2), body)!.on, isTrue);
      final light = parseStatusResponse(endpoint(DeviceProtocol.shellyGen2, channel: 1), body)!;
      expect(light.brightness, 70);
    });

    test('Tasmota maps ON/OFF strings and reads Dimmer', () {
      const body = '{"POWER":"ON","Dimmer":25}';
      final state = parseStatusResponse(endpoint(DeviceProtocol.tasmota), body)!;
      expect(state.on, isTrue);
      expect(state.brightness, 25);
      expect(
        parseStatusResponse(endpoint(DeviceProtocol.tasmota), '{"POWER":"OFF"}')!.on,
        isFalse,
      );
    });

    test('WLED brightness comes back as a 0-100 percentage', () {
      expect(
        parseStatusResponse(endpoint(DeviceProtocol.wled), '{"on":true,"bri":255}')!.brightness,
        100,
      );
      expect(
        parseStatusResponse(endpoint(DeviceProtocol.wled), '{"on":true,"bri":128}')!.brightness,
        50,
      );
    });

    test('garbage and missing channels read as no data, not as off', () {
      expect(parseStatusResponse(endpoint(DeviceProtocol.wled), 'not json'), isNull);
      expect(
        parseStatusResponse(endpoint(DeviceProtocol.shellyGen1, channel: 5),
            '{"relays":[{"ison":true}]}'),
        isNull,
      );
    });
  });
}
