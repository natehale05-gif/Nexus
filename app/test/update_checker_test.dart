import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexus_app/update/update_checker.dart';

http.Client _client(Map<String, dynamic> body, {int status = 200}) =>
    MockClient((_) async => http.Response(jsonEncode(body), status));

Map<String, dynamic> _release(String tag, {List<String> assets = const []}) => {
      'tag_name': tag,
      'body': 'notes for $tag',
      'assets': [
        for (final name in assets)
          {'name': name, 'browser_download_url': 'https://example.test/$name'},
      ],
    };

void main() {
  group('compareVersions', () {
    test('orders by numeric segment, not lexically', () {
      expect(compareVersions('0.10.0', '0.9.0'), greaterThan(0));
      expect(compareVersions('1.0.0', '0.99.99'), greaterThan(0));
      expect(compareVersions('0.3.0', '0.3.0'), 0);
    });

    test('treats missing segments as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.1', '1.2'), greaterThan(0));
    });

    test('a pre-release sorts below the same release', () {
      expect(compareVersions('0.3.0-beta', '0.3.0'), lessThan(0));
      expect(compareVersions('0.3.0', '0.3.0-beta'), greaterThan(0));
      expect(compareVersions('0.4.0-beta', '0.3.0'), greaterThan(0));
    });
  });

  group('UpdateChecker', () {
    test('reports a newer release', () async {
      final checker = UpdateChecker(
        client: _client(_release('v0.4.0', assets: ['NEXUS-macos.dmg'])),
        currentVersion: '0.3.0',
      );
      final update = await checker.check(platform: UpdatePlatform.macos);
      expect(update, isNotNull);
      expect(update!.version, '0.4.0');
      expect(update.tag, 'v0.4.0');
      expect(update.assetUrl, 'https://example.test/NEXUS-macos.dmg');
    });

    test('stays quiet when already current or ahead', () async {
      final same = UpdateChecker(client: _client(_release('v0.3.0')), currentVersion: '0.3.0');
      expect(await same.check(), isNull);

      final ahead = UpdateChecker(client: _client(_release('v0.2.0')), currentVersion: '0.3.0');
      expect(await ahead.check(), isNull);
    });

    test('never nags a dev build', () async {
      final checker = UpdateChecker(
        client: _client(_release('v9.9.9')),
        currentVersion: '0.0.0-dev',
      );
      expect(await checker.check(platform: UpdatePlatform.linux), isNull);
    });

    test('picks the asset for the running platform only', () async {
      final body = _release('v0.4.0', assets: [
        'NEXUS-windows-x64-setup.exe',
        'NEXUS-macos.dmg',
        'NEXUS-linux-x64.deb',
      ]);
      for (final (platform, expected) in [
        (UpdatePlatform.windows, 'NEXUS-windows-x64-setup.exe'),
        (UpdatePlatform.macos, 'NEXUS-macos.dmg'),
        (UpdatePlatform.linux, 'NEXUS-linux-x64.deb'),
      ]) {
        final checker = UpdateChecker(client: _client(body), currentVersion: '0.3.0');
        final update = await checker.check(platform: platform);
        expect(update!.assetName, expected);
      }
    });

    test('still reports the update when this platform has no asset', () async {
      // A release cut before a platform existed shouldn't hide the fact that
      // a newer version is out.
      final checker = UpdateChecker(
        client: _client(_release('v0.4.0', assets: ['NEXUS-macos.dmg'])),
        currentVersion: '0.3.0',
      );
      final update = await checker.check(platform: UpdatePlatform.windows);
      expect(update, isNotNull);
      expect(update!.assetUrl, isNull);
    });

    test('a failed check is silent, not fatal', () async {
      final rateLimited = UpdateChecker(client: _client(const {}, status: 403), currentVersion: '0.3.0');
      expect(await rateLimited.check(), isNull);

      final offline = UpdateChecker(
        client: MockClient((_) async => throw const SocketExceptionStub()),
        currentVersion: '0.3.0',
      );
      expect(await offline.check(), isNull);

      final garbage = UpdateChecker(
        client: MockClient((_) async => http.Response('not json', 200)),
        currentVersion: '0.3.0',
      );
      expect(await garbage.check(), isNull);
    });
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
