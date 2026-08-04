import 'package:nexus_shared/nexus_shared.dart';
import 'package:test/test.dart';

void main() {
  group('isTailscaleAddress', () {
    test('accepts the CGNAT range and nothing else', () {
      expect(isTailscaleAddress('100.64.0.1'), isTrue);
      expect(isTailscaleAddress('100.101.102.103:8765'), isTrue);
      expect(isTailscaleAddress('100.127.255.255'), isTrue);
      // 100.63 and 100.128 sit just outside 100.64.0.0/10.
      expect(isTailscaleAddress('100.63.0.1'), isFalse);
      expect(isTailscaleAddress('100.128.0.1'), isFalse);
      expect(isTailscaleAddress('192.168.1.50'), isFalse);
      expect(isTailscaleAddress('myhouse.ts.net'), isFalse);
      expect(isTailscaleAddress('not an address'), isFalse);
    });
  });

  test('a MagicDNS name counts as remotely reachable, a LAN address does not', () {
    expect(isRemoteReachable('myhouse.tailnet-name.ts.net:8765'), isTrue);
    expect(isRemoteReachable('100.101.102.103:8765'), isTrue);
    expect(isRemoteReachable('192.168.1.50:8765'), isFalse);
    expect(isRemoteReachable('nexus.local:8765'), isFalse);
  });

  group('PairingPayload', () {
    final payload = PairingPayload(
      addresses: ['192.168.1.50:8765', '100.101.102.103:8765', 'x.ts.net:8765'],
      token: 'abc123',
    );

    test('survives a round trip through the short form', () {
      final decoded = PairingPayload.decode(payload.encode())!;
      expect(decoded.addresses, payload.addresses);
      expect(decoded.token, 'abc123');
    });

    test('survives a round trip through the web link', () {
      const appUrl = 'https://example.github.io/Nexus/';
      final link = payload.encodeWebLink(appUrl);
      // The secret has to be in the fragment: browsers never send that to the
      // host, so a publicly-served page never sees the token.
      expect(link.startsWith('$appUrl#'), isTrue);
      expect(link.contains('?'), isFalse);

      final decoded = PairingPayload.decode(link)!;
      expect(decoded.addresses, payload.addresses);
      expect(decoded.token, 'abc123');
    });

    test('a web link replaces any fragment already on the app URL', () {
      final link = payload.encodeWebLink('https://example.github.io/Nexus/#stale');
      expect(PairingPayload.decode(link)!.token, 'abc123');
      expect(link.contains('stale'), isFalse);
    });

    test('tokens with URL-significant characters survive', () {
      final odd = PairingPayload(addresses: ['h:1'], token: 'a&b=c d/e+f#g');
      expect(PairingPayload.decode(odd.encode())!.token, 'a&b=c d/e+f#g');
    });

    test('addresses keep their order, blanks and duplicates are dropped', () {
      final messy = PairingPayload(
        addresses: [' 192.168.1.50:8765 ', '', '192.168.1.50:8765', '100.64.0.1:8765'],
        token: 't',
      );
      // A duplicate costs a whole failed connection attempt during failover.
      expect(messy.addresses, ['192.168.1.50:8765', '100.64.0.1:8765']);
    });

    test('remoteAddresses is what still works from a hotel', () {
      expect(payload.remoteAddresses, ['100.101.102.103:8765', 'x.ts.net:8765']);
    });

    group('decode is forgiving about what got pasted', () {
      final expected = ['192.168.1.50:8765'];
      final variants = {
        'bare query string': 'a=192.168.1.50%3A8765&t=abc123',
        'wrapped in angle brackets': '<nexus://pair?a=192.168.1.50%3A8765&t=abc123>',
        'surrounded by whitespace': '  nexus://pair?a=192.168.1.50%3A8765&t=abc123\n',
      };
      variants.forEach((name, text) {
        test(name, () {
          final decoded = PairingPayload.decode(text)!;
          expect(decoded.addresses, expected);
          expect(decoded.token, 'abc123');
        });
      });
    });

    group('decode returns null rather than a half-built pairing', () {
      final bad = {
        'empty': '',
        'no token': 'nexus://pair?a=192.168.1.50%3A8765',
        'no address': 'nexus://pair?t=abc123',
        'empty token': 'nexus://pair?a=h%3A1&t=',
        'unrelated text': 'hey can you send me the thing',
        'a plain URL': 'https://example.com/page',
      };
      bad.forEach((name, text) {
        // Returning a partial payload here would produce a connection that
        // fails later with nothing pointing at the paste as the cause.
        test(name, () => expect(PairingPayload.decode(text), isNull));
      });
    });
  });
}
