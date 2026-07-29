/// Web: a browser can't run a server process.
library;

const bool localServerSupported = false;

String? get localServerPath => null;
bool get localServerRunning => false;
String? get localServerLog => null;

Future<LocalServerHandle?> startLocalServer({String? mediaRoot}) async => null;
Future<void> stopLocalServer() async {}

/// Mirrors the io type so callers compile on every platform.
class LocalServerHandle {
  const LocalServerHandle({required this.address, required this.token});
  final String address;
  final String token;
}
