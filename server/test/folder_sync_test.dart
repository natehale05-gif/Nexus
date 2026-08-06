import 'dart:io';

import 'package:nexus_server/files/drive_store.dart';
import 'package:nexus_server/sync/folder_sync.dart';
import 'package:nexus_server/sync/sync_source.dart';
import 'package:test/test.dart';

void main() {
  group('what to skip', () {
    test('an iCloud placeholder is never copied', () {
      // The single most important rule here. A file the Mac has not
      // downloaded yet is a tiny .icloud stub, and copying one produces a
      // Drive full of things that look like photos and are not.
      expect(shouldSkipFile('.IMG_4021.HEIC.icloud', 180), isTrue);
      expect(shouldSkipFile('IMG_4021.HEIC.icloud', 180), isTrue);
      // The real file, once downloaded, is not a dotfile and is not skipped.
      expect(shouldSkipFile('IMG_4021.HEIC', 2400000), isFalse);
    });

    test('a zero-byte file is not worth copying', () {
      // Either it is nothing, or it is a placeholder that has not
      // materialised - both mean "come back later".
      expect(shouldSkipFile('IMG_1.HEIC', 0), isTrue);
      expect(shouldSkipFile('IMG_1.HEIC', -1), isTrue);
    });

    test('OS metadata is left behind', () {
      for (final name in ['.DS_Store', '._IMG_1.HEIC', 'desktop.ini', 'thumbs.db']) {
        expect(shouldSkipFile(name, 4096), isTrue, reason: name);
      }
    });

    test('a photo library package is not walked into', () {
      // It is thousands of internal files, none of which anyone wants in
      // Drive - and the originals inside it are not laid out as photos.
      expect(shouldSkipFolder('Photos Library.photoslibrary'), isTrue);
      expect(shouldSkipFolder('Family.fcpbundle'), isTrue);
      expect(shouldSkipFolder('.Trash'), isTrue);
      expect(shouldSkipFolder('2026 Trip'), isFalse);
    });
  });

  group('sources', () {
    test('parses labelled paths', () {
      final sources = parseSyncSources('Photos=/a/b,Files=/c/d');
      expect(sources.map((s) => s.label), ['Photos', 'Files']);
      expect(sources.map((s) => s.path), ['/a/b', '/c/d']);
    });

    test('a bare path is labelled from its last folder rather than refused', () {
      final sources = parseSyncSources('/Users/me/Pictures/iCloud Photos');
      expect(sources.single.label, 'iCloud Photos');
      expect(sources.single.path, '/Users/me/Pictures/iCloud Photos');
    });

    test('blank entries are ignored', () {
      expect(parseSyncSources(''), isEmpty);
      expect(parseSyncSources('  '), isEmpty);
      expect(parseSyncSources('Photos=/a,,'), hasLength(1));
    });

    test('a Mac offers the folders iCloud actually creates', () {
      final candidates = appleSyncCandidates('/Users/me', os: 'macos');
      final paths = candidates.map((s) => s.path).toList();
      expect(paths, contains('/Users/me/Pictures/iCloud Photos'));
      expect(paths, contains('/Users/me/Library/Mobile Documents/com~apple~CloudDocs'));
    });

    test('Linux has no Apple folders to guess at', () {
      expect(appleSyncCandidates('/home/me', os: 'linux'), isEmpty);
    });
  });

  test('a file keeps the shape it had on the Mac', () {
    expect(driveDestination('Photos', '2026/June/IMG_1.HEIC'), 'Photos/2026/June/IMG_1.HEIC');
    expect(driveDestination('Photos', r'2026\June\IMG_1.HEIC'), 'Photos/2026/June/IMG_1.HEIC');
    expect(driveDestination('Photos', '/IMG_1.HEIC'), 'Photos/IMG_1.HEIC');
  });

  group('copying', () {
    late Directory temp;
    late Directory source;
    late DriveStore drive;
    late FolderSync sync;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('nexus_sync_test');
      source = Directory('${temp.path}/icloud')..createSync();
      drive = DriveStore('${temp.path}/drive');
      sync = FolderSync(
        drive: drive,
        sources: [SyncSource(label: 'Photos', path: source.path)],
        stateDir: temp.path,
      );
    });

    tearDown(() => temp.deleteSync(recursive: true));

    /// Written with an old timestamp: the sync deliberately leaves very
    /// recent files alone in case they are still being written.
    File settled(String relative, String contents) {
      final file = File('${source.path}/$relative');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
      file.setLastModifiedSync(DateTime.now().subtract(const Duration(minutes: 5)));
      return file;
    }

    test('copies new files into Drive, keeping their folders', () async {
      settled('2026/June/IMG_1.HEIC', 'photo-bytes');

      await sync.runOnce();

      final copied = File('${drive.root.path}/Photos/2026/June/IMG_1.HEIC');
      expect(copied.existsSync(), isTrue);
      expect(copied.readAsStringSync(), 'photo-bytes');
      expect(sync.copiedLastPass, 1);
    });

    test('a second pass copies nothing again', () async {
      settled('IMG_1.HEIC', 'x');
      await sync.runOnce();
      expect(sync.copiedLastPass, 1);

      await sync.runOnce();
      // Re-copying an untouched photo library every five minutes would burn
      // the disk and the network for nothing.
      expect(sync.copiedLastPass, 0);
    });

    test('an edited original comes through again', () async {
      final file = settled('IMG_1.HEIC', 'first');
      await sync.runOnce();

      file.writeAsStringSync('second and longer');
      file.setLastModifiedSync(DateTime.now().subtract(const Duration(minutes: 2)));
      await sync.runOnce();

      expect(sync.copiedLastPass, 1);
      expect(
        File('${drive.root.path}/Photos/IMG_1.HEIC').readAsStringSync(),
        'second and longer',
      );
    });

    test('a file still being written is left for the next pass', () async {
      final file = File('${source.path}/IMG_live.HEIC')..writeAsStringSync('half');
      file.setLastModifiedSync(DateTime.now());

      await sync.runOnce();

      // Copying half a photo and recording it as done would leave a corrupt
      // file that never gets fixed.
      expect(File('${drive.root.path}/Photos/IMG_live.HEIC').existsSync(), isFalse);
      expect(sync.copiedLastPass, 0);
    });

    test('placeholders and metadata are skipped, real files beside them are not', () async {
      settled('.IMG_2.HEIC.icloud', 'stub');
      settled('.DS_Store', 'junk');
      settled('IMG_3.HEIC', 'real');

      await sync.runOnce();

      expect(sync.copiedLastPass, 1);
      expect(File('${drive.root.path}/Photos/IMG_3.HEIC').existsSync(), isTrue);
      expect(Directory('${drive.root.path}/Photos').listSync(), hasLength(1));
    });

    test('nothing is ever removed from the source', () async {
      settled('IMG_1.HEIC', 'x');
      await sync.runOnce();
      // One-way, always. A sync that can delete is a sync that can lose your
      // photos to a bug.
      expect(File('${source.path}/IMG_1.HEIC').existsSync(), isTrue);
    });

    test('a source folder that is not on this machine is not an error', () async {
      final absent = FolderSync(
        drive: drive,
        sources: const [SyncSource(label: 'Photos', path: '/nope/not/here')],
        stateDir: temp.path,
      );
      expect(absent.availableSources, isEmpty);
      await expectLater(absent.runOnce(), completes);
    });

    test('what was copied survives a restart', () async {
      settled('IMG_1.HEIC', 'x');
      await sync.runOnce();

      final restarted = FolderSync(
        drive: drive,
        sources: [SyncSource(label: 'Photos', path: source.path)],
        stateDir: temp.path,
      );
      await restarted.start();
      restarted.stop();

      expect(restarted.copiedLastPass, 0);
    });
  });
}
