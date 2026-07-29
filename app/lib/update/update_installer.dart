/// Downloads and launches a platform installer for an available update.
///
/// Native only - on web an "update" is just a page reload, so the web
/// implementation reports no platform and does nothing.
library;

export 'update_installer_io.dart'
    if (dart.library.js_interop) 'update_installer_web.dart';
