import 'dart:io';

import 'package:nexus_shared/nexus_shared.dart';

/// Personal files on the compound server.
///
/// Deliberately dumb: a rooted directory, listed on demand. No index, no
/// database, no scan - what's on disk is what you see, so putting a file there
/// over SMB or with a USB stick works exactly as well as uploading it through
/// the app.
///
/// Every path that crosses the wire is relative to [root] and passed through
/// [safeDrivePath] first. Resolving is then checked a second time against the
/// real root, because a symlink inside the tree can point anywhere and no
/// amount of string parsing will catch that.
class DriveStore {
  DriveStore(String rootPath) : root = Directory(rootPath) {
    root.createSync(recursive: true);
  }

  final Directory root;

  /// The absolute path for a client-supplied relative path, or null if it
  /// isn't inside the root.
  String? resolve(String requested) {
    final safe = safeDrivePath(requested);
    if (safe == null) return null;
    final rootPath = root.resolveSymbolicLinksSync();
    final target = safe.isEmpty ? root.path : '${root.path}/$safe';

    // Belt and braces: a symlink planted inside the root can point outside it,
    // which string-level checks can't see. Compare the resolved paths.
    try {
      final resolved = File(target).existsSync()
          ? File(target).resolveSymbolicLinksSync()
          : Directory(target).existsSync()
              ? Directory(target).resolveSymbolicLinksSync()
              : target;
      if (resolved != rootPath && !resolved.startsWith('$rootPath/')) return null;
      return target;
    } on FileSystemException {
      return null;
    }
  }

  /// One folder's contents, folders first and then files, each group by name.
  ///
  /// Folders first because that's how every file browser worth using does it;
  /// a folder is a place you're going, a file is a thing you're taking.
  DriveListing? list(String requested) {
    final safe = safeDrivePath(requested);
    final absolute = resolve(requested);
    if (safe == null || absolute == null) return null;
    final directory = Directory(absolute);
    if (!directory.existsSync()) return null;

    final folders = <DriveEntry>[];
    final files = <DriveEntry>[];
    for (final entity in directory.listSync(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      // Dotfiles are noise here - this is someone's documents, not a checkout.
      if (name.startsWith('.')) continue;
      final relative = safe.isEmpty ? name : '$safe/$name';
      if (entity is Directory) {
        folders.add(DriveEntry(
          name: name,
          path: relative,
          kind: DriveKind.folder,
          childCount: _countChildren(entity),
          modified: _modified(entity),
        ));
      } else if (entity is File) {
        FileStat? stat;
        try {
          stat = entity.statSync();
        } catch (_) {
          continue; // Vanished or unreadable mid-listing.
        }
        files.add(DriveEntry(
          name: name,
          path: relative,
          kind: driveKindForName(name),
          sizeBytes: stat.size,
          modified: stat.modified,
        ));
      }
    }

    int byName(DriveEntry a, DriveEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    folders.sort(byName);
    files.sort(byName);
    return DriveListing(path: safe, entries: [...folders, ...files]);
  }

  int? _countChildren(Directory directory) {
    try {
      return directory.listSync(followLinks: false).length;
    } catch (_) {
      // Unreadable folder - the count is cosmetic, so don't fail the listing.
      return null;
    }
  }

  DateTime? _modified(FileSystemEntity entity) {
    try {
      return entity.statSync().modified;
    } catch (_) {
      return null;
    }
  }

  /// The file at a relative path, or null if it isn't one.
  File? file(String requested) {
    final absolute = resolve(requested);
    if (absolute == null) return null;
    final file = File(absolute);
    return file.existsSync() ? file : null;
  }

  /// Creates a folder. Returns false if the path escapes the root.
  bool createFolder(String requested) {
    final absolute = resolve(requested);
    if (absolute == null || absolute == root.path) return false;
    Directory(absolute).createSync(recursive: true);
    return true;
  }

  /// Opens a file for writing, creating parent folders as needed.
  ///
  /// Returns null rather than throwing for a path outside the root, so the
  /// caller answers with a 400 instead of a stack trace.
  IOSink? openForWrite(String requested) {
    final absolute = resolve(requested);
    if (absolute == null || absolute == root.path) return null;
    final file = File(absolute);
    file.parent.createSync(recursive: true);
    return file.openWrite();
  }

  /// Deletes a file or an empty folder.
  bool delete(String requested) {
    final absolute = resolve(requested);
    if (absolute == null || absolute == root.path) return false;
    final file = File(absolute);
    if (file.existsSync()) {
      file.deleteSync();
      return true;
    }
    final directory = Directory(absolute);
    if (directory.existsSync()) {
      // Non-recursive on purpose: deleting a folder tree from a tap in a file
      // browser should be a deliberate, separate thing to build.
      if (directory.listSync().isNotEmpty) return false;
      directory.deleteSync();
      return true;
    }
    return false;
  }
}
