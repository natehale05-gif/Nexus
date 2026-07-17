import 'package:shelf/shelf.dart';

import 'pairing_token.dart';

/// Rejects any REST request other than `/health` or `/media/stream/*` that
/// doesn't present the correct `Authorization: Bearer <token>` header.
/// `/health` stays open so basic liveness checks don't need a token;
/// `/media/stream/*` authenticates itself separately via a per-item query
/// token (see `mediaStreamToken`) since players can't reliably attach a
/// custom header to range requests.
Middleware requireToken(PairingToken token) {
  return (Handler innerHandler) {
    return (Request request) {
      final path = request.url.path;
      if (path == 'health' || path == '/health' || path.startsWith('media/stream/')) {
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
