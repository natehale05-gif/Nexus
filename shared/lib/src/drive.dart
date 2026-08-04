/// Personal files kept on the compound server - the Drive tab.
///
/// Separate from the media library on purpose. The library is *scanned*: the
/// server walks a folder and works out what's a film and what's an episode.
/// Drive is the opposite - whatever you put there, arranged however you
/// arranged it, browsable as folders.
library;

/// What a Drive entry is, which is all the UI needs to decide how to show it.
enum DriveKind {
  folder,
  image,
  video,
  audio,
  document,
  other;

  static DriveKind fromName(String? raw) {
    for (final kind in DriveKind.values) {
      if (kind.name == raw) return kind;
    }
    return DriveKind.other;
  }
}

/// One file or folder.
class DriveEntry {
  const DriveEntry({
    required this.name,
    required this.path,
    required this.kind,
    this.sizeBytes = 0,
    this.modified,
    this.childCount,
  });

  final String name;

  /// Always relative to the Drive root, with `/` separators and no leading
  /// slash. Keeping it relative is what stops a client from ever naming a
  /// path outside the root.
  final String path;

  final DriveKind kind;
  final int sizeBytes;
  final DateTime? modified;

  /// Folders only: how many entries are inside.
  final int? childCount;

  bool get isFolder => kind == DriveKind.folder;

  /// True for the things that belong in a photo grid rather than a file list.
  bool get isVisualMedia => kind == DriveKind.image || kind == DriveKind.video;

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'kind': kind.name,
        'sizeBytes': sizeBytes,
        if (modified != null) 'modified': modified!.toIso8601String(),
        if (childCount != null) 'childCount': childCount,
      };

  static DriveEntry fromJson(Map<String, dynamic> json) => DriveEntry(
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        kind: DriveKind.fromName(json['kind'] as String?),
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        modified: DateTime.tryParse(json['modified'] as String? ?? ''),
        childCount: (json['childCount'] as num?)?.toInt(),
      );
}

/// A listing of one folder.
class DriveListing {
  const DriveListing({required this.path, required this.entries});

  /// The folder this describes, relative to the root. Empty string is the root.
  final String path;
  final List<DriveEntry> entries;

  /// The path segments, for a breadcrumb trail.
  List<String> get segments =>
      path.isEmpty ? const [] : path.split('/').where((s) => s.isNotEmpty).toList();

  /// The folder above this one, or null at the root.
  String? get parent {
    final parts = segments;
    if (parts.isEmpty) return null;
    return parts.sublist(0, parts.length - 1).join('/');
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'entries': [for (final entry in entries) entry.toJson()],
      };

  static DriveListing fromJson(Map<String, dynamic> json) => DriveListing(
        path: json['path'] as String? ?? '',
        entries: [
          for (final raw in (json['entries'] as List<dynamic>? ?? const []))
            DriveEntry.fromJson((raw as Map).cast<String, dynamic>()),
        ],
      );
}

/// Classifies a filename, so the app and server agree without either one
/// having to sniff file contents.
DriveKind driveKindForName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return DriveKind.other;
  final ext = name.substring(dot + 1).toLowerCase();
  if (const {'jpg', 'jpeg', 'png', 'gif', 'heic', 'heif', 'webp', 'bmp', 'tiff', 'avif'}
      .contains(ext)) {
    return DriveKind.image;
  }
  if (const {'mp4', 'mov', 'm4v', 'mkv', 'avi', 'webm', 'hevc'}.contains(ext)) {
    return DriveKind.video;
  }
  if (const {'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'opus'}.contains(ext)) {
    return DriveKind.audio;
  }
  if (const {
    'pdf', 'txt', 'md', 'rtf', 'doc', 'docx', 'pages', 'xls', 'xlsx', 'numbers',
    'ppt', 'pptx', 'key', 'csv', 'json', 'yaml', 'yml', 'epub',
  }.contains(ext)) {
    return DriveKind.document;
  }
  return DriveKind.other;
}

/// Turns a client-supplied path into one that is guaranteed to stay inside the
/// Drive root, or null if it tried to escape.
///
/// This is the whole security boundary for Drive. A client can name any path
/// it likes; `../../etc/passwd`, an absolute path, a Windows drive letter and
/// a path with a NUL in it all have to come back null rather than resolving to
/// something real. Written as a pure function so it can be tested exhaustively
/// without touching a filesystem.
String? safeDrivePath(String requested) {
  var value = requested.trim().replaceAll(r'\', '/');
  // A NUL truncates a path in some syscalls, so a name containing one can mean
  // two different files depending on who reads it.
  if (value.contains('\u0000')) return null;
  // An absolute path or a drive letter is never relative to the root.
  if (value.startsWith('/')) value = value.substring(1);
  if (RegExp(r'^[A-Za-z]:').hasMatch(value)) return null;

  final out = <String>[];
  for (final segment in value.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      // Refuse rather than silently clamping at the root: a request that
      // tried to climb out is a request the caller got wrong, and quietly
      // returning a different folder's contents is worse than an error.
      return null;
    }
    out.add(segment);
  }
  return out.join('/');
}
