import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// How this device is running NEXUS. Chosen once on first launch and then
/// remembered, so the app opens straight into whatever you picked.
enum AppMode {
  /// Paired with a `nexus_server`; the server owns the compound state.
  server,

  /// This device holds its own compound, created and edited in-app.
  local,

  /// The seeded example compound. Explicitly chosen now rather than being
  /// what everyone silently lands in.
  demo;

  static AppMode? parse(String? raw) {
    if (raw == null) return null;
    for (final mode in AppMode.values) {
      if (mode.name == raw) return mode;
    }
    return null;
  }
}

/// Persists the chosen [AppMode]. Shares the secure-storage backend the
/// pairing token already uses - not because the mode is a secret, but so
/// there's one storage dependency to reason about for "what this device
/// remembers about itself".
class AppModeSettings {
  AppModeSettings({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'nexus_app_mode';

  Future<AppMode?> load() async {
    try {
      return AppMode.parse(await _storage.read(key: _key));
    } catch (_) {
      // An unreadable keystore shouldn't block launch; onboarding just runs.
      return null;
    }
  }

  Future<void> save(AppMode mode) async {
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {
      // Worst case the choice isn't remembered and onboarding shows again.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Nothing to do.
    }
  }
}
