/// Web: the pairing arrives in the URL fragment, put there by the QR code the
/// server's machine displays.
library;

import 'package:nexus_shared/nexus_shared.dart';
import 'package:web/web.dart' as web;

/// The pairing this page was opened with, if any.
///
/// The fragment is the right place for it: browsers never send a fragment to
/// the server, so the pairing token never reaches GitHub Pages even though
/// the page itself is served publicly.
PairingPayload? pairingFromLaunchUrl() {
  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return null;
  return PairingPayload.decode(fragment);
}

/// Drops the pairing out of the address bar once it has been stored.
///
/// Without this the token sits in the URL for anyone glancing at the screen,
/// survives into bookmarks and history, and re-applies itself on every
/// refresh - which would silently undo a later change of server.
void clearLaunchPairing() {
  final location = web.window.location;
  final clean = '${location.pathname}${location.search}';
  web.window.history.replaceState(null, '', clean);
}
