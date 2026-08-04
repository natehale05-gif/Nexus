/// Which engine build belongs on which machine.
///
/// Kept as a small plain table on purpose. It is the one part of the local-AI
/// feature that depends on someone else's release naming, so it is worth
/// having in a single place that is obvious to correct, rather than spread
/// through the installer as string concatenation.
library;

/// A downloadable engine build.
class RuntimeRelease {
  const RuntimeRelease({
    required this.url,
    required this.archiveName,
    required this.executablePath,
    required this.approxMb,
  });

  final String url;
  final String archiveName;

  /// Where the executable ends up inside the extracted archive.
  final String executablePath;

  /// Rough download size, so the UI can warn before starting it.
  final int approxMb;

  bool get isZip => archiveName.endsWith('.zip');
}

/// Pinned rather than "latest": an engine that silently changes under a
/// working install is a support problem, and a release that renames its assets
/// would otherwise turn into a download failure with no explanation.
const runtimeVersion = '0.5.7';

/// The build for a given platform, or null where there isn't one.
///
/// [os] takes `Platform.operatingSystem` values; [arch] is `arm64` or `x64`.
RuntimeRelease? runtimeReleaseFor({required String os, required String arch}) {
  const base = 'https://github.com/ollama/ollama/releases/download/v$runtimeVersion';
  switch (os) {
    case 'macos':
      // One universal build covers both Apple Silicon and Intel.
      return const RuntimeRelease(
        url: '$base/ollama-darwin.tgz',
        archiveName: 'ollama-darwin.tgz',
        executablePath: 'ollama',
        approxMb: 190,
      );
    case 'linux':
      final suffix = arch == 'arm64' ? 'arm64' : 'amd64';
      return RuntimeRelease(
        url: '$base/ollama-linux-$suffix.tgz',
        archiveName: 'ollama-linux-$suffix.tgz',
        executablePath: 'bin/ollama',
        approxMb: arch == 'arm64' ? 1100 : 1500,
      );
    case 'windows':
      return const RuntimeRelease(
        url: '$base/ollama-windows-amd64.zip',
        archiveName: 'ollama-windows-amd64.zip',
        executablePath: 'ollama.exe',
        approxMb: 700,
      );
    default:
      return null;
  }
}
