import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A server address the app has paired with before, persisted on-device
/// (Keychain on iOS/macOS, Keystore on Android, encrypted storage on web)
/// so a device only needs to enter its server address + pairing token
/// once, rather than re-typing them - or relaunching with a `?server=`
/// URL - on every launch.
class StoredConnection {
  const StoredConnection({required this.serverAddress, required this.token});

  final String serverAddress;
  final String token;
}

class ConnectionSettings {
  ConnectionSettings({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _serverKey = 'nexus.server_address';
  static const _tokenKey = 'nexus.pairing_token';

  final FlutterSecureStorage _storage;

  Future<StoredConnection?> load() async {
    final address = await _storage.read(key: _serverKey);
    final token = await _storage.read(key: _tokenKey);
    if (address == null || address.isEmpty || token == null || token.isEmpty) return null;
    return StoredConnection(serverAddress: address, token: token);
  }

  Future<void> save(StoredConnection connection) async {
    await _storage.write(key: _serverKey, value: connection.serverAddress);
    await _storage.write(key: _tokenKey, value: connection.token);
  }

  Future<void> clear() async {
    await _storage.delete(key: _serverKey);
    await _storage.delete(key: _tokenKey);
  }
}
