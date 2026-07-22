import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'download_types.dart';

export 'download_types.dart';

/// Native [DownloadManager]: streams a title's bytes to a file in the app's
/// documents directory and tracks it in a small persisted JSON index, so
/// downloads survive relaunch and play back from disk with no server /
/// internet. See `download_manager.dart` for the platform-dispatch rationale.
class DownloadManager extends ChangeNotifier {
  DownloadManager({Directory? directoryOverride}) : _override = directoryOverride;

  final Directory? _override;
  Directory? _dir;

  /// Persisted, fully-downloaded items (itemId -> on-disk entry).
  final Map<String, _Entry> _entries = {};

  /// Transient per-item state for in-flight/failed downloads.
  final Map<String, DownloadStatus> _transient = {};
  final Map<String, double> _progress = {};
  final Map<String, int> _lastNotifiedPercent = {};

  bool get isSupported => true;

  Future<Directory> _dataDir() async {
    if (_dir != null) return _dir!;
    final base = _override ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/nexus_downloads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  File _indexFile(Directory dir) => File('${dir.path}/index.json');

  /// Loads the persisted download index. Call once at startup.
  Future<void> load() async {
    final dir = await _dataDir();
    final index = _indexFile(dir);
    if (index.existsSync()) {
      try {
        final map = jsonDecode(index.readAsStringSync()) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final value = entry.value as Map<String, dynamic>;
          final file = File('${dir.path}/${value['file']}');
          // Only trust an index entry whose file is actually still present.
          if (file.existsSync()) {
            _entries[entry.key] = _Entry(
              file: value['file'] as String,
              title: value['title'] as String? ?? '',
              durationSeconds: (value['durationSeconds'] as num?)?.toDouble() ?? 0,
            );
          }
        }
      } catch (_) {
        // Corrupt index - start clean rather than crash.
      }
    }
    notifyListeners();
  }

  Future<void> _saveIndex() async {
    final dir = await _dataDir();
    final map = {
      for (final e in _entries.entries)
        e.key: {'file': e.value.file, 'title': e.value.title, 'durationSeconds': e.value.durationSeconds},
    };
    _indexFile(dir).writeAsStringSync(jsonEncode(map));
  }

  DownloadStatus statusFor(String itemId) {
    if (_entries.containsKey(itemId)) return DownloadStatus.downloaded;
    return _transient[itemId] ?? DownloadStatus.notDownloaded;
  }

  double progressFor(String itemId) => _progress[itemId] ?? 0;

  List<DownloadedItem> get downloaded => _entries.entries
      .map((e) => DownloadedItem(id: e.key, title: e.value.title, durationSeconds: e.value.durationSeconds))
      .toList();

  /// The local `file://` URI to play [itemId] from, or null if it isn't
  /// downloaded on this device.
  Uri? localUri(String itemId) {
    final entry = _entries[itemId];
    if (entry == null || _dir == null) return null;
    return Uri.file('${_dir!.path}/${entry.file}');
  }

  /// Downloads [itemId] from [source] (its `/media/stream/<id>?token=` URL)
  /// to local storage, reporting progress as it goes.
  Future<void> download(
    String itemId,
    Uri source, {
    String title = '',
    double durationSeconds = 0,
  }) async {
    final status = statusFor(itemId);
    if (status == DownloadStatus.downloading || status == DownloadStatus.downloaded) return;

    _transient[itemId] = DownloadStatus.downloading;
    _progress[itemId] = 0;
    _lastNotifiedPercent[itemId] = 0;
    notifyListeners();

    final dir = await _dataDir();
    final tmp = File('${dir.path}/$itemId.part');
    HttpClient? client;
    IOSink? sink;
    try {
      client = HttpClient();
      final request = await client.getUrl(source);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength;
      sink = tmp.openWrite();
      var received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final progress = received / total;
          _progress[itemId] = progress;
          // Throttle notifications to whole-percent changes so a large file
          // doesn't spam the UI thread on every byte chunk.
          final percent = (progress * 100).floor();
          if (percent != _lastNotifiedPercent[itemId]) {
            _lastNotifiedPercent[itemId] = percent;
            notifyListeners();
          }
        }
      }
      await sink.close();
      sink = null;

      final finalFile = File('${dir.path}/$itemId');
      if (finalFile.existsSync()) finalFile.deleteSync();
      tmp.renameSync(finalFile.path);

      _entries[itemId] = _Entry(file: itemId, title: title, durationSeconds: durationSeconds);
      _transient.remove(itemId);
      _progress.remove(itemId);
      _lastNotifiedPercent.remove(itemId);
      await _saveIndex();
      notifyListeners();
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      if (tmp.existsSync()) tmp.deleteSync();
      _transient[itemId] = DownloadStatus.failed;
      _progress.remove(itemId);
      _lastNotifiedPercent.remove(itemId);
      notifyListeners();
    } finally {
      client?.close();
    }
  }

  /// Removes [itemId]'s local copy (and index entry).
  Future<void> delete(String itemId) async {
    final entry = _entries.remove(itemId);
    if (entry != null) {
      final dir = await _dataDir();
      final file = File('${dir.path}/${entry.file}');
      if (file.existsSync()) file.deleteSync();
      await _saveIndex();
    }
    _transient.remove(itemId);
    _progress.remove(itemId);
    notifyListeners();
  }
}

class _Entry {
  _Entry({required this.file, required this.title, required this.durationSeconds});
  final String file;
  final String title;
  final double durationSeconds;
}
