/// Reads a pairing handed to the app by the URL it was opened with.
///
/// This is what makes the QR code work without an in-app scanner: the code
/// encodes an ordinary https link to the NEXUS web app with the pairing in
/// its fragment, so a phone's built-in camera opens it and the app is paired
/// before anyone has typed anything. On native builds there is no launch URL
/// and these are no-ops.
library;

export 'launch_pairing_io.dart' if (dart.library.js_interop) 'launch_pairing_web.dart';
