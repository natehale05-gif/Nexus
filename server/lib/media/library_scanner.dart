import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'ffprobe.dart';
import 'library_item.dart';

/// Walks a filesystem root for movie/TV files and builds [LibraryItem]s out
/// of them. No metadata service (TMDB etc.) is involved - titles/years/
/// episode numbers are parsed heuristically from file and folder names, so
/// results won't always be perfect. Good enough for a homelab library.
class LibraryScanner {
  LibraryScanner(this.root);

  final Directory root;

  static const _videoExtensions = {'.mp4', '.mkv', '.mov', '.m4v', '.avi', '.webm'};
  static const _photoExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'};
  static const _musicExtensions = {'.mp3', '.m4a', '.flac', '.wav', '.aac', '.ogg', '.opus'};

  static final _episodePattern = RegExp(r'[Ss](\d{1,2})[Ee](\d{1,3})');
  static final _yearPattern = RegExp(r'\((19|20)\d{2}\)|\b(19|20)\d{2}\b');

  Future<List<LibraryItem>> scan() async {
    if (!root.existsSync()) return [];
    final items = <LibraryItem>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (_photoExtensions.contains(ext)) {
        items.add(_simpleEntry(entity, LibraryItemKind.photo));
        continue;
      }
      if (_musicExtensions.contains(ext)) {
        // Music needs a real duration for the player's scrubber; photos
        // don't, so only pay the ffprobe cost here.
        items.add(_simpleEntry(entity, LibraryItemKind.music,
            durationSeconds: await probeDurationSeconds(entity.path)));
        continue;
      }
      if (!_videoExtensions.contains(ext)) continue;
      final durationSeconds = await probeDurationSeconds(entity.path);
      items.add(_parse(entity, durationSeconds));
    }
    return items;
  }

  /// Photos and music: title from the filename, "subtitle" from the folder
  /// it lives in (which is usually the album, or the shoot/event).
  LibraryItem _simpleEntry(File file, LibraryItemKind kind, {double durationSeconds = 0}) {
    final relative = p.relative(file.path, from: root.path);
    return LibraryItem(
      id: sha256.convert(utf8.encode(relative)).toString().substring(0, 16),
      path: file.path,
      title: _cleanTitle(p.basenameWithoutExtension(file.path)),
      kind: kind,
      durationSeconds: durationSeconds,
      showTitle: p.dirname(relative) == '.' ? null : _cleanTitle(p.basename(p.dirname(file.path))),
    );
  }

  LibraryItem _parse(File file, double durationSeconds) {
    final relative = p.relative(file.path, from: root.path);
    final id = sha256.convert(utf8.encode(relative)).toString().substring(0, 16);
    final base = p.basenameWithoutExtension(file.path);

    final episodeMatch = _episodePattern.firstMatch(base);
    if (episodeMatch != null) {
      final season = int.parse(episodeMatch.group(1)!);
      final episode = int.parse(episodeMatch.group(2)!);
      final showTitle = _cleanTitle(p.basename(p.dirname(file.path)));
      final title = _cleanTitle(base.substring(0, episodeMatch.start));
      return LibraryItem(
        id: id,
        path: file.path,
        title: title.isEmpty ? showTitle : title,
        kind: LibraryItemKind.episode,
        showTitle: showTitle,
        seasonNumber: season,
        episodeNumber: episode,
        durationSeconds: durationSeconds,
      );
    }

    final yearMatch = _yearPattern.firstMatch(base);
    final year = yearMatch == null
        ? null
        : int.tryParse(yearMatch.group(0)!.replaceAll(RegExp(r'[()]'), ''));
    final titleSource = yearMatch == null ? base : base.substring(0, yearMatch.start);
    return LibraryItem(
      id: id,
      path: file.path,
      title: _cleanTitle(titleSource),
      year: year,
      kind: LibraryItemKind.movie,
      durationSeconds: durationSeconds,
    );
  }

  String _cleanTitle(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[._]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? raw : cleaned;
  }
}
