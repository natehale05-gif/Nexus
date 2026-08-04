/// Native: find, fetch, and supervise the local inference engine.
library;

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'runtime_release.dart';

export 'runtime_release.dart';

const bool aiRuntimeSupported = true;

/// The address the engine listens on.
///
/// Loopback and a non-default port: loopback because nothing outside this
/// machine should be able to drive it, and a private port so NEXUS never
/// fights an engine the user runs themselves on the standard one.
const aiRuntimeHost = '127.0.0.1';
const aiRuntimePort = 11435;
const aiRuntimeUrl = 'http://$aiRuntimeHost:$aiRuntimePort';

/// The port a user-installed engine would already be on.
const _conventionalUrl = 'http://127.0.0.1:11434';

Process? _process;

bool get aiRuntimeRunning => _process != null;

/// How much memory this machine has, for sizing the model recommendation.
///
/// Best-effort: a wrong answer here only changes which model is suggested, so
/// it is not worth a plugin. Returns null when it can't be worked out, and the
/// caller falls back to a safe middle choice.
Future<double?> machineRamGb() async {
  try {
    if (Platform.isLinux) {
      final line = await File('/proc/meminfo')
          .readAsLines()
          .then((lines) => lines.firstWhere((l) => l.startsWith('MemTotal:')));
      final kb = int.parse(RegExp(r'(\d+)').firstMatch(line)!.group(1)!);
      return kb / 1024 / 1024;
    }
    if (Platform.isMacOS) {
      final result = await Process.run('sysctl', ['-n', 'hw.memsize'])
          .timeout(const Duration(seconds: 3));
      return int.parse((result.stdout as String).trim()) / 1024 / 1024 / 1024;
    }
    if (Platform.isWindows) {
      final result = await Process.run('wmic', ['computersystem', 'get', 'TotalPhysicalMemory'])
          .timeout(const Duration(seconds: 5));
      final match = RegExp(r'(\d{6,})').firstMatch(result.stdout as String);
      if (match != null) return int.parse(match.group(1)!) / 1024 / 1024 / 1024;
    }
  } catch (_) {
    // Unreadable /proc, missing sysctl, wmic removed in a future Windows -
    // none of which is worth failing over.
  }
  return null;
}

/// Where NEXUS keeps the engine and its models.
///
/// Beside the app's own data rather than in the install directory, so an
/// update doesn't delete a 40 GB model the user waited an hour for.
Future<Directory> aiRuntimeDir() async =>
    Directory('${(await getApplicationSupportDirectory()).path}/ai-runtime');

Future<File> _installedBinary() async {
  final dir = await aiRuntimeDir();
  final release = runtimeReleaseFor(
    os: Platform.operatingSystem,
    arch: _architecture(),
  );
  final relative = release?.executablePath ?? 'ollama';
  return File('${dir.path}/${relative.split('/').last}');
}

String _architecture() =>
    Platform.version.contains('arm64') || Platform.version.contains('aarch64')
        ? 'arm64'
        : 'x64';

