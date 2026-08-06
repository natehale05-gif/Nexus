/// Deciding what to copy into Drive, and what to leave alone.
///
/// Pure, so the rules can be tested exhaustively without a filesystem. The
/// interesting ones are all about iCloud: a folder that looks like a photo
/// library is mostly not photos, and a file that looks like a photo is often
/// a placeholder for one that lives in the cloud.
library;

/// One folder being pulled into Drive.
class SyncSource {
  const SyncSource({required this.label, required this.path});

  /// Where it lands inside Drive - so photos arrive under `Photos/` rather
  /// than in a heap at the root.
  final String label;

  /// The folder on this machine to read from.
  final String path;

  Map<String, dynamic> toJson() => {'label': label, 'path': path};
}

/// Parses `NEXUS_SYNC_SOURCES`: a comma-separated list of `Label=/path`
/// pairs, e.g.
///   NEXUS_SYNC_SOURCES="Photos=/Users/me/Pictures/iCloud Photos,Docs=/Users/me/Documents"
List<SyncSource> parseSyncSources(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  final sources = <SyncSource>[];
  for (final part in raw.split(',')) {
    final entry = part.trim();
    if (entry.isEmpty) continue;
    final split = entry.indexOf('=');
    // A bare path with no label lands under a folder named after itself,
    // which beats refusing to sync because someone forgot the "Photos=".
    final label = split == -1
        ? entry.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last
        : entry.substring(0, split).trim();
    final path = split == -1 ? entry : entry.substring(split + 1).trim();
    if (label.isEmpty || path.isEmpty) continue;
    sources.add(SyncSource(label: label, path: path));
  }
  return sources;
}

/// Where Apple keeps things, per platform.
///
/// These are the folders a Mac already has once iCloud Photos and iCloud
/// Drive are switched on - which is what makes "a photo I took on my phone
/// ends up on the server" work without the phone doing anything: the photo
/// syncs to the Mac by itself, and NEXUS picks it up from there.
List<SyncSource> appleSyncCandidates(String home, {required String os}) {
  switch (os) {
    case 'macos':
      return [
        // The Photos library is a package, not a folder of pictures; the
        // originals live inside it. Reading them directly is unsupported and
        // breaks between OS versions, so this points at the folder Photos
        // writes to when "Download Originals to this Mac" plus a shared or
        // exported album is used, and at iCloud Drive, which is a real tree.
        SyncSource(label: 'Photos', path: '$home/Pictures/iCloud Photos'),
        SyncSource(
          label: 'Files',
          path: '$home/Library/Mobile Documents/com~apple~CloudDocs',
        ),
        SyncSource(label: 'Desktop', path: '$home/Desktop'),
        SyncSource(label: 'Documents', path: '$home/Documents'),
      ];
    case 'windows':
      // iCloud for Windows creates these when Photos and Drive are enabled.
      return [
        SyncSource(label: 'Photos', path: '$home\\Pictures\\iCloud Photos'),
        SyncSource(label: 'Files', path: '$home\\iCloudDrive'),
      ];
    default:
      return const [];
  }
}

/// True for a file NEXUS should not copy.
///
/// The important case is iCloud's placeholders. When a Mac hasn't downloaded
/// a file yet, what's on disk is a tiny `.filename.icloud` stub, not the
/// file - copying one produces a Drive full of things that look like photos
/// and aren't. The rest are the metadata files every OS scatters around.
bool shouldSkipFile(String name, int sizeBytes) {
  if (name.startsWith('.')) {
    // Covers .DS_Store, ._resource forks, and every .icloud placeholder,
    // which are all dotfiles.
    return true;
  }
  if (name.endsWith('.icloud')) return true;
  const noise = {'desktop.ini', 'thumbs.db', 'Icon\r'};
  if (noise.contains(name)) return true;
  // A zero-byte file is either nothing worth copying or a placeholder that
  // hasn't materialised.
  if (sizeBytes <= 0) return true;
  return false;
}

/// True for a folder not worth walking into.
bool shouldSkipFolder(String name) {
  if (name.startsWith('.')) return true;
  // Photos and Final Cut keep whole libraries as packages: thousands of
  // internal files, none of which is a thing anyone wants in Drive.
  const packages = {'.photoslibrary', '.photolibrary', '.fcpbundle', '.aplibrary'};
  return packages.any((suffix) => name.endsWith(suffix));
}

/// What NEXUS has already pulled in.
///
/// Keyed by source path so a file that moves inside Drive isn't downloaded
/// again, and matched on size and modification time so an edited original
/// does come through a second time.
class SyncRecord {
  const SyncRecord({required this.sizeBytes, required this.modifiedMs});

  final int sizeBytes;
  final int modifiedMs;

  bool matches(int size, int modifiedMs) =>
      size == sizeBytes && modifiedMs == this.modifiedMs;

  Map<String, dynamic> toJson() => {'size': sizeBytes, 'modified': modifiedMs};

  static SyncRecord fromJson(Map<String, dynamic> json) => SyncRecord(
        sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
        modifiedMs: (json['modified'] as num?)?.toInt() ?? 0,
      );
}

/// Where a source file lands inside Drive.
///
/// The label plus the path relative to the source root, so the shape someone
/// arranged on their Mac survives the trip.
String driveDestination(String label, String relativePath) {
  final clean = relativePath.replaceAll(r'\', '/').split('/').where((s) => s.isNotEmpty);
  return [label, ...clean].join('/');
}
