/// Where the Cesium ion access token for the 3D compound map lives.
///
/// The map itself is the static CesiumJS page in `web/cesium/`, embedded as a
/// same-origin `<iframe>`. Because it's same-origin, `localStorage` is shared
/// between the Flutter shell and that page - so the app writes the token here
/// and `web/cesium/data.js` picks it up on its next load. That keeps the token
/// out of the repo: an ion token is tied to a specific ion account, so there
/// is no value that could be committed and work for everyone.
///
/// Native builds don't render the CesiumJS map at all (see `cesium_map.dart`),
/// so the io implementation is a no-op rather than a second storage backend
/// nothing would read.
library;

export 'map_settings_io.dart' if (dart.library.js_interop) 'map_settings_web.dart';