/// An engine binary already on this machine, if there is one.
///
/// Checked before downloading anything: plenty of people already have one
/// installed, and making them wait for a second copy would be rude.
Future<String?> findExistingBinary() async {
  final own = await _installedBinary();
  if (own.existsSync()) return own.path;

  const candidates = [
    '/usr/local/bin/ollama',
    '/usr/bin/ollama',
    '/opt/homebrew/bin/ollama',
    '/Applications/Ollama.app/Contents/Resources/ollama',
    r'C:\Program Files\Ollama\ollama.exe',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  // Finally, anything on PATH.
  try {
    final which = Platform.isWindows ? 'where' : 'which';
    final result =
        await Process.run(which, ['ollama']).timeout(const Duration(seconds: 3));
    final found = (result.stdout as String).trim().split('\n').first.trim();
    if (result.exitCode == 0 && found.isNotEmpty && File(found).existsSync()) {
      return found;
    }
  } catch (_) {}
  return null;
}

/// An engine already answering, whether or not NEXUS started it.
///
/// Returns the URL to use, or null if nothing is up. Checks the conventional
/// port too, so someone who already runs one gets picked up for free.
Future<String?> findRunningEngine() async {
  for (final url in const [aiRuntimeUrl, _conventionalUrl]) {
    if (await engineAnswers(url)) return url;
  }
  return null;
}

Future<bool> engineAnswers(String baseUrl, {Duration timeout = const Duration(seconds: 2)}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(Uri.parse('$baseUrl/api/tags'));
    final response = await request.close().timeout(timeout);
    await response.drain<void>();
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

/// Downloads and unpacks the engine, reporting progress 0..1.
///
/// [onProgress] gets null while the size is unknown, so the UI can show an
/// indeterminate bar rather than a 0% that looks stuck.
Future<void> installRuntime({
  required void Function(double? fraction) onProgress,
  HttpClient? client,
}) async {
  final release = runtimeReleaseFor(os: Platform.operatingSystem, arch: _architecture());
  if (release == null) {
    throw AiRuntimeException('No engine build exists for ${Platform.operatingSystem}.');
  }

  final dir = await aiRuntimeDir();
  dir.createSync(recursive: true);
  final archive = File('${dir.path}/${release.archiveName}');

  final owned = client == null;
  final http = client ?? HttpClient();
  try {
    final request = await http.getUrl(Uri.parse(release.url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw AiRuntimeException(
        'Could not download the AI engine (HTTP ${response.statusCode}). '
        'Check the connection and try again.',
      );
    }
    final total = response.contentLength;
    var received = 0;
    final sink = archive.openWrite();
    try {
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        onProgress(total > 0 ? received / total : null);
      }
    } finally {
      await sink.close();
    }
  } on AiRuntimeException {
    rethrow;
  } catch (error) {
    throw AiRuntimeException('Could not download the AI engine: $error');
  } finally {
    if (owned) http.close(force: true);
  }

  onProgress(null);
  await _extract(archive, dir);
  // The archive is dead weight once unpacked, and it's the size of the engine.
  try {
    archive.deleteSync();
  } catch (_) {}

  final binary = await _installedBinary();
  if (!binary.existsSync()) {
    throw const AiRuntimeException(
      'The AI engine downloaded but its executable was not where expected. '
      'This usually means the release layout changed.',
    );
  }
  if (!Platform.isWindows) {
    await Process.run('chmod', ['+x', binary.path]);
  }
}

/// Unpacks with the system tar, which handles both .tgz and .zip on every
/// platform NEXUS ships to (Windows has bundled bsdtar since Windows 10).
/// Avoids pulling in an archive library for one call.
Future<void> _extract(File archive, Directory into) async {
  final result = await Process.run(
    'tar',
    ['-xf', archive.path, '-C', into.path],
  ).timeout(const Duration(minutes: 5));
  if (result.exitCode != 0) {
    throw AiRuntimeException('Could not unpack the AI engine: ${result.stderr}');
  }
  // Some builds nest the executable a directory down; flatten it so the rest
  // of this file only has to know one path.
  final expected = File('${into.path}/${_expectedRelative()}');
  final flat = await _installedBinary();
  if (expected.existsSync() && expected.path != flat.path) {
    expected.renameSync(flat.path);
  }
}

String _expectedRelative() =>
    runtimeReleaseFor(os: Platform.operatingSystem, arch: _architecture())
        ?.executablePath ??
    'ollama';

/// Starts the engine and waits for it to answer.
Future<String> startRuntime({String? binaryPath}) async {
  final running = await findRunningEngine();
  if (running != null) return running;

  final path = binaryPath ?? await findExistingBinary();
  if (path == null) {
    throw const AiRuntimeException('The AI engine is not installed yet.');
  }

  final dir = await aiRuntimeDir();
  _process = await Process.start(
    path,
    ['serve'],
    environment: {
      'OLLAMA_HOST': '$aiRuntimeHost:$aiRuntimePort',
      // Models live with NEXUS's data, so uninstalling the engine doesn't
      // strand tens of gigabytes somewhere the user will never find.
      'OLLAMA_MODELS': '${dir.path}/models',
    },
    // A child, not detached: an orphaned engine would hold the port and make
    // the next start fail with nothing explaining why.
    mode: ProcessStartMode.detachedWithStdio,
  );
  unawaited(_process!.exitCode.then((_) => _process = null));

  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    if (await engineAnswers(aiRuntimeUrl)) return aiRuntimeUrl;
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  throw const AiRuntimeException(
    'The AI engine started but never became reachable.',
  );
}

Future<void> stopRuntime() async {
  final process = _process;
  _process = null;
  process?.kill();
}

class AiRuntimeException implements Exception {
  const AiRuntimeException(this.message);
  final String message;
  @override
  String toString() => message;
}
