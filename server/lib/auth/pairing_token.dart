import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// The single shared secret every device must present to talk to this
/// server. Generated once on first boot and persisted to disk - this is
/// intentionally a static shared secret for one household's devices, not
/// per-user login/session auth.
class PairingToken {
  factory PairingToken(File file) {
    if (file.existsSync()) {
      final existing = file.readAsStringSync().trim();
      if (existing.isNotEmpty) return PairingToken._(existing, isNew: false);
    }
    final token = _generate();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(token);
    return PairingToken._(token, isNew: true);
  }

  PairingToken._(this.value, {required this.isNew});

  /// The token itself.
  final String value;

  /// True if this call generated a brand new token (first boot, or the
  /// token file was removed) rather than loading an existing one.
  final bool isNew;

  bool verify(String? presented) => presented != null && presented.isNotEmpty && presented == value;

  static String _generate() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
