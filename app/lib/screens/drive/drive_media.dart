import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';

import '../../icons/nexus_icons.dart';
import '../../state/nexus_data_source.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/nexus_sheet.dart';
import '../../widgets/press_scale.dart';

/// Your own photos and video, as a wall rather than a folder tree.
///
/// This is the Photos half of Drive. It walks the Drive tree, collects
/// everything that's an image or a video wherever it happens to live, and
/// groups by month - because when you're looking for a picture you remember
/// roughly when it was taken and almost never which folder you filed it in.
class DriveMediaView extends StatefulWidget {
  const DriveMediaView({super.key, required this.store});

  final NexusDataSource store;

  @override
  State<DriveMediaView> createState() => _DriveMediaViewState();
}

class _DriveMediaViewState extends State<DriveMediaView> {
  List<DriveEntry>? _items;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Walks the tree breadth-first, bounded.
  ///
  /// Bounded on purpose: this is a client walking someone's whole disk one
  /// HTTP request per folder, and an unbounded version on a deep tree would
  /// be hundreds of round trips and a screen that never finishes loading.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });

    const maxFolders = 120;
    final queue = <String>[''];
    final found = <DriveEntry>[];
    var visited = 0;
    var reachedServer = false;

    while (queue.isNotEmpty && visited < maxFolders) {
      final listing = await widget.store.listDrive(queue.removeAt(0));
      visited++;
      if (listing == null) continue;
      reachedServer = true;
      for (final entry in listing.entries) {
        if (entry.isFolder) {
          queue.add(entry.path);
        } else if (entry.isVisualMedia) {
          found.add(entry);
        }
      }
    }
    if (!mounted) return;

    // Newest first, which is what a photo library is for.
    found.sort((a, b) {
      final at = a.modified, bt = b.modified;
      if (at == null && bt == null) return a.name.compareTo(b.name);
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    setState(() {
      _items = found;
      _loading = false;
      _failed = !reachedServer;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: Text('Looking through Drive…', style: NexusText.footnote));
    }
    if (_failed) {
      return _centered(
        'Could not reach the server',
        'Your photos live on the compound server. Check the connection under '
            'Settings > Server.',
      );
    }
    final items = _items ?? const <DriveEntry>[];
    if (items.isEmpty) {
      return _centered(
        'No photos or video yet',
        'Anything you put in Drive that is an image or a video shows up here, '
            'newest first, whichever folder it is in.',
      );
    }

    final groups = _groupByMonth(items);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(group.label.toUpperCase(), style: NexusText.sectionHeader),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (final entry in group.entries)
                  _Thumb(
                    entry: entry,
                    uri: widget.store.driveFileUri(entry.path),
                    onTap: () => _openViewer(entry),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
        );
      },
    );
  }

  void _openViewer(DriveEntry entry) {
    showNexusSheet(
      context: context,
      builder: (context) => NexusSheet(
        child: _Viewer(entry: entry, uri: widget.store.driveFileUri(entry.path)),
      ),
    );
  }

  Widget _centered(String title, String body) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: NexusText.headline),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: NexusText.subhead.copyWith(color: NexusColors.textMuted),
              ),
            ],
          ),
        ),
      );
}

class _MonthGroup {
  _MonthGroup(this.label, this.entries);
  final String label;
  final List<DriveEntry> entries;
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

List<_MonthGroup> _groupByMonth(List<DriveEntry> entries) {
  final groups = <String, List<DriveEntry>>{};
  final order = <String>[];
  for (final entry in entries) {
    final date = entry.modified;
    final label = date == null
        // Files whose date the server couldn't read still have to appear
        // somewhere rather than being silently dropped.
        ? 'Undated'
        : '${_monthNames[date.month - 1]} ${date.year}';
    if (!groups.containsKey(label)) {
      groups[label] = [];
      order.add(label);
    }
    groups[label]!.add(entry);
  }
  return [for (final label in order) _MonthGroup(label, groups[label]!)];
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.entry, required this.uri, required this.onTap});

  final DriveEntry entry;
  final Uri? uri;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.97,
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: NexusColors.secondarySurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (entry.kind == DriveKind.image && uri != null)
              Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                // A broken thumbnail should be a grey square, not a red error
                // box in the middle of a photo wall.
                errorBuilder: (context, _, __) => const SizedBox.shrink(),
              )
            else
              Center(
                child: NexusIcon(
                  entry.kind == DriveKind.video ? NexusGlyph.tv : NexusGlyph.photo,
                  size: 20,
                  color: NexusColors.textFaint,
                ),
              ),
            if (entry.kind == DriveKind.video)
              Positioned(
                right: 5,
                bottom: 5,
                child: NexusIcon(
                  NexusGlyph.playFill,
                  size: 13,
                  color: const Color(0xFFFFFFFF).withValues(alpha: 0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Viewer extends StatelessWidget {
  const _Viewer({required this.entry, required this.uri});

  final DriveEntry entry;
  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(entry.name, style: NexusText.headline),
        const SizedBox(height: 4),
        Text(
          [
            entry.path,
            if (entry.sizeBytes > 0) '${(entry.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB',
          ].join('  ·  '),
          style: NexusText.footnote,
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(NexusRadii.chip),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              color: NexusColors.mapBaseDeep,
              child: entry.kind == DriveKind.image && uri != null
                  ? Image.network(uri.toString(), fit: BoxFit.contain)
                  : Center(
                      child: Text(
                        entry.kind == DriveKind.video
                            ? 'Video preview opens in the player'
                            : 'No preview',
                        style: NexusText.footnote.copyWith(
                          color: const Color(0xFFFFFFFF).withValues(alpha: 0.7),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
