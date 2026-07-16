import 'package:shelf/shelf.dart';

import 'pairing_token.dart';

/// Rejects any REST request other than `/health` that doesn't present the
/// correct `Authorization: Bearer <token>` header. `/health` stays open so
/// basic liveness checks don't need a token.
Middleware requireToken(PairingToken token) {
  return (Handler innerHandler) {
    return (Request request) {
      if (request.url.path == 'health' || request.url.path == '/health') {
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
