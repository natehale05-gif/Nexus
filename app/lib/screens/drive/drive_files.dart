import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';

import '../../icons/nexus_icons.dart';
import '../../state/nexus_data_source.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/edit_prompts.dart';
import '../../widgets/nexus_button.dart';
import '../../widgets/press_scale.dart';
import 'drive_tab.dart';

/// The folder tree, browsed one folder at a time.
///
/// A breadcrumb rather than a back stack: on a compound server the interesting
/// paths are two or three deep, and a trail you can jump around in beats a
/// chain of back taps.
class DriveFilesView extends StatefulWidget {
  const DriveFilesView({super.key, required this.store});

  final NexusDataSource store;

  @override
  State<DriveFilesView> createState() => _DriveFilesViewState();
}

class _DriveFilesViewState extends State<DriveFilesView> {
  String _path = '';
  DriveListing? _listing;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final listing = await widget.store.listDrive(_path);
    if (!mounted) return;
    setState(() {
      _listing = listing;
      _loading = false;
      // Null means "couldn't look", which is a different thing from an empty
      // folder and has to read differently.
      _failed = listing == null;
    });
  }

  void _open(String path) {
    setState(() => _path = path);
    _load();
  }

  Future<void> _newFolder() async {
    final name = await promptForName(
      context,
      title: 'New folder',
      subtitle: _path.isEmpty ? 'In Drive' : 'In $_path',
    );
    if (name == null) return;
    final target = _path.isEmpty ? name : '$_path/$name';
    await widget.store.createDriveFolder(target);
    await _load();
  }

  Future<void> _delete(DriveEntry entry) async {
    final ok = await confirmDelete(
      context,
      title: 'Delete ${entry.name}?',
      detail: entry.isFolder
          ? 'The folder has to be empty. This cannot be undone.'
          : 'The file is removed from the server. This cannot be undone.',
    );
    if (!ok) return;
    final done = await widget.store.deleteDriveEntry(entry.path);
    if (!done && mounted) {
      setState(() => _failed = true);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Breadcrumb(path: _path, onOpen: _open),
        Expanded(
          child: _loading
              ? Center(child: Text('Loading…', style: NexusText.footnote))
              : _failed
                  ? _Message(
                      title: 'Could not reach the server',
                      body: 'Drive lives on the compound server. Check the '
                          'connection under Settings > Server and try again.',
                      action: 'Try again',
                      onAction: _load,
                    )
                  : (listing == null || listing.entries.isEmpty)
                      ? _Message(
                          title: 'Nothing here yet',
                          body: _path.isEmpty
                              ? 'Drive is the compound\'s own storage. Put files '
                                  'in it and they are on every device you have '
                                  'paired.'
                              : 'This folder is empty.',
                          action: 'New folder',
                          onAction: _newFolder,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: listing.entries.length,
                          itemBuilder: (context, index) {
                            final entry = listing.entries[index];
                            return _EntryRow(
                              entry: entry,
                              onTap: entry.isFolder ? () => _open(entry.path) : null,
                              onDelete: () => _delete(entry),
                            );
                          },
                        ),
        ),
        if (!_loading && !_failed)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: NexusButton(
              label: 'New folder',
              style: NexusButtonStyle.tinted,
              onTap: _newFolder,
            ),
          ),
      ],
    );
  }
}

/// Drive > Photos > 2026, each part tappable.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.path, required this.onOpen});

  final String path;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final segments = path.isEmpty ? <String>[] : path.split('/');
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _Crumb(label: 'Drive', onTap: () => onOpen(''), last: segments.isEmpty),
          for (var i = 0; i < segments.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Text('›', style: NexusText.footnote.copyWith(color: NexusColors.textFaint)),
              ),
            ),
            _Crumb(
              label: segments[i],
              onTap: () => onOpen(segments.sublist(0, i + 1).join('/')),
              last: i == segments.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.onTap, required this.last});

  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: NexusText.bodyMedium.copyWith(
            color: last ? NexusColors.textPrimary : NexusColors.blue,
            fontWeight: last ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap, required this.onDelete});

  final DriveEntry entry;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (glyph, color) = visualFor(entry.kind);
    final subtitle = entry.isFolder
        ? '${entry.childCount ?? 0} item${entry.childCount == 1 ? '' : 's'}'
        : formatBytes(entry.sizeBytes);

    return PressScale(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: NexusColors.separator, width: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(child: NexusIcon(glyph, size: 17, color: color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: NexusText.body),
                  const SizedBox(height: 2),
                  Text(subtitle, style: NexusText.footnote),
                ],
              ),
            ),
            PressScale(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: NexusIcon(NexusGlyph.trash, size: 16, color: NexusColors.textFaint),
              ),
            ),
            if (entry.isFolder)
              Text(
                '›',
                style: NexusText.title.copyWith(
                  color: NexusColors.textFaint,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
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
            const SizedBox(height: 16),
            NexusButton(
              label: action,
              style: NexusButtonStyle.tinted,
              expand: false,
              compact: true,
              onTap: onAction,
            ),
          ],
        ),
      ),
    );
  }
}
