import 'package:shelf/shelf.dart';

import 'pairing_token.dart';

/// Rejects any REST request that doesn't present the correct
/// `Authorization: Bearer <token>` header, with two deliberate exceptions.
///
/// `/health` stays open so basic liveness checks don't need a token.
/// `/media/stream/*` and `/drive/file` authenticate themselves through a
/// per-path query token derived from the pairing token (see
/// `mediaStreamToken`), because the things that fetch them - a video element,
/// an `<img>`, a range request from a player - can't reliably attach a custom
/// header. Those two carry a token that only unlocks the one path, so a
/// leaked URL is not a leaked pairing.
Middleware requireToken(PairingToken token) {
  return (Handler innerHandler) {
    return (Request request) {
      final path = request.url.path;
      if (path == 'health' ||
          path == '/health' ||
          path.startsWith('media/stream/') ||
          path == 'drive/file') {
        return innerHandler(request);
      }
      final header = request.headers['authorization'];
      final presented = header != null && header.startsWith('Bearer ') ? header.substring(7) : null;
      if (!token.verify(presented)) {
        return Response(401, body: 'Unauthorized');
      }
      return innerHandler(request);
    };
  };
}
