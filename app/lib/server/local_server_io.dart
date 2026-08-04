/// Native: locate the bundled `nexus_server`, run it, and read back the
/// pairing token it generates on first boot.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nexus_shared/nexus_shared.dart';
import 'package:path_provider/path_provider.dart';

/// Desktop only. iOS/Android can't spawn a long-lived server process, and
/// wouldn't be the right machine to host the compound anyway.
final bool localServerSupported =
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Process? _process;
final StringBuffer _log = StringBuffer();

bool get localServerRunning => _process != null;
String? get localServerLog => _log.isEmpty ? null : _log.toString();

/// Where the server binary sits: beside the app executable in every desktop
/// bundle (`NEXUS.app/Contents/MacOS/` on macOS, next to `nexus_app.exe` on
/// Windows, next to `nexus` on Linux). A dev checkout won't have it - that's
/// what [localServerPath] returning null means.
String? get localServerPath {
  if (!localServerSupported) return null;
  final dir = File(Platform.resolvedExecutable).parent.path;
  final name = Platform.isWindows ? 'nexus_server.exe' : 'nexus_server';
  final candidate = File('$dir/$name');
  return candidate.existsSync() ? candidate.path : null;
}

/// A running local server: where to point the app, and the token to pair with.
class LocalServerHandle {
  const LocalServerHandle({
    required this.address,
    required this.token,
    this.addresses = const [],
  });

  /// `host:port` of the WebSocket port, in the shape the Settings screen and
  /// [ServerClient] already expect. Loopback - this is how the machine
  /// running the server talks to it.
  final String address;
  final String token;

  /// Every address *other* devices can reach this server on, LAN first and
  /// remote (Tailscale) last. Loopback is deliberately not in here: it is the
  /// one address that is guaranteed wrong on a phone.
  final List<String> addresses;

  /// What to put in a QR code. Null until the server is up and its addresses
  /// have been enumerated.
  PairingPayload? get pairing =>
      addresses.isEmpty ? null : PairingPayload(addresses: addresses, token: token);
}

/// Every address a *different* device could use to reach a server on this
/// machine, in the order worth trying.
///
/// LAN addresses first: on the same network they're the fastest path and
/// need nothing else running. Tailscale last, because it's the one that
/// still works from somewhere else entirely - which is exactly the case
/// where you want a fallback rather than a first choice.
Future<List<String>> serverAddresses({int port = 8765}) async {
  final lan = <String>[];
  final remote = <String>[];
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback) continue;
        final entry = '${address.address}:$port';
        (isTailscaleAddress(address.address) ? remote : lan).add(entry);
      }
    }
  } catch (_) {
    // Sandboxed or permission-denied interface enumeration: better to hand
    // back whatever we have than to fail starting a server over it.
  }

  // The MagicDNS name outlives the 100.x address, so prefer it when the
  // tailscale CLI is around to tell us what it is.
  final magicDns = await _magicDnsName();
  if (magicDns != null) remote.insert(0, '$magicDns:$port');

  return [...lan, ...remote];
}

/// Asks the local tailscale CLI for this machine's MagicDNS name.
///
/// Best-effort and quick to give up: Tailscale is optional, the CLI isn't on
/// PATH in every install (macOS puts it inside the .app), and a server start
/// must never hang waiting for it.
Future<String?> _magicDnsName() async {
  const candidates = [
    'tailscale',
    '/usr/bin/tailscale',
    '/usr/local/bin/tailscale',
    '/Applications/Tailscale.app/Contents/MacOS/Tailscale',
    r'C:\Program Files\Tailscale\tailscale.exe',
  ];
  for (final executable in candidates) {
    try {
      final result = await Process.run(executable, ['status', '--json'])
          .timeout(const Duration(seconds: 3));
      if (result.exitCode != 0) continue;
      final decoded = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final self = decoded['Self'] as Map<String, dynamic>?;
      final dnsName = self?['DNSName'] as String?;
      if (dnsName == null || dnsName.isEmpty) continue;
      // Tailscale reports it fully-qualified, with a trailing dot.
      return dnsName.endsWith('.') ? dnsName.substring(0, dnsName.length - 1) : dnsName;
    } catch (_) {
      continue;
    }
  }
  return null;
}

/// Starts the bundled server and waits for it to become reachable.
///
/// Binds to 0.0.0.0 rather than localhost on purpose: the whole point of
/// running it here is that your phone and laptop connect to it too, over the
/// LAN or Tailscale. Auth is the pairing token, not the bind address.
Future<LocalServerHandle?> startLocalServer({String? mediaRoot}) async {
  if (_process != null) return _handleFromDisk();
  final path = localServerPath;
  if (path == null) {
    throw const LocalServerException(
      'No bundled server found next to the app. This build was made without '
      'one - reinstall from a release download.',
    );
  }

  final dataDir = await _dataDir();
  Directory(dataDir).createSync(recursive: true);

  _log.clear();
  final process = await Process.start(
    path,
    const [],
    environment: {
      'NEXUS_DATA_DIR': dataDir,
      if (mediaRoot != null && mediaRoot.trim().isNotEmpty)
        'NEXUS_MEDIA_ROOT': mediaRoot.trim(),
    },
    // Not detached: if the app dies the server should go with it, otherwise
    // a stale process keeps the port and the next start fails confusingly.
    mode: ProcessStartMode.normal,
  );
  _process = process;

  // Keep the tail of the output so the UI can show why a start failed.
  void capture(Stream<List<int>> stream) {
    stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      _log.writeln(line);
      const limit = 8000;
      if (_log.length > limit) {
        final trimmed = _log.toString();
        _log
          ..clear()
          ..write(trimmed.substring(trimmed.length - limit));
      }
    }, onError: (_) {});
  }

  capture(process.stdout);
  capture(process.stderr);

  unawaited(process.exitCode.then((code) {
    _log.writeln('nexus_server exited with code $code');
    _process = null;
  }));

  // Poll /health rather than sleeping a fixed amount - first boot generates
  // the pairing token and scans the media root, which takes an unpredictable
  // amount of time.
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    if (_process == null) {
      throw LocalServerException(
        'The server exited immediately.\n${localServerLog ?? ''}'.trim(),
      );
    }
    if (await _healthy()) return _handleFromDisk();
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  throw LocalServerException(
    'The server started but never became reachable on port 8766.\n'
    '${localServerLog ?? ''}'.trim(),
  );
}

Future<void> stopLocalServer() async {
  final process = _process;
  _process = null;
  if (process == null) return;
  process.kill(ProcessSignal.sigterm);
  // Don't wait forever on a wedged process.
  await process.exitCode.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return -1;
    },
  );
}

Future<bool> _healthy() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client.getUrl(Uri.parse('http://127.0.0.1:8766/health'));
    final response = await request.close().timeout(const Duration(seconds: 3));
    await response.drain<void>();
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

Future<LocalServerHandle> _handleFromDisk() async {
  final tokenFile = File('${await _dataDir()}/pairing_token');
  if (!tokenFile.existsSync()) {
    throw const LocalServerException(
      'The server is up but has not written a pairing token yet.',
    );
  }
  return LocalServerHandle(
    address: '127.0.0.1:8765',
    token: (await tokenFile.readAsString()).trim(),
    addresses: await serverAddresses(),
  );
}

/// The server's state lives beside the app's own data rather than in the
/// install directory, so an update or uninstall doesn't take the compound
/// and pairing token with it.
Future<String> _dataDir() async =>
    '${(await getApplicationSupportDirectory()).path}/server';

class LocalServerException implements Exception {
  const LocalServerException(this.message);
  final String message;
  @override
  String toString() => message;
}
