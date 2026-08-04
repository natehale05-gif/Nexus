import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../state/download_manager.dart';
import '../../state/download_scope.dart';
import '../../state/nexus_data_source.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';
import '../security/tab_header.dart';
import '../../widgets/nexus_card.dart';

/// Media tab (Section 5): Now Playing hero (real playback when connected to
/// a server with a scanned library - see `server/lib/media/`), 3-stat row,
/// a Downloaded section (native devices - titles saved for offline
/// playback), and a Continue Watching grid (tap a tile to play it).
class MediaTab extends StatefulWidget {
  const MediaTab({super.key});

  @override
  State<MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends State<MediaTab> {
  /// A locally-chosen "now playing" - set when a downloaded title is tapped,
  /// so it plays from disk even with no server reachable (the server-driven
  /// `compound.nowPlaying` needs a live connection). Cleared when a
  /// streaming title is chosen instead.
  NowPlaying? _localOverride;

  void _playStreaming(String itemId, NexusDataSource store) {
    setState(() => _localOverride = null);
    store.playLibraryItem(itemId);
  }

  void _playDownloaded(DownloadedItem item, NexusDataSource store) {
    // Tell the server too (harmless / no-op when offline), so other devices
    // reflect it when a connection is available.
    store.playLibraryItem(item.id);
    setState(() {
      _localOverride = NowPlaying(
        itemId: item.id,
        title: item.title,
        durationSeconds: item.durationSeconds,
        positionSeconds: store.compound.playbackPositions[item.id] ?? 0,
        isPlaying: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    final downloads = DownloadScope.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([store, downloads]),
      builder: (context, _) {
        final compound = store.compound;
        final nowPlaying = _localOverride ?? compound.nowPlaying;
        final downloaded = downloads.isSupported ? downloads.downloaded : const <DownloadedItem>[];
        return Container(
          color: NexusColors.background,
          child: Column(
            children: [
              const TabHeader(title: 'Media', pillLabel: 'Library', pillColor: NexusColors.purple),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    if (nowPlaying != null)
                      _NowPlayingCard(nowPlaying: nowPlaying, store: store, downloads: downloads),
                    const SizedBox(height: 20),
                    _StatsRow(stats: compound.mediaStats),
                    if (downloaded.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Downloaded', style: NexusText.footnote),
                      const SizedBox(height: 10),
                      _PosterGrid(
                        children: [
                          for (final item in downloaded)
                            _PosterTile(
                              title: item.title,
                              progress: item.durationSeconds <= 0
                                  ? 0
                                  : ((store.compound.playbackPositions[item.id] ?? 0) / item.durationSeconds)
                                      .clamp(0, 1),
                              onTap: () => _playDownloaded(item, store),
                              trailing: _CornerButton(
                                glyph: NexusGlyph.trash,
                                color: NexusColors.red,
                                onTap: () => downloads.delete(item.id),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (compound.photos.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Photos', style: NexusText.footnote),
                      const SizedBox(height: 10),
                      _PhotoGrid(photos: compound.photos, store: store),
                    ],
                    if (compound.music.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Music', style: NexusText.footnote),
                      const SizedBox(height: 10),
                      _MusicList(
                        tracks: compound.music,
                        store: store,
                        onPlay: (entry) => _playStreaming(entry.id, store),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text('Continue Watching', style: NexusText.footnote),
                    const SizedBox(height: 10),
                    _PosterGrid(
                      children: [
                        for (final item in compound.continueWatching)
                          _PosterTile(
                            title: item.title,
                            progress: item.progress,
                            onTap: () => _playStreaming(item.id, store),
                            trailing: downloads.isSupported
                                ? _DownloadButton(
                                    status: downloads.statusFor(item.id),
                                    progress: downloads.progressFor(item.id),
                                    onDownload: () {
                                      final uri = store.mediaStreamUri(item.id);
                                      if (uri != null) {
                                        downloads.download(
                                          item.id,
                                          uri,
                                          title: item.title,
                                          durationSeconds: item.durationSeconds,
                                        );
                                      }
                                    },
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NowPlayingCard extends StatefulWidget {
  const _NowPlayingCard({required this.nowPlaying, required this.store, required this.downloads});

  final NowPlaying nowPlaying;
  final NexusDataSource store;
  final DownloadManager downloads;

  @override
  State<_NowPlayingCard> createState() => _NowPlayingCardState();
}

class _NowPlayingCardState extends State<_NowPlayingCard> {
  Player? _player;
  VideoController? _controller;
  String? _boundItemId;
  Timer? _reportTimer;

  @override
  void initState() {
    super.initState();
    _syncPlayer();
  }

  @override
  void didUpdateWidget(covariant _NowPlayingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlayer();
  }

  @override
  void dispose() {
    _teardownPlayer();
    super.dispose();
  }

  /// The source to play from: a local downloaded file if present (works
  /// offline), otherwise the server stream URL.
  Uri? _sourceFor(String itemId) =>
      widget.downloads.localUri(itemId) ?? widget.store.mediaStreamUri(itemId);

  void _syncPlayer() {
    final uri = _sourceFor(widget.nowPlaying.itemId);
    if (uri == null) {
      _teardownPlayer();
      return;
    }
    if (_boundItemId == widget.nowPlaying.itemId && _player != null) return;
    _teardownPlayer();

    final player = Player();
    unawaited(player.open(Media(uri.toString()), play: widget.nowPlaying.isPlaying));
    if (widget.nowPlaying.positionSeconds > 1) {
      unawaited(player.seek(Duration(seconds: widget.nowPlaying.positionSeconds.round())));
    }
    _player = player;
    _controller = VideoController(player);
    _boundItemId = widget.nowPlaying.itemId;
    _reportTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (player.state.playing) {
        widget.store.reportPlaybackPosition(widget.nowPlaying.itemId, player.state.position.inSeconds.toDouble());
      }
    });
    if (mounted) setState(() {});
  }

  void _teardownPlayer() {
    _reportTimer?.cancel();
    _reportTimer = null;
    final player = _player;
    _player = null;
    _controller = null;
    _boundItemId = null;
    if (player != null) unawaited(player.dispose());
  }

  void _togglePlay() {
    _player?.playOrPause();
    widget.store.setNowPlayingState(!widget.nowPlaying.isPlaying);
  }

  void _skip(double deltaSeconds) {
    final player = _player;
    final nowPlaying = widget.nowPlaying;
    if (player != null) {
      var target = player.state.position + Duration(seconds: deltaSeconds.round());
      if (target < Duration.zero) target = Duration.zero;
      final duration = player.state.duration;
      if (duration > Duration.zero && target > duration) target = duration;
      unawaited(player.seek(target));
      widget.store.reportPlaybackPosition(nowPlaying.itemId, target.inSeconds.toDouble());
    } else {
      final target = (nowPlaying.positionSeconds + deltaSeconds).clamp(0, nowPlaying.durationSeconds).toDouble();
      widget.store.reportPlaybackPosition(nowPlaying.itemId, target);
    }
  }

  String _metaLine(NowPlaying nowPlaying) {
    final parts = <String>[
      if (nowPlaying.year != null) '${nowPlaying.year}',
      if ((nowPlaying.genre ?? '').isNotEmpty) nowPlaying.genre!,
      '${nowPlaying.runtimeMinutes}m',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final nowPlaying = widget.nowPlaying;
    // Audio tracks play through the same player but have no picture, so
    // they keep the compact artwork-style header instead of a black
    // 16:9 video surface.
    final isAudio = widget.store.compound.music.any((m) => m.id == nowPlaying.itemId);
    final controller = isAudio ? null : _controller;
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Video(controller: controller, controls: NoVideoControls),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nowPlaying.title, style: NexusText.headline),
                      const SizedBox(height: 2),
                      Text(_metaLine(nowPlaying), style: NexusText.footnote),
                    ],
                  ),
                ),
                _NowPlayingDownloadControl(nowPlaying: nowPlaying, store: widget.store, downloads: widget.downloads),
              ],
            ),
          ] else
            Row(
              children: [
                Container(
                  width: 60,
                  height: 84,
                  decoration: BoxDecoration(color: NexusColors.secondarySurface, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: NexusIcon(NexusGlyph.tv, size: 24, color: NexusColors.textFaint)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nowPlaying.title, style: NexusText.headline),
                      const SizedBox(height: 4),
                      Text(_metaLine(nowPlaying), style: NexusText.footnote),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LayoutBuilder(builder: (context, constraints) {
              return Stack(
                children: [
                  Container(height: 4, width: constraints.maxWidth, color: NexusColors.secondarySurface),
                  Container(height: 4, width: constraints.maxWidth * nowPlaying.progress, color: NexusColors.purple),
                ],
              );
            }),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PressScale(
                onTap: () => _skip(-15),
                child: NexusIcon(NexusGlyph.skipBack, size: 22, color: NexusColors.textPrimary),
              ),
              const SizedBox(width: 28),
              PressScale(
                onTap: _togglePlay,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: NexusColors.purple, shape: BoxShape.circle),
                  child: Center(
                    child: NexusIcon(
                      nowPlaying.isPlaying ? NexusGlyph.pauseFill : NexusGlyph.playFill,
                      size: 22,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 28),
              PressScale(
                onTap: () => _skip(15),
                child: NexusIcon(NexusGlyph.skipForward, size: 22, color: NexusColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The download affordance shown next to the Now Playing title: a labeled
/// button reflecting whether the current title is saved for offline
/// playback. Hidden on platforms that can't download (web).
class _NowPlayingDownloadControl extends StatelessWidget {
  const _NowPlayingDownloadControl({required this.nowPlaying, required this.store, required this.downloads});

  final NowPlaying nowPlaying;
  final NexusDataSource store;
  final DownloadManager downloads;

  @override
  Widget build(BuildContext context) {
    if (!downloads.isSupported) return const SizedBox.shrink();
    final status = downloads.statusFor(nowPlaying.itemId);
    return _DownloadButton(
      status: status,
      progress: downloads.progressFor(nowPlaying.itemId),
      onDownload: () {
        final uri = store.mediaStreamUri(nowPlaying.itemId);
        if (uri != null) {
          downloads.download(
            nowPlaying.itemId,
            uri,
            title: nowPlaying.title,
            durationSeconds: nowPlaying.durationSeconds,
          );
        }
      },
      onDelete: () => downloads.delete(nowPlaying.itemId),
    );
  }
}

/// A small circular control showing download state: tap to download, a ring
/// while downloading, a check when done (tap to remove).
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.status,
    required this.progress,
    required this.onDownload,
    this.onDelete,
  });

  final DownloadStatus status;
  final double progress;
  final VoidCallback onDownload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Widget inner;
    VoidCallback? onTap;
    switch (status) {
      case DownloadStatus.notDownloaded:
        inner = NexusIcon(NexusGlyph.download, size: 16, color: NexusColors.blue);
        onTap = onDownload;
      case DownloadStatus.downloading:
        inner = _ProgressRing(progress: progress);
        onTap = null;
      case DownloadStatus.downloaded:
        inner = NexusIcon(NexusGlyph.check, size: 16, color: NexusColors.green);
        onTap = onDelete;
      case DownloadStatus.failed:
        inner = NexusIcon(NexusGlyph.download, size: 16, color: NexusColors.red);
        onTap = onDownload;
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: NexusColors.secondarySurface, shape: BoxShape.circle),
        child: Center(child: inner),
      ),
    );
  }
}

/// A tappable corner badge (e.g. a trash button on a downloaded tile).
class _CornerButton extends StatelessWidget {
  const _CornerButton({required this.glyph, required this.color, required this.onTap});

  final NexusGlyph glyph;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(color: Color(0xCC000000), shape: BoxShape.circle),
        child: Center(child: NexusIcon(glyph, size: 13, color: color)),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _ProgressRingPainter(progress: progress.clamp(0, 1))),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1.5;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = NexusColors.separator;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = NexusColors.blue;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Photos as a square thumbnail grid, loaded straight from the server's
/// media stream endpoint (same per-item token as video). Tapping one opens
/// it full-screen.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.store});

  final List<LibraryEntry> photos;
  final NexusDataSource store;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final photo in photos)
          PressScale(
            onTap: () => _openViewer(context, photo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _PhotoThumb(uri: store.mediaStreamUri(photo.id)),
            ),
          ),
      ],
    );
  }

  void _openViewer(BuildContext context, LibraryEntry photo) {
    final uri = store.mediaStreamUri(photo.id);
    if (uri == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: const Color(0xE6000000),
        pageBuilder: (context, _, _) => _PhotoViewer(title: photo.title, uri: uri),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.uri});

  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    if (uri == null) {
      // Local-demo-mode: no server to fetch from.
      return Container(
        color: NexusColors.secondarySurface,
        child: Center(child: NexusIcon(NexusGlyph.tv, size: 18, color: NexusColors.textFaint)),
      );
    }
    return Image.network(
      uri.toString(),
      fit: BoxFit.cover,
      errorBuilder: (context, _, _) => Container(
        color: NexusColors.secondarySurface,
        child: Center(child: NexusIcon(NexusGlyph.close, size: 16, color: NexusColors.textFaint)),
      ),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(color: NexusColors.secondarySurface),
    );
  }
}

/// Full-screen photo, tap anywhere to dismiss.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.title, required this.uri});

  final String title;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: NexusText.headline.copyWith(color: const Color(0xFFFFFFFF)),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(child: Center(child: Image.network(uri.toString(), fit: BoxFit.contain))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Tap to close', style: NexusText.footnote),
            ),
          ],
        ),
      ),
    );
  }
}

/// Music tracks as a tappable list - playback runs through the same player
/// as video (audio-only media just renders no video surface).
class _MusicList extends StatelessWidget {
  const _MusicList({required this.tracks, required this.store, required this.onPlay});

  final List<LibraryEntry> tracks;
  final NexusDataSource store;
  final ValueChanged<LibraryEntry> onPlay;

  String _duration(double seconds) {
    if (seconds <= 0) return '';
    final total = seconds.round();
    final minutes = total ~/ 60;
    final secs = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: NexusColors.surface, borderRadius: BorderRadius.circular(NexusRadii.card)),
      child: Column(
        children: [
          for (var i = 0; i < tracks.length; i++) ...[
            if (i > 0) Container(height: 1, color: NexusColors.separator),
            PressScale(
              onTap: () => onPlay(tracks[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    NexusIcon(NexusGlyph.playFill, size: 14, color: NexusColors.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tracks[i].title,
                              style: NexusText.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                          if ((tracks[i].subtitle ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(tracks[i].subtitle!,
                                style: NexusText.footnote, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(_duration(tracks[i].durationSeconds), style: NexusText.footnote),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final MediaLibraryStats stats;

  @override
  Widget build(BuildContext context) {
    // Movies/Shows/Episodes always; Photos/Music only once the library has
    // some, so the row doesn't get cramped with zeroes.
    final cells = <Widget>[
      _StatCell(value: stats.movieCount, label: 'Movies'),
      _StatCell(value: stats.showCount, label: 'Shows'),
      _StatCell(value: stats.episodeCount, label: 'Episodes'),
      if (stats.photoCount > 0) _StatCell(value: stats.photoCount, label: 'Photos'),
      if (stats.trackCount > 0) _StatCell(value: stats.trackCount, label: 'Tracks'),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      // Three per row, wrapping to a second row when photos/music appear.
      final width = (constraints.maxWidth - 2 * 8) / 3;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final cell in cells) SizedBox(width: width, child: cell)],
      );
    });
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: NexusColors.surface, borderRadius: BorderRadius.circular(NexusRadii.card)),
      child: Column(
        children: [
          Text('$value', style: NexusText.title),
          const SizedBox(height: 2),
          Text(label, style: NexusText.footnote),
        ],
      ),
    );
  }
}

class _PosterGrid extends StatelessWidget {
  const _PosterGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.68,
      children: children,
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.title, required this.progress, required this.onTap, this.trailing});

  final String title;
  final double progress;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: NexusColors.secondarySurface, borderRadius: BorderRadius.circular(10)),
              child: Stack(
                children: [
                  Center(child: NexusIcon(NexusGlyph.tv, size: 20, color: NexusColors.textFaint)),
                  if (trailing != null) Positioned(top: 6, right: 6, child: trailing!),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 3,
                      color: const Color(0x22000000),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(color: NexusColors.purple),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: NexusText.footnote, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
