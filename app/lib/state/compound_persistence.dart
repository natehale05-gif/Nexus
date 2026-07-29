/// Saves and restores a locally-created [Compound].
///
/// Only matters for the "set this device up as its own compound" mode - when
/// paired with a `nexus_server` the server owns the state and pushes it over
/// the WebSocket, and the demo compound is regenerated from `buildDemoCompound()`
/// every launch on purpose.
///
/// Native writes a JSON file in the app documents directory; web uses
/// `localStorage`. Both are keyed the same way so the calling code doesn't
/// branch. A compound tree is far too big for `flutter_secure_storage` (which
/// is for the pairing token and API keys), and none of it is secret.
library;

export 'compound_persistence_io.dart'
    if (dart.library.js_interop) 'compound_persistence_web.dart';
