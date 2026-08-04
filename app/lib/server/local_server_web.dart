/// Web: a browser can't run a server process.
library;

import 'package:nexus_shared/nexus_shared.dart';

const bool localServerSupported = false;

String? get localServerPath => null;
bool get localServerRunning => false;
String? get localServerLog => null;

Future<LocalServerHandle?> startLocalServer({String? mediaRoot}) async => null;
Future<void> stopLocalServer() async {}

/// A browser can't enumerate network interfaces either.
Future<List<String>> serverAddresses({int port = 8765}) async => const [];

/// Mirrors the io type so callers compile on every platform.
class LocalServerHandle {
  const LocalServerHandle({
    required this.address,
    required this.token,
    this.addresses = const [],
  });

  final String address;
  final String token;
  final List<String> addresses;

  PairingPayload? get pairing =>
      addresses.isEmpty ? null : PairingPayload(addresses: addresses, token: token);
}
