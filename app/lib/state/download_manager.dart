/// Manages movies/TV saved on *this* device for offline playback.
///
/// Real offline download-and-playback is a native-device capability: the
/// native implementation ([download_manager_io.dart]) streams a title to
/// the app's documents directory and plays it back from disk. The web build
/// has no app-managed filesystem for large video, so it gets a no-op stub
/// ([download_manager_web.dart]) whose `isSupported` is `false` and the
/// Media tab simply doesn't show download affordances there - streaming
/// still works on web when online. This mirrors the platform split already
/// used for the CesiumJS map (`screens/home/cesium_map.dart`).
library;

export 'download_manager_io.dart'
    if (dart.library.js_interop) 'download_manager_web.dart';
