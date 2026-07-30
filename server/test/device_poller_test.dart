import 'dart:convert';
import 'dart:io';

import 'package:nexus_server/devices/device_poller.dart';
import 'package:nexus_server/state/server_compound.dart';
import 'package:nexus_shared/nexus_shared.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer stub;
  // What the fake device currently reports - mutate this to simulate someone
  // flipping the physical switch behind NEXUS's back.
  late Map<String, dynamic> reported;
  var requests = 0;

  setUp(() async {
    reported = {'on': false, 'bri': 0};
    requests = 0;
    stub = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    stub.listen((request) async {
      requests++;
      await request.drain<void>();
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(reported));
      await request.response.close();
    });
  });

  tearDown(() => stub.close(force: true));

  LightDevice wiredLight() => LightDevice(
        id: 'porch',
        name: 'Porch',
        buildingId: 'main',
        endpoint: DeviceEndpoint(
          protocol: DeviceProtocol.wled,
          host: '127.0.0.1:${stub.port}',
        ),
      );

  test('picks up a change made outside NEXUS', () async {
    final light = wiredLight();
    final server = ServerCompound(seed: buildEmptyCompound()..devices.add(light));
    final poller = DevicePoller(server);

    expect(light.on, isFalse);

    // Someone hits the wall switch and sets it to half brightness.
    reported = {'on': true, 'bri': 128};
    await poller.poll();

    expect(light.on, isTrue, reason: 'the poll must reconcile, not keep stale state');
    expect(light.brightness, 50, reason: 'WLED 128/255 is 50%');

    poller.dispose();
    server.dispose();
  });

  test('broadcasts only when something actually differs', () async {
    final light = wiredLight();
    final server = ServerCompound(seed: buildEmptyCompound()..devices.add(light));
    final poller = DevicePoller(server);

    var broadcasts = 0;
    final sub = server.onChange.listen((_) => broadcasts++);

    // Already matches the device's initial state - LightDevice defaults to
    // brightness 100, so report 255 (=100%), not 0. An idle compound
    // shouldn't push the whole tree to every client on every interval.
    reported = {'on': false, 'bri': 255};
    await poller.poll();
    await Future<void>.delayed(Duration.zero);
    expect(broadcasts, 0);

    reported = {'on': true, 'bri': 255};
    await poller.poll();
    await Future<void>.delayed(Duration.zero);
    expect(broadcasts, greaterThan(0));

    await sub.cancel();
    poller.dispose();
    server.dispose();
  });

  test('keeps the last known state when a device stops answering', () async {
    final light = LightDevice(
      id: 'gone',
      name: 'Unplugged',
      buildingId: 'main',
      // Reserved-for-documentation address: nothing answers.
      endpoint: const DeviceEndpoint(protocol: DeviceProtocol.wled, host: '192.0.2.1'),
    )..on = true;
    final server = ServerCompound(seed: buildEmptyCompound()..devices.add(light));
    final poller = DevicePoller(server);

    await poller.poll();

    // Unreachable must not read as "off" - that would silently misreport a
    // light that's actually on.
    expect(light.on, isTrue);
    poller.dispose();
    server.dispose();
  });

  test('skips devices with no endpoint entirely', () async {
    final tracked = LightDevice(id: 'x', name: 'Unwired', buildingId: 'main');
    final server = ServerCompound(seed: buildEmptyCompound()..devices.add(tracked));
    final poller = DevicePoller(server);

    await poller.poll();
    expect(requests, 0);

    poller.dispose();
    server.dispose();
  });

  test('a gate relay reading on means unlocked', () async {
    final gate = LockDevice(
      id: 'gate',
      name: 'North Gate',
      buildingId: 'main',
      isGate: true,
      endpoint: DeviceEndpoint(
        protocol: DeviceProtocol.wled,
        host: '127.0.0.1:${stub.port}',
      ),
    );
    final server = ServerCompound(seed: buildEmptyCompound()..devices.add(gate));
    final poller = DevicePoller(server);

    expect(gate.locked, isTrue);
    reported = {'on': true};
    await poller.poll();
    expect(gate.locked, isFalse, reason: 'relay energized = gate open');

    reported = {'on': false};
    await poller.poll();
    expect(gate.locked, isTrue);

    poller.dispose();
    server.dispose();
  });

  test('overlapping polls do not stack traffic on slow devices', () async {
    final light = wiredLight();
    final server = ServerCompound(seed: buildEmptyCompound()..devices.add(light));
    final poller = DevicePoller(server);

    // Fire several rounds without awaiting: the guard should collapse them.
    final rounds = [poller.poll(), poller.poll(), poller.poll()];
    await Future.wait(rounds);
    expect(requests, 1);

    poller.dispose();
    server.dispose();
  });
}
