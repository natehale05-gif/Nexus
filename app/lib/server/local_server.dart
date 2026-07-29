/// Runs a `nexus_server` process on this machine, so the desktop app can be
/// the server as well as a client - no separate terminal, no `dart run`.
///
/// The server binary is compiled by CI (`dart compile exe`) and shipped
/// beside the app executable in every desktop bundle. Web and mobile can't
/// spawn processes, so those get a stub reporting the feature unavailable.
library;

export 'local_server_io.dart' if (dart.library.js_interop) 'local_server_web.dart';
