import 'dart:convert';

import 'package:http/http.dart' as http;

/// The version this build was compiled as. Injected by `release.yml` from the
/// release tag (`--dart-define=NEXUS_VERSION=0.3.0`); a local `flutter run`
/// leaves it at the dev sentinel, which never reports an update as available
/// so working copies don't nag.
const String appVersion = String.fromEnvironment(
  'NEXUS_VERSION',
  defaultValue: '0.0.0-dev',
);

const String _releasesApi =
    'https://api.github.com/repos/natehale05-gif/Nexus/releases/latest';

/// A newer release than the one running.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.tag,
    required this.notes,
    required this.assetUrl,
    required this.assetName,
  });

  final String version;
  final String tag;
  final String notes;

  /// The installer for the current platform, or null if this release doesn't
  /// carry one (e.g. a release cut before a platform was supported).
  final String? assetUrl;
  final String? assetName;
}

/// Which release asset this platform installs.
enum UpdatePlatform {
  windows('NEXUS-windows-x64-setup.exe'),
  macos('NEXUS-macos.dmg'),
  linux('NEXUS-linux-x64.deb'),

  /// Web updates by reloading the page - there's nothing to download.
  none('');

  const UpdatePlatform(this.assetName);
  final String assetName;
}

/// Polls GitHub Releases for a newer build.
///
/// Deliberately read-only and unauthenticated: the releases endpoint is public,
/// so this needs no token, and the app never gains write access to the repo.
class UpdateChecker {
  UpdateChecker({http.Client? client, this.currentVersion = appVersion})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String currentVersion;

  /// Returns the newer release, or null when up to date, on a dev build, or
  /// if the check fails. A failed update check is not an error worth
  /// interrupting anyone over - the app works fine either way.
  Future<UpdateInfo?> check({UpdatePlatform platform = UpdatePlatform.none}) async {
    if (currentVersion.endsWith('-dev')) return null;
    try {
      final response = await _client
          .get(Uri.parse(_releasesApi), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latest.isEmpty || compareVersions(latest, currentVersion) <= 0) return null;

      String? assetUrl;
      String? assetName;
      if (platform != UpdatePlatform.none) {
        for (final asset in (json['assets'] as List<dynamic>? ?? const [])) {
          final map = asset as Map<String, dynamic>;
          if (map['name'] == platform.assetName) {
            assetUrl = map['browser_download_url'] as String?;
            assetName = map['name'] as String?;
            break;
          }
        }
      }

      return UpdateInfo(
        version: latest,
        tag: tag,
        notes: (json['body'] as String?) ?? '',
        assetUrl: assetUrl,
        assetName: assetName,
      );
    } catch (_) {
      // Offline, rate-limited, DNS failure, malformed payload - all the same
      // outcome: don't offer an update this time.
      return null;
    }
  }

  void dispose() => _client.close();
}

/// Numeric-segment version compare: >0 if [a] is newer than [b].
///
/// Handles the common shapes without pulling in a semver package: differing
/// segment counts (1.2 vs 1.2.0), and pre-release suffixes, which sort *below*
/// the same version without one so `0.3.0-beta` never looks newer than
/// `0.3.0`.
int compareVersions(String a, String b) {
  final (aCore, aPre) = _split(a);
  final (bCore, bPre) = _split(b);
  final length = aCore.length > bCore.length ? aCore.length : bCore.length;
  for (var i = 0; i < length; i++) {
    final ai = i < aCore.length ? aCore[i] : 0;
    final bi = i < bCore.length ? bCore[i] : 0;
    if (ai != bi) return ai > bi ? 1 : -1;
  }
  if (aPre == bPre) return 0;
  if (aPre.isEmpty) return 1; // a release beats a pre-release of the same core
  if (bPre.isEmpty) return -1;
  return aPre.compareTo(bPre);
}

(List<int>, String) _split(String version) {
  final dash = version.indexOf('-');
  final core = dash == -1 ? version : version.substring(0, dash);
  final pre = dash == -1 ? '' : version.substring(dash + 1);
  final parts = core
      .split('.')
      .map((segment) => int.tryParse(segment.trim()) ?? 0)
      .toList();
  return (parts, pre);
}
