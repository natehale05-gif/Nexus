import 'package:nexus_shared/nexus_shared.dart';
import 'package:test/test.dart';

void main() {
  group('safeDrivePath', () {
    test('keeps ordinary paths, including ones with spaces', () {
      expect(safeDrivePath(''), '');
      expect(safeDrivePath('Photos'), 'Photos');
      expect(safeDrivePath('Photos/2024/Trip to Bend.jpg'), 'Photos/2024/Trip to Bend.jpg');
      // A leading slash is a client being loose, not an attack.
      expect(safeDrivePath('/Photos'), 'Photos');
      expect(safeDrivePath('Photos//2024'), 'Photos/2024');
      expect(safeDrivePath('./Photos'), 'Photos');
      expect(safeDrivePath(r'Photos\2024'), 'Photos/2024');
    });

    test('refuses anything that climbs out of the root', () {
      // Quietly clamping these to the root would return a different folder's
      // contents than the caller asked for, which is worse than an error.
      expect(safeDrivePath('..'), isNull);
      expect(safeDrivePath('../etc/passwd'), isNull);
      expect(safeDrivePath('Photos/../../etc/passwd'), isNull);
      expect(safeDrivePath('/../secrets'), isNull);
      expect(safeDrivePath(r'..\..\Windows\System32'), isNull);
      // Even a climb that would land back inside is refused - it means the
      // caller built the path wrong.
      expect(safeDrivePath('Photos/../Photos'), isNull);
    });

    test('refuses drive letters and embedded NULs', () {
      expect(safeDrivePath(r'C:\Users'), isNull);
      expect(safeDrivePath('D:/data'), isNull);
      expect(safeDrivePath('Photos/x\u0000.jpg'), isNull);
    });

    test('a dotfile is a normal name, not a climb', () {
      expect(safeDrivePath('.config/app.json'), '.config/app.json');
      expect(safeDrivePath('...weird'), '...weird');
    });
  });

  group('driveKindForName', () {
    test('sorts files into what the UI needs to know', () {
      expect(driveKindForName('sunset.JPG'), DriveKind.image);
      expect(driveKindForName('clip.mov'), DriveKind.video);
      expect(driveKindForName('song.flac'), DriveKind.audio);
      expect(driveKindForName('deed.pdf'), DriveKind.document);
      expect(driveKindForName('firmware.bin'), DriveKind.other);
    });

    test('a name with no usable extension is not guessed at', () {
      expect(driveKindForName('README'), DriveKind.other);
      expect(driveKindForName('.gitignore'), DriveKind.other);
      expect(driveKindForName('trailing.'), DriveKind.other);
    });

    test('images and video are the two that belong in a photo grid', () {
      expect(const DriveEntry(name: 'a.jpg', path: 'a.jpg', kind: DriveKind.image).isVisualMedia,
          isTrue);
      expect(const DriveEntry(name: 'a.mp4', path: 'a.mp4', kind: DriveKind.video).isVisualMedia,
          isTrue);
      expect(const DriveEntry(name: 'a.pdf', path: 'a.pdf', kind: DriveKind.document).isVisualMedia,
          isFalse);
    });
  });

  group('DriveListing', () {
    test('breadcrumbs and parent come off the path', () {
      const listing = DriveListing(path: 'Photos/2024/June', entries: []);
      expect(listing.segments, ['Photos', '2024', 'June']);
      expect(listing.parent, 'Photos/2024');
    });

    test('the root has no parent to go up to', () {
      const root = DriveListing(path: '', entries: []);
      expect(root.segments, isEmpty);
      expect(root.parent, isNull);
    });

    test('survives a JSON round trip', () {
      final listing = DriveListing(path: 'Docs', entries: [
        DriveEntry(
          name: 'Deed.pdf',
          path: 'Docs/Deed.pdf',
          kind: DriveKind.document,
          sizeBytes: 4096,
          modified: DateTime.utc(2026, 3, 1, 12),
        ),
        const DriveEntry(
          name: 'Scans',
          path: 'Docs/Scans',
          kind: DriveKind.folder,
          childCount: 7,
        ),
      ]);

      final restored = DriveListing.fromJson(listing.toJson());
      expect(restored.path, 'Docs');
      expect(restored.entries.first.name, 'Deed.pdf');
      expect(restored.entries.first.sizeBytes, 4096);
      expect(restored.entries.first.modified, DateTime.utc(2026, 3, 1, 12));
      expect(restored.entries.last.isFolder, isTrue);
      expect(restored.entries.last.childCount, 7);
    });
  });
}
