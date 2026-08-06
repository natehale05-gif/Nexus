import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'connection_settings.dart';
import 'server_client.dart';

/// Mirrors the pairing into the Keychain, where Siri can find it.
///
/// Apple's App Intents run in their own moment: the system may execute one
/// with NEXUS closed, from a HomePod, or off the lock screen. They can't ask
/// Flutter for the server address, because there may be no Flutter running.
/// So Dart pushes the pairing down to native storage whenever it changes, and
/// the Swift side reads it directly.
///
/// Dart sends the finished REST base URLs rather than raw host:port pairs.
/// Working out the scheme and the +1 port is real logic that already exists
/// here; duplicating it in Swift would be a second implementation to keep in
/// step, and a wrong one would look like "Siri can't reach your server".
class NativePairing {
  const NativePairing({this.channel = const MethodChannel('nexus/pairing')});

  final MethodChannel channel;

  /// Only Apple platforms have Siri. Everywhere else this is a no-op rather
  /// than a failed channel call on every connect.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> save(StoredConnection connection) async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('save', {
        'bases': [for (final address in connection.addresses) restBaseUrlFor(address)],
        'token': connection.token,
      });
    } on MissingPluginException {
      // An older build of the native side, or a platform that never
      // registered the channel. Siri simply won't have a pairing; nothing
      // about the app itself should fail over it.
    } catch (_) {
      // Same reasoning: this is a convenience mirror, not the source of truth.
    }
  }

  Future<void> clear() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('clear');
    } catch (_) {
      // Forgetting a server must succeed whether or not the mirror does.
    }
  }
}

/// The REST base URL for an address the app pairs with.
///
/// Same two rules [ServerClient] uses: a LAN-shaped address speaks plain
/// HTTP, anything else (a Tailscale MagicDNS name) speaks HTTPS, and REST
/// lives one port above the WebSocket.
String restBaseUrlFor(String address) {
  final uri = ServerClient.normalizeAddress(address);
  final scheme = uri.scheme == 'wss' ? 'https' : 'http';
  return '$scheme://${uri.host}:${uri.port + 1}';
}
