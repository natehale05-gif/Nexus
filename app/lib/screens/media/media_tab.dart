import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../state/nexus_data_source.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';
import '../security/tab_header.dart';

/// Media tab (Section 5): Now Playing hero, 3-stat row, Continue Watching
/// grid.
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
                        for (final item in compound.continueWatching) _PosterTile(item: item),
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

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({required this.nowPlaying, required this.store});

  final NowPlaying nowPlaying;
  final NexusDataSource store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: NexusColors.surface, borderRadius: BorderRadius.circular(NexusRadii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Text(
                      '${nowPlaying.year} · ${nowPlaying.genre} · ${nowPlaying.runtimeMinutes}m',
                      style: NexusText.footnote,
                    ),
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
                child: NexusIcon(NexusGlyph.skipBack, size: 22, color: NexusColors.textPrimary),
              ),
              const SizedBox(width: 28),
              PressScale(
                onTap: () => store.setNowPlayingState(!nowPlaying.isPlaying),
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
  const _PosterTile({required this.item});

  final ContinueWatchingItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}
