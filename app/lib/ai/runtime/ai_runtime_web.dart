/// Web: a browser can't spawn a process or hold a model in memory, so there is
/// no local engine to manage. The AI settings offer the paired server's engine
/// instead, which is the better arrangement anyway - a phone should not be
/// downloading an 8 GB model.
library;

export 'runtime_release.dart';

const bool aiRuntimeSupported = false;

const aiRuntimeHost = '127.0.0.1';
const aiRuntimePort = 11435;
const aiRuntimeUrl = 'http://$aiRuntimeHost:$aiRuntimePort';

bool get aiRuntimeRunning => false;

Future<double?> machineRamGb() async => null;

Future<String?> findExistingBinary() async => null;

Future<String?> findRunningEngine() async => null;

Future<bool> engineAnswers(String baseUrl, {Duration timeout = const Duration(seconds: 2)}) async =>
    false;

Future<void> installRuntime({
  required void Function(double? fraction) onProgress,
  Object? client,
}) async {
  throw const AiRuntimeException('Local AI needs the desktop app.');
}

Future<String> startRuntime({String? binaryPath}) async {
  throw const AiRuntimeException('Local AI needs the desktop app.');
}

Future<void> stopRuntime() async {}

class AiRuntimeException implements Exception {
  const AiRuntimeException(this.message);
  final String message;
  @override
  String toString() => message;
}
