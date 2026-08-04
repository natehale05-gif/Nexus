import 'dart:io';

import 'package:nexus_server/files/drive_store.dart';
import 'package:nexus_shared/nexus_shared.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late Directory root;
  late DriveStore store;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('nexus_drive_test');
    root = Directory('${temp.path}/drive')..createSync();
    store = DriveStore(root.path);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  File write(String relative, [String contents = 'x']) {
    final file = File('${root.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
    return file;
  }

  test('creates its root if it is not there yet', () {
    final fresh = Directory('${temp.path}/brand-new');
    expect(fresh.existsSync(), isFalse);
    DriveStore(fresh.path);
    expect(fresh.existsSync(), isTrue);
  });

  test('lists folders before files, each alphabetically', () {
    write('zebra.txt');
    write('Apple.txt');
    Directory('${root.path}/Photos').createSync();
    Directory('${root.path}/archive').createSync();

    final listing = store.list('')!;
    // Folders first because a folder is somewhere you're going and a file is
    // something you're taking; case-insensitive so "archive" isn't exiled
    // below "Photos".
    expect(listing.entries.map((e) => e.name), ['archive', 'Photos', 'Apple.txt', 'zebra.txt']);
    expect(listing.entries.first.isFolder, isTrue);
  });

  test('reports size, kind and a relative path for each entry', () {
    write('Photos/sunset.jpg', 'abcdefgh');
    final listing = store.list('Photos')!;
    final entry = listing.entries.single;
    expect(entry.name, 'sunset.jpg');
    // Relative, always - an absolute path leaking to a client is how the next
    // request ends up naming somewhere outside the root.
    expect(entry.path, 'Photos/sunset.jpg');
    expect(entry.kind, DriveKind.image);
    expect(entry.sizeBytes, 8);
    expect(entry.modified, isNotNull);
  });

  test('folders report how much is inside them', () {
    write('Docs/a.pdf');
    write('Docs/b.pdf');
    expect(store.list('')!.entries.single.childCount, 2);
  });

  test('hides dotfiles', () {
    write('.DS_Store');
    write('visible.txt');
    expect(store.list('')!.entries.map((e) => e.name), ['visible.txt']);
  });

  test('a path that climbs out of the root resolves to nothing', () {
    write('secret.txt');
    File('${temp.path}/outside.txt').writeAsStringSync('nope');

    expect(store.list('..'), isNull);
    expect(store.list('../'), isNull);
    expect(store.file('../outside.txt'), isNull);
    // A leading slash is a loose client, not an attack: it means "from the
    // root", and the root is the Drive root. It must land inside.
    expect(store.resolve('/etc/passwd'), '${root.path}/etc/passwd');
    expect(store.file('/etc/passwd'), isNull);
    expect(store.createFolder('../escaped'), isFalse);
    expect(store.openForWrite('../escaped.txt'), isNull);
    expect(Directory('${temp.path}/escaped').existsSync(), isFalse);
  });

  test('a symlink pointing outside the root is refused', () {
    // String-level path checking cannot see this: every segment is innocent.
    final outside = Directory('${temp.path}/outside')..createSync();
    File('${outside.path}/passwd').writeAsStringSync('root:x:0:0');
    try {
      Link('${root.path}/escape').createSync(outside.path);
    } on FileSystemException {
      return; // A platform without symlink permission - nothing to prove.
    }

    expect(store.file('escape/passwd'), isNull);
    expect(store.list('escape'), isNull);
  });

  test('reads and writes a file through the root', () async {
    final sink = store.openForWrite('Docs/new.txt')!;
    sink.write('hello');
    await sink.close();

    final file = store.file('Docs/new.txt')!;
    expect(file.readAsStringSync(), 'hello');
    // Parent folders are created on the way, so an upload into a new folder
    // doesn't need a separate mkdir first.
    expect(Directory('${root.path}/Docs').existsSync(), isTrue);
  });

  test('creates folders, but never replaces the root itself', () {
    expect(store.createFolder('Trips/2026'), isTrue);
    expect(Directory('${root.path}/Trips/2026').existsSync(), isTrue);
    expect(store.createFolder(''), isFalse);
  });

  test('deletes a file, and an empty folder, but not a full one', () {
    write('gone.txt');
    Directory('${root.path}/empty').createSync();
    write('full/keep.txt');

    expect(store.delete('gone.txt'), isTrue);
    expect(store.delete('empty'), isTrue);
    // Emptying a folder tree from a tap in a file browser should be a
    // deliberate, separate thing to build.
    expect(store.delete('full'), isFalse);
    expect(File('${root.path}/full/keep.txt').existsSync(), isTrue);
    expect(store.delete(''), isFalse);
    expect(root.existsSync(), isTrue);
  });

  test('listing a path that is not there returns null, not an empty folder', () {
    // An empty listing would read as "this folder is empty", which is a
    // different and misleading answer.
    expect(store.list('nope'), isNull);
    expect(store.file('nope.txt'), isNull);
  });
}
