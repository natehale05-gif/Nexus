import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../files/drive_store.dart';
import 'sync_source.dart';

/// Pulls Apple's folders into the compound's Drive.
///
/// One-way and additive, always: NEXUS copies *from* iCloud and never writes
/// back, never deletes, and never moves anything. A sync that can delete is a
/// sync that can lose your photos to a bug, and the whole point of putting
/// them on your own hardware is that they stop being one company's problem.
///
/// This is the half of "sync with my Apple apps" that actually works from a
/// server. A photo taken on the phone reaches iCloud Photos, iCloud brings it
/// down to the Mac, and NEXUS finds it there - no phone-side app, no
/// entitlements, nothing to keep alive in the background on iOS.
class FolderSync {
  FolderSync({
    required this.drive,
    required this.sources,
    required String stateDir,
    this.interval = const Duration(minutes: 5),
  }) : _manifestFile = File('$stateDir/sync_manifest.json');

  final DriveStore drive;
  final List<SyncSource> sources;
  final Duration interval;
  final File _manifestFile;

  /// source absolute path -> what we copied last time.
  final Map<String, SyncRecord> _seen = {};

  Timer? _timer;
  bool _running = false;

  /// Counts from the last pass, for the log and for Settings to show.
  int copiedLastPass = 0;
  int skippedLastPass = 0;
  DateTime? lastRun;

  /// Sources that exist on this machine. A path someone configured on a
  /// different computer isn't an error worth failing over - it just isn't
  /// here.
  List<SyncSource> get availableSources =>
      [for (final s in sources) if (Directory(s.path).existsSync()) s];

  Future<void> start() async {
    if (sources.isEmpty) return;
    await _loadManifest();
    // Run once now so a restart picks up whatever arrived while it was down,
    // then on a timer.
    unawaited(runOnce());
    _timer = Timer.periodic(interval, (_) => unawaited(runOnce()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One pass over every source.
  ///
  /// Guarded against overlap: a first pass over a large photo library can
  /// easily outlast the interval, and two passes copying the same files would
  /// fight over the same destination.
  Future<void> runOnce() async {
    if (_running) return;
    _running = true;
    copiedLastPass = 0;
    skippedLastPass = 0;
    try {
      for (final source in availableSources) {
        await _syncSource(source);
      }
      lastRun = DateTime.now();
      if (copiedLastPass > 0) await _saveManifest();
    } finally {
      _running = false;
    }
  }

  Future<void> _syncSource(SyncSource source) async {
    final root = Directory(source.path);
    await for (final entity in _walk(root)) {
      final relative = entity.path
          .substring(root.path.length)
          .replaceAll(r'\', '/')
          .replaceAll(RegExp('^/+'), '');
      final name = relative.split('/').last;

      FileStat stat;
      try {
        stat = entity.statSync();
      } catch (_) {
        continue; // Vanished between listing and stat.
      }

      if (shouldSkipFile(name, stat.size)) {
        skippedLastPass++;
        continue;
      }

      final modifiedMs = stat.modified.millisecondsSinceEpoch;
      final already = _seen[entity.path];
      if (already != null && already.matches(stat.size, modifiedMs)) {
        skippedLastPass++;
        continue;
      }

      // A file still being written has a size that changes under us. Leave it
      // for the next pass rather than copying half a photo.
      if (DateTime.now().difference(stat.modified) < const Duration(seconds: 30)) {
        skippedLastPass++;
        continue;
      }

      final destination = driveDestination(source.label, relative);
      if (await _copy(entity, destination)) {
        _seen[entity.path] = SyncRecord(sizeBytes: stat.size, modifiedMs: modifiedMs);
        copiedLastPass++;
      }
    }
  }

  /// Every file under [root], skipping the folders that aren't worth walking.
  Stream<File> _walk(Directory root) async* {
    final queue = <Directory>[root];
    while (queue.isNotEmpty) {
      final directory = queue.removeAt(0);
      List<FileSystemEntity> entries;
      try {
        // followLinks false: an alias pointing back up the tree would walk
        // forever, and one pointing outside would copy somewhere unexpected.
        entries = directory.listSync(followLinks: false);
      } catch (_) {
        continue; // Permission denied on a folder is not a reason to stop.
      }
      for (final entry in entries) {
        final name = entry.path.split(Platform.pathSeparator).last;
        if (entry is Directory) {
          if (!shouldSkipFolder(name)) queue.add(entry);
        } else if (entry is File) {
          yield entry;
        }
      }
    }
  }

  Future<bool> _copy(File source, String destination) async {
    final sink = drive.openForWrite(destination);
    if (sink == null) return false;
    try {
      await source.openRead().pipe(sink);
      return true;
    } catch (_) {
      // Unreadable original, or Drive's disk filled up. Not recorded as seen,
      // so the next pass tries again.
      return false;
    }
  }

  Future<void> _loadManifest() async {
    if (!_manifestFile.existsSync()) return;
    try {
      final decoded = jsonDecode(await _manifestFile.readAsString()) as Map<String, dynamic>;
      decoded.forEach((path, raw) {
        _seen[path] = SyncRecord.fromJson((raw as Map).cast<String, dynamic>());
      });
    } catch (_) {
      // A corrupt manifest means re-copying, which is wasteful but harmless -
      // far better than refusing to start.
    }
  }

  Future<void> _saveManifest() async {
    try {
      _manifestFile.parent.createSync(recursive: true);
      await _manifestFile.writeAsString(
        jsonEncode({for (final entry in _seen.entries) entry.key: entry.value.toJson()}),
      );
    } catch (_) {
      // Losing the manifest costs a re-copy next boot, nothing more.
    }
  }
}
