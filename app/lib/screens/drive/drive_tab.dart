import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';

import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../state/nexus_data_source.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/nexus_card.dart';
import '../security/tab_header.dart';
import 'drive_files.dart';
import 'drive_media.dart';

/// Everything personal that lives on the server.
///
/// Split the way Apple splits it, because the split is a real one: Files is a
/// folder tree you arranged and can put anything in, Media is a wall of your
/// own photos and video with no folders in sight. The same bytes on disk back
/// both - Media is just Files with the pictures pulled forward.
class DriveTab extends StatefulWidget {
  const DriveTab({super.key});

  @override
  State<DriveTab> createState() => _DriveTabState();
}

enum _DriveSection { files, media }

class _DriveTabState extends State<DriveTab> {
  _DriveSection _section = _DriveSection.media;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    final hasServer = store.connectionStatus == ConnectionStatus.connected;

    return Container(
      color: NexusColors.background,
      child: Column(
        children: [
          const TabHeader(title: 'Drive'),
          if (!hasServer)
            const Expanded(child: _NoServer())
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _SegmentedControl(
                labels: const ['Media', 'Files'],
                index: _section == _DriveSection.media ? 0 : 1,
                onChanged: (i) => setState(
                  () => _section = i == 0 ? _DriveSection.media : _DriveSection.files,
                ),
              ),
            ),
            Expanded(
              child: switch (_section) {
                _DriveSection.media => DriveMediaView(store: store),
                _DriveSection.files => DriveFilesView(store: store),
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Drive is server-only by definition - these are files on the machine that
/// holds them, not on the phone in your hand.
class _NoServer extends StatelessWidget {
  const _NoServer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: NexusCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No server connected', style: NexusText.bodyMedium),
              const SizedBox(height: 6),
              Text(
                'Drive holds your files and personal media on the compound '
                'server. Connect to one in Settings and everything on it shows '
                'up here, on every device you have paired.',
                style: NexusText.subhead.copyWith(color: NexusColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An iOS-style segmented control.
class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: NexusColors.secondarySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: NexusDurations.fast,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == index ? NexusColors.surface : null,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: i == index ? NexusShadows.card : null,
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: NexusText.bodyMedium.copyWith(
                        fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                        color: i == index ? NexusColors.textPrimary : NexusColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Formats a byte count the way a file browser does.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value < 10 ? value.toStringAsFixed(1) : value.round()} ${units[unit]}';
}

/// The icon and tint a Drive entry should carry, in one place so the file
/// list and any future grid can't drift apart.
(NexusGlyph, Color) visualFor(DriveKind kind) => switch (kind) {
      DriveKind.folder => (NexusGlyph.folder, NexusColors.blue),
      DriveKind.image => (NexusGlyph.photo, NexusColors.purple),
      DriveKind.video => (NexusGlyph.tv, NexusColors.purple),
      DriveKind.audio => (NexusGlyph.signal, NexusColors.green),
      DriveKind.document => (NexusGlyph.info, NexusColors.textMuted),
      DriveKind.other => (NexusGlyph.info, NexusColors.textFaint),
    };
