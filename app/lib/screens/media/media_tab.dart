import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../state/nexus_data_source.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';
import '../security/tab_header.dart';

/// Media tab (Section 5): Now Playing hero (real playback when connected to
/// a server with a scanned library - see `server/lib/media/`), 3-stat row,
/// Continue Watching grid (tap a tile to play it).
class MediaTab extends StatelessWidget {
  const MediaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final compound = store.compound;
        final nowPlaying = compound.nowPlaying;
        return Container(
          color: NexusColors.background,
          child: Column(
            children: [
              const TabHeader(title: 'Media', pillLabel: 'Jellyfin', pillColor: NexusColors.purple),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    if (nowPlaying != null) _NowPlayingCard(nowPlaying: nowPlaying, store: store),
                    const SizedBox(height: 20),
                    _StatsRow(stats: compound.mediaStats),
                    const SizedBox(height: 20),
                    Text('Continue Watching', style: NexusText.footnote),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.68,
                      children: [
                        for (final item in compound.continueWatching)
                          _PosterTile(item: item, onTap: () => store.playLibraryItem(item.id)),
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
  const _NowPlayingCard({required this.nowPlaying, required this.store});

  final NowPlaying nowPlaying;
  final NexusDataSource store;

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

  void _syncPlayer() {
    final uri = widget.store.mediaStreamUri(widget.nowPlaying.itemId);
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
    final controller = _controller;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: NexusColors.surface, borderRadius: BorderRadius.circular(NexusRadii.card)),
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
            Text(nowPlaying.title, style: NexusText.headline),
            const SizedBox(height: 2),
            Text(_metaLine(nowPlaying), style: NexusText.footnote),
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

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final MediaLibraryStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCell(value: stats.movieCount, label: 'Movies')),
        Expanded(child: _StatCell(value: stats.showCount, label: 'Shows')),
        Expanded(child: _StatCell(value: stats.episodeCount, label: 'Episodes')),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
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

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.item, required this.onTap});

  final ContinueWatchingItem item;
  final VoidCallback onTap;

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
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 3,
                      color: const Color(0x22000000),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: item.progress,
                        child: Container(color: NexusColors.purple),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(item.title, style: NexusText.footnote, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
