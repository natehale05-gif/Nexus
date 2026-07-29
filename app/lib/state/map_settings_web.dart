/// Web implementation: the token goes in `localStorage` under the same key
/// `web/cesium/data.js` reads (`nexus.ionToken`).
library;

import 'package:web/web.dart' as web;

/// Whether this platform has a 3D map whose token can be configured.
const bool mapTokenConfigurable = true;

const String _key = 'nexus.ionToken';

String? loadIonToken() {
  try {
    final value = web.window.localStorage.getItem(_key);
    return (value == null || value.isEmpty) ? null : value;
  } catch (_) {
    // localStorage throws in private mode and in sandboxed frames. A missing
    // token is a normal state here, so degrade rather than crash the app.
    return null;
  }
}

void saveIonToken(String token) {
  try {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      web.window.localStorage.removeItem(_key);
    } else {
      web.window.localStorage.setItem(_key, trimmed);
    }
  } catch (_) {
    // Same reasoning as above - the map falls back to its offline schematic
    // and says why, which is a better outcome than an unhandled exception.
  }
}
