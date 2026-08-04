import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/ai/model_catalog.dart';
import 'package:nexus_app/ai/runtime/runtime_release.dart';

void main() {
  group('model catalog', () {
    test('recommends the largest model the machine can actually run', () {
      // Picking by "technically loads" rather than "runs well" produces an
      // assistant that takes a minute to answer, which reads as broken.
      expect(recommendedModel(8).name, 'Fast');
      expect(recommendedModel(16).name, 'Balanced');
      expect(recommendedModel(32).name, 'Sharper');
      expect(recommendedModel(64).name, 'Best');
    });

    test('a tiny machine still gets an option rather than nothing', () {
      expect(recommendedModel(2).name, 'Fast');
    });

    test('unknown memory falls back to the middle, not the biggest', () {
      // Guessing high on an unknown machine is the expensive mistake: a 42 GB
      // download that then won't run.
      expect(recommendedModel(null).name, 'Balanced');
    });

    test('every entry is ordered by size and self-consistent', () {
      for (var i = 1; i < localModelCatalog.length; i++) {
        expect(
          localModelCatalog[i].downloadGb,
          greaterThan(localModelCatalog[i - 1].downloadGb),
          reason: 'the picker reads top-to-bottom as small-to-large',
        );
        expect(
          localModelCatalog[i].needsRamGb,
          greaterThan(localModelCatalog[i - 1].needsRamGb),
        );
      }
      for (final model in localModelCatalog) {
        // A model always needs more memory than its file size on disk.
        expect(model.needsRamGb, greaterThan(model.downloadGb));
        expect(model.id, contains(':'));
      }
    });

    test('fitsIn is inclusive at the boundary', () {
      final balanced = localModelCatalog[1];
      expect(balanced.fitsIn(balanced.needsRamGb), isTrue);
      expect(balanced.fitsIn(balanced.needsRamGb - 0.1), isFalse);
      // Unknown memory must not hide every model.
      expect(balanced.fitsIn(null), isTrue);
    });

    test('sizes read as sizes', () {
      expect(formatGb(1.9), '1.9 GB');
      expect(formatGb(42), '42 GB');
    });
  });

  group('runtime release table', () {
    test('every platform NEXUS ships to has a build', () {
      for (final os in ['macos', 'linux', 'windows']) {
        final release = runtimeReleaseFor(os: os, arch: 'x64');
        expect(release, isNotNull, reason: '$os has desktop releases');
        expect(release!.url, startsWith('https://'));
        expect(release.url, contains(runtimeVersion),
            reason: 'pinned, so a working install cannot change underneath');
        expect(release.approxMb, greaterThan(0));
        expect(release.executablePath, isNotEmpty);
      }
    });

    test('linux picks a build per architecture, macOS is universal', () {
      expect(runtimeReleaseFor(os: 'linux', arch: 'arm64')!.url, contains('arm64'));
      expect(runtimeReleaseFor(os: 'linux', arch: 'x64')!.url, contains('amd64'));
      expect(
        runtimeReleaseFor(os: 'macos', arch: 'arm64')!.url,
        runtimeReleaseFor(os: 'macos', arch: 'x64')!.url,
      );
    });

    test('archive kind matches the filename', () {
      expect(runtimeReleaseFor(os: 'windows', arch: 'x64')!.isZip, isTrue);
      expect(runtimeReleaseFor(os: 'linux', arch: 'x64')!.isZip, isFalse);
    });

    test('an unknown platform returns null rather than a broken URL', () {
      // iOS and Android can't host a model; the UI reads this as unsupported.
      expect(runtimeReleaseFor(os: 'ios', arch: 'arm64'), isNull);
      expect(runtimeReleaseFor(os: 'android', arch: 'arm64'), isNull);
    });
  });
}
