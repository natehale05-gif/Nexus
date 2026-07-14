import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
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
                      Text('Active Alerts', style: NexusText.footnote),
                      const SizedBox(height: 10),
                      for (final alert in alerts) _AlertCard(alert: alert),
                      const SizedBox(height: 20),
                    ],
                    Text('Cameras', style: NexusText.footnote),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        for (final camera in demoCameras)
                          _CameraTile(
                            camera: camera,
                            expanded: _expandedCamera == camera.name,
                            onTap: () => setState(
                              () => _expandedCamera = _expandedCamera == camera.name ? null : camera.name,
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

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.camera, required this.expanded, required this.onTap});

  final SecurityCamera camera;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF17181C),
          borderRadius: BorderRadius.circular(NexusRadii.card),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: NexusIcon(NexusGlyph.camera, size: 26, color: const Color(0xFFFFFFFF).withValues(alpha: 0.24))),
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
                      color: camera.hasMotion ? NexusColors.red : NexusColors.green,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    camera.hasMotion ? 'MOTION' : 'LIVE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: const Color(0xFFFFFFFF).withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Text(
                camera.name,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFFFFFFF).withValues(alpha: 0.9)),
              ),
            ),
            if (expanded)
              Positioned.fill(
                child: Container(
                  color: const Color(0xCC000000),
                  padding: const EdgeInsets.all(10),
                  child: const Center(
                    child: Text(
                      'Connect server to enable live feed',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFFE5E5EA), fontWeight: FontWeight.w500),
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
