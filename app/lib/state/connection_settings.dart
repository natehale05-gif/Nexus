import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nexus_shared/nexus_shared.dart';

/// A server the app has paired with before, persisted on-device (Keychain on
/// iOS/macOS, Keystore on Android, encrypted storage on web) so a device only
/// needs to pair once rather than re-entering an address and token on every
/// launch.
///
/// Holds a *list* of addresses, not one. The address that works is a property
/// of where you're standing: the LAN IP is right at home and wrong everywhere
/// else, and the Tailscale address is right everywhere but slower at home.
/// Keeping all of them is what makes one pairing survive travelling.
class StoredConnection {
  StoredConnection({
    required this.serverAddress,
    required this.token,
    List<String> alternates = const [],
  }) : alternates = List.unmodifiable(alternates.where((a) => a != serverAddress));

  /// The preferred address - the one shown in Settings.
  final String serverAddress;
  final String token;

  /// Other addresses for the same server, tried in order when the preferred
  /// one can't be reached.
  final List<String> alternates;

  /// Every address, preferred first.
  List<String> get addresses => [serverAddress, ...alternates];

  /// The pairing this connection came from, for re-sharing it to another
  /// device without going back to the machine running the server.
  PairingPayload get payload => PairingPayload(addresses: addresses, token: token);

  static StoredConnection fromPayload(PairingPayload payload) => StoredConnection(
        serverAddress: payload.addresses.first,
        token: payload.token,
        alternates: payload.addresses.skip(1).toList(),
      );
}

class ConnectionSettings {
  ConnectionSettings({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _serverKey = 'nexus.server_address';
  static const _tokenKey = 'nexus.pairing_token';
  static const _alternatesKey = 'nexus.alternate_addresses';

  final FlutterSecureStorage _storage;

  Future<StoredConnection?> load() async {
    final address = await _storage.read(key: _serverKey);
    final token = await _storage.read(key: _tokenKey);
    if (address == null || address.isEmpty || token == null || token.isEmpty) return null;
    // Absent for connections paired before failover existed, which must keep
    // working with the single address they were saved with.
    final alternates = await _storage.read(key: _alternatesKey);
    return StoredConnection(
      serverAddress: address,
      token: token,
      alternates: _splitAddresses(alternates),
    );
  }

  Future<void> save(StoredConnection connection) async {
    await _storage.write(key: _serverKey, value: connection.serverAddress);
    await _storage.write(key: _tokenKey, value: connection.token);
    await _storage.write(key: _alternatesKey, value: connection.alternates.join('\n'));
  }

  Future<void> clear() async {
    await _storage.delete(key: _serverKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _alternatesKey);
  }

  static List<String> _splitAddresses(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return [
      for (final line in raw.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
  }
}
