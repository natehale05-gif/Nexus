import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../../icons/nexus_icons.dart';
import '../../../state/compound_scope.dart';
import '../../../theme/text_styles.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/drag_track.dart';
import '../../../widgets/expand_section.dart';
import '../../../widgets/nexus_switch.dart';
import 'device_row_shell.dart';

/// Grill/Traeger device row + expanded control (Section 4) - a first-class
/// device type, not an afterthought. Also surfaces the hard cloud
/// dependency unique to this integration (Section 8): a distinct
/// "offline (cloud unreachable)" state, different from "off".
class GrillRow extends StatefulWidget {
  const GrillRow({super.key, required this.device});

  final GrillDevice device;

  @override
  State<GrillRow> createState() => _GrillRowState();
}

class _GrillRowState extends State<GrillRow> {
  bool _expanded = false;

  String get _summary {
    final device = widget.device;
    if (!device.cloudOnline) return 'Offline (cloud unreachable)';
    if (!device.on) return 'Off';
    final probeText = device.probe != null ? ' · probe ${device.probe!.round()}°' : '';
    final pelletsSuffix = device.pellets < 20 ? ' · pellets low' : '';
    return '${device.temp.round()}° now · ${device.set.round()}° set$probeText$pelletsSuffix';
  }

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    final device = widget.device;
    final lowPellets = device.pellets < 20 && device.on;

    return DeviceRowShell(
      onTap: () => setState(() => _expanded = !_expanded),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: device.on ? NexusColors.grill.withValues(alpha: 0.16) : NexusColors.secondarySurface,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(
          child: NexusIcon(
            NexusGlyph.flame,
            size: 19,
            filled: device.on,
            color: device.on ? NexusColors.grill : NexusColors.textFaint,
          ),
        ),
      ),
      title: device.name,
      subtitle: _summary,
      subtitleColor: !device.cloudOnline
          ? NexusColors.textFaint
          : (lowPellets ? NexusColors.red : null),
      trailing: NexusSwitch(
        value: device.on,
        activeColor: NexusColors.grill,
        onChanged: (v) => store.setGrillOn(device.id, v),
      ),
      expanded: _expanded,
      child: ExpandSection(
        expanded: _expanded,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Column(
            children: [
              if (!device.cloudOnline) _CloudUnreachableBanner(),
              _IgniteRow(device: device, onChanged: (v) => store.setGrillOn(device.id, v)),
              const SizedBox(height: 16),
              Opacity(
                opacity: device.on ? 1 : 0.4,
                child: IgnorePointer(
                  ignoring: !device.on,
                  child: Column(
                    children: [
                      DragTrack(
                        min: 165,
                        max: 500,
                        value: device.set,
                        enabled: device.on,
                        gradientColors: const [Color(0xFFFFAB84), NexusColors.grill],
                        labelBuilder: (v) => '${v.round()}°F',
                        onChanged: (v) => store.setGrillTarget(device.id, (v / 5).round() * 5),
                      ),
                      const SizedBox(height: 10),
                      PresetRow(
                        presets: const [
                          PresetValue(165, 'Smoke'),
                          PresetValue(225, '225°'),
                          PresetValue(275, '275°'),
                          PresetValue(350, '350°'),
                          PresetValue(450, '450°'),
                          PresetValue(500, '500°'),
                        ],
                        selectedValue: device.set,
                        accentColor: NexusColors.grill,
                        enabled: device.on,
                        onSelect: (v) => store.setGrillTarget(device.id, v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ProbeRow(device: device),
              const SizedBox(height: 10),
              _PelletRow(device: device),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudUnreachableBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NexusColors.textFaint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          NexusIcon(NexusGlyph.cloudOff, size: 16, color: NexusColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cloud connection to Traeger is unreachable - live status may be stale.',
              style: NexusText.footnote,
            ),
          ),
        ],
      ),
    );
  }
}

class _IgniteRow extends StatelessWidget {
  const _IgniteRow({required this.device, required this.onChanged});

  final GrillDevice device;
  final ValueChanged<bool> onChanged;

  String get _subtext {
    if (!device.on) return 'Auger + hot rod start cycle';
    if ((device.temp - device.set).abs() <= 3) return 'Holding ${device.set.round()}°';
    return 'Heating to ${device.set.round()}°';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device.on ? 'Running' : 'Ignite', style: NexusText.headline),
              const SizedBox(height: 2),
              Text(_subtext, style: NexusText.footnote),
            ],
          ),
        ),
        NexusSwitch(value: device.on, activeColor: NexusColors.grill, onChanged: onChanged),
      ],
    );
  }
}

class _ProbeRow extends StatelessWidget {
  const _ProbeRow({required this.device});

  final GrillDevice device;

  @override
  Widget build(BuildContext context) {
    final connected = device.probe != null && device.probeTarget != null;
    final done = connected && device.probe! >= device.probeTarget!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: NexusColors.secondarySurface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          NexusIcon(NexusGlyph.thermostat, size: 17, color: connected ? NexusColors.blue : NexusColors.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Meat probe', style: NexusText.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  connected
                      ? '${device.probe!.round()}° internal · target ${device.probeTarget!.round()}°'
                      : 'Not connected',
                  style: NexusText.footnote.copyWith(color: connected ? NexusColors.blue : NexusColors.textMuted),
                ),
              ],
            ),
          ),
          if (connected)
            Text(
              done ? 'Done' : '${(device.probeTarget! - device.probe!).round()}° to go',
              style: NexusText.bodyMedium.copyWith(
                color: done ? NexusColors.green : NexusColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _PelletRow extends StatelessWidget {
  const _PelletRow({required this.device});

  final GrillDevice device;

  @override
  Widget build(BuildContext context) {
    final low = device.pellets < 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Pellet hopper', style: NexusText.bodyMedium),
            const Spacer(),
            Text(
              '${device.pellets}%',
              style: NexusText.bodyMedium.copyWith(
                color: low ? NexusColors.red : NexusColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LayoutBuilder(builder: (context, constraints) {
            return Stack(
              children: [
                Container(height: 10, width: constraints.maxWidth, color: NexusColors.secondarySurface),
                Container(
                  height: 10,
                  width: constraints.maxWidth * (device.pellets / 100),
                  color: low ? NexusColors.red : const Color(0xFF8B5E34),
                ),
              ],
            );
          }),
        ),
        if (low) ...[
          const SizedBox(height: 6),
          Text(
            'Refill before your next long cook',
            style: NexusText.footnote.copyWith(color: NexusColors.red),
          ),
        ],
      ],
    );
  }
}
