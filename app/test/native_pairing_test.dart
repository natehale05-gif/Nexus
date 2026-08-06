import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/state/connection_settings.dart';
import 'package:nexus_app/state/native_pairing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('restBaseUrlFor', () {
    test('a LAN address speaks plain HTTP one port up', () {
      // REST lives at the WebSocket port + 1, which is the one rule Swift
      // would otherwise have to reimplement and could get subtly wrong.
      expect(restBaseUrlFor('192.168.1.50:8765'), 'http://192.168.1.50:8766');
      expect(restBaseUrlFor('nexus.local:8765'), 'http://nexus.local:8766');
      expect(restBaseUrlFor('localhost:8765'), 'http://localhost:8766');
      // A Tailscale 100.x address is still a bare IP, so still plain HTTP.
      expect(restBaseUrlFor('100.101.102.103:8765'), 'http://100.101.102.103:8766');
    });

    test('a MagicDNS name speaks HTTPS', () {
      expect(
        restBaseUrlFor('myhouse.tailnet-name.ts.net:8765'),
        'https://myhouse.tailnet-name.ts.net:8766',
      );
    });

    test('an address with no port assumes the default pair', () {
      expect(restBaseUrlFor('192.168.1.50'), 'http://192.168.1.50:8766');
    });

    test('a custom port still means "one above"', () {
      expect(restBaseUrlFor('192.168.1.50:9000'), 'http://192.168.1.50:9001');
    });
  });

  group('NativePairing', () {
    late List<MethodCall> calls;
    late NativePairing pairing;

    setUp(() {
      calls = [];
      const channel = MethodChannel('nexus/pairing');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      pairing = const NativePairing();
    });

    test('sends every address as a finished REST base, preferred first', () async {
      if (!NativePairing.supported) return; // Not an Apple platform.
      await pairing.save(StoredConnection(
        serverAddress: '192.168.1.50:8765',
        token: 'abc',
        alternates: ['100.64.0.1:8765', 'shed.tail1.ts.net:8765'],
      ));

      final args = (calls.single.arguments as Map).cast<String, dynamic>();
      expect(args['token'], 'abc');
      expect(args['bases'], [
        'http://192.168.1.50:8766',
        'http://100.64.0.1:8766',
        'https://shed.tail1.ts.net:8766',
      ]);
    });

    test('a missing native handler does not break connecting', () async {
      const channel = MethodChannel('nexus/pairing');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      // Siri losing its copy of the pairing must never stop the app itself
      // from pairing.
      await expectLater(
        pairing.save(StoredConnection(serverAddress: 'h:1', token: 't')),
        completes,
      );
      await expectLater(pairing.clear(), completes);
    });
  });
}
