import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A per-item streaming token derived from the server's pairing token, so a
/// leaked stream URL only ever exposes access to one item rather than the
/// master pairing token itself (video players/browser `<video>` elements
/// can't reliably attach an `Authorization` header to range requests, so
/// `/media/stream/<id>` is authenticated via this query-param token instead
/// of the usual bearer header).
String mediaStreamToken(String pairingToken, String itemId) =>
    sha256.convert(utf8.encode('$pairingToken:$itemId')).toString();
