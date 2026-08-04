import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../state/app_mode.dart';
import '../../state/compound_scope.dart';
import '../../state/connection_scope.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/nexus_card.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/status_pill.dart';
import 'camera.dart';
import 'tab_header.dart';

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Security tab (Section 5): active alerts (level != info) first, then a
/// 2-column camera grid.
class SecurityTab extends StatefulWidget {
  const SecurityTab({super.key});

  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  String? _expandedCamera;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final alerts = store.compound.alerts.where((a) => a.level != Level.info).toList()
          ..sort((a, b) => b.time.compareTo(a.time));
        // Whatever the paired server declares via NEXUS_CAMERAS. The demo
        // list stands in only in demo mode - showing invented cameras to
        // someone running their own compound is worse than showing none,
        // because it looks like hardware they don't have is online.
        final demo = ConnectionScope.of(context).mode == AppMode.demo;
        final cameras = store.compound.cameras.isNotEmpty
            ? store.compound.cameras
            : (demo ? demoCameras : const <Camera>[]);

        return Container(
          color: NexusColors.background,
          child: Column(
            children: [
              TabHeader(
                title: 'Security',
                pillLabel: alerts.isEmpty ? 'All Clear' : '${alerts.length} Active',
                pillColor: alerts.isEmpty ? NexusColors.green : NexusColors.red,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    if (alerts.isNotEmpty) ...[
                      Text('Active alerts'.toUpperCase(), style: NexusText.sectionHeader),
                      const SizedBox(height: 10),
                      for (final alert in alerts) _AlertCard(alert: alert),
                      const SizedBox(height: 20),
                    ],
                    Text('Cameras'.toUpperCase(), style: NexusText.sectionHeader),
                    const SizedBox(height: 10),
                    if (cameras.isEmpty)
                      NexusCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No cameras yet', style: NexusText.bodyMedium),
                            const SizedBox(height: 6),
                            Text(
                              'Cameras come from the server. Set NEXUS_CAMERAS on it to a '
                              'comma-separated list of name=HLS-URL entries, then reconnect - '
                              'each one shows up here with a live tile.',
                              style: NexusText.subhead.copyWith(color: NexusColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    else
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: [
                          for (final camera in cameras)
                            _CameraTile(
                              camera: camera,
                              expanded: _expandedCamera == camera.id,
                              onTap: () => setState(
                                () => _expandedCamera =
                                    _expandedCamera == camera.id ? null : camera.id,
                              ),
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

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final color = alert.level == Level.crit ? NexusColors.red : NexusColors.amber;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: NexusColors.surface,
        borderRadius: BorderRadius.circular(NexusRadii.card),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: NexusShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    StatusPill(label: alert.level == Level.crit ? 'Critical' : 'Warning', color: color, dense: true),
                    const SizedBox(width: 8),
                    Expanded(child: Text(alert.source, style: NexusText.bodyMedium, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(alert.message, style: NexusText.body),
                const SizedBox(height: 4),
                Text(_timeAgo(alert.time), style: NexusText.footnote),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A camera tile. When the server has a stream URL configured for this
/// camera, tapping it plays the live feed inline; otherwise it says so
/// plainly rather than dead-ending.
class _CameraTile extends StatefulWidget {
  const _CameraTile({required this.camera, required this.expanded, required this.onTap});

  final Camera camera;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_CameraTile> createState() => _CameraTileState();
}

class _CameraTileState extends State<_CameraTile> {
  Player? _player;
  VideoController? _controller;

  @override
  void didUpdateWidget(covariant _CameraTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && widget.camera.isStreamable) {
      _startStream();
    } else if (!widget.expanded) {
      _stopStream();
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _startStream() {
    if (_player != null) return;
    final player = Player();
    unawaited(player.open(Media(widget.camera.streamUrl!)));
    setState(() {
      _player = player;
      _controller = VideoController(player);
    });
  }

  void _stopStream() {
    final player = _player;
    _player = null;
    _controller = null;
    if (player != null) unawaited(player.dispose());
  }

  static const _tileWhite = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    final controller = _controller;
    return PressScale(
      onTap: widget.onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: NexusColors.mapBaseDeep,
          borderRadius: BorderRadius.circular(NexusRadii.card),
          boxShadow: NexusShadows.card,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null)
              Video(controller: controller, controls: NoVideoControls, fit: BoxFit.cover)
            else
              Center(child: NexusIcon(NexusGlyph.camera, size: 26, color: _tileWhite.withValues(alpha: 0.24))),
            Positioned(
              left: 8,
              top: 8,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: camera.hasMotion
                          ? NexusColors.red
                          : (camera.isStreamable ? NexusColors.green : NexusColors.textFaint),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    camera.hasMotion ? 'MOTION' : (camera.isStreamable ? 'LIVE' : 'NO STREAM'),
                    style: NexusText.caption.copyWith(
                      fontSize: 9,
                      color: _tileWhite.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Text(
                camera.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NexusText.footnote.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _tileWhite.withValues(alpha: 0.9),
                ),
              ),
            ),
            if (widget.expanded && !camera.isStreamable)
              Positioned.fill(
                child: Container(
                  color: NexusColors.overlayScrim,
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No stream configured',
                          textAlign: TextAlign.center,
                          style: NexusText.bodyMedium.copyWith(color: _tileWhite),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add this camera to NEXUS_CAMERAS on the server with an HLS URL.',
                          textAlign: TextAlign.center,
                          style: NexusText.footnote.copyWith(color: _tileWhite.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
