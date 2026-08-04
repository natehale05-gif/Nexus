/// Everything a device needs to reach a NEXUS server, in one scannable blob.
///
/// Pairing used to mean reading an address and a 32-character token off one
/// screen and typing them into another, which is both tedious and the kind of
/// thing you get wrong once and then can't tell why it failed. Worse, a single
/// address can only ever be right in one place: `192.168.1.50` is correct at
/// home and useless in an airport.
///
/// So a payload carries *every* address the server answers on, in the order
/// worth trying, and the client keeps all of them - see the failover in
/// `ServerClient`. Pair once at home, and the same pairing still works from
/// the other side of the country over Tailscale.
library;

/// The Tailscale CGNAT range, 100.64.0.0/10.
///
/// Worth telling apart from an ordinary LAN address: a 192.168.x.y is only
/// reachable while you're on that network, whereas a Tailscale address is the
/// one that still works from a hotel. They're ordered accordingly, and the UI
/// labels them differently.
bool isTailscaleAddress(String hostOrHostPort) {
  final host = hostOrHostPort.split(':').first;
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final octets = [for (final p in parts) int.tryParse(p)];
  if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
  return octets[0] == 100 && octets[1]! >= 64 && octets[1]! <= 127;
}

/// True for a MagicDNS name (`myhouse.tailnet-name.ts.net`), which is the
/// stable way to reach a tailnet - the 100.x address can change.
bool isMagicDnsName(String hostOrHostPort) =>
    hostOrHostPort.split(':').first.toLowerCase().endsWith('.ts.net');

/// True for an address that works from outside the local network.
bool isRemoteReachable(String address) =>
    isTailscaleAddress(address) || isMagicDnsName(address);

/// A server's addresses plus the token that authorises a device to use them.
class PairingPayload {
  PairingPayload({required List<String> addresses, required this.token})
      : addresses = List.unmodifiable(_clean(addresses));

  /// Every `host:port` this server answers on, in the order a client should
  /// try them: LAN first (fastest when you're home), remote last.
  final List<String> addresses;
  final String token;

  static const scheme = 'nexus';
  static const _host = 'pair';

  bool get isEmpty => addresses.isEmpty || token.isEmpty;

  /// The addresses that still work when you're not on the home network.
  List<String> get remoteAddresses => addresses.where(isRemoteReachable).toList();

  /// The short canonical form: `nexus://pair?a=<addr>&a=<addr>&t=<token>`.
  ///
  /// Short on purpose. This is what goes in a QR code and what someone might
  /// paste into a message, and QR density grows fast with length.
  String encode() {
    final query = [
      for (final address in addresses) 'a=${Uri.encodeQueryComponent(address)}',
      't=${Uri.encodeQueryComponent(token)}',
    ].join('&');
    return '$scheme://$_host?$query';
  }

  /// The same payload as an ordinary https link, with the secret in the
  /// fragment.
  ///
  /// This is the form that goes in the QR code, because a phone's built-in
  /// camera will open it - no app installed, nothing to launch first. The
  /// fragment matters: browsers never send it to the server, so the pairing
  /// token never leaves the device even though the page is hosted publicly.
  String encodeWebLink(String appUrl) {
    final base = appUrl.split('#').first;
    return '$base#${encode().split('?').last}';
  }

  /// Reads a payload back out of any of the forms above.
  ///
  /// Deliberately forgiving - this parses whatever someone pasted. A
  /// `nexus://` URI, an https link with the payload in its fragment, a bare
  /// `a=...&t=...` query string, or a link that arrived with stray whitespace
  /// or wrapping angle brackets from a chat app. Returns null rather than
  /// throwing: bad input here is ordinary, not exceptional.
  static PairingPayload? decode(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('<') && text.endsWith('>')) {
      text = text.substring(1, text.length - 1).trim();
    }

    // Pull out whichever part carries the parameters.
    String query;
    if (text.contains('#')) {
      query = text.split('#').last;
    } else if (text.contains('?')) {
      query = text.split('?').last;
    } else {
      query = text;
    }
    if (!query.contains('t=')) return null;

    final addresses = <String>[];
    String? token;
    for (final pair in query.split('&')) {
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      final key = pair.substring(0, index);
      final value = Uri.decodeQueryComponent(pair.substring(index + 1));
      switch (key) {
        case 'a':
          addresses.add(value);
        case 't':
          token = value;
      }
    }
    if (token == null || token.isEmpty || addresses.isEmpty) return null;
    final payload = PairingPayload(addresses: addresses, token: token);
    return payload.isEmpty ? null : payload;
  }

  /// Trims, drops blanks, and de-duplicates while keeping the given order -
  /// a machine with several interfaces reports the same address more than
  /// once, and a duplicate costs a whole failed connection attempt.
  static List<String> _clean(List<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final entry in raw) {
      final value = entry.trim();
      if (value.isEmpty) continue;
      if (seen.add(value)) out.add(value);
    }
    return out;
  }

  @override
  String toString() => 'PairingPayload(${addresses.join(', ')})';
}
