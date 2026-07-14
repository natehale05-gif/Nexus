import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../../icons/nexus_icons.dart';
import '../../../state/compound_scope.dart';
import '../../../theme/text_styles.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/arc_dial.dart';
import '../../../widgets/expand_section.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/segmented_control.dart';
import 'device_row_shell.dart';

Color climateModeColor(ClimateMode mode) {
  switch (mode) {
    case ClimateMode.off:
      return NexusColors.textMuted;
    case ClimateMode.heat:
      return NexusColors.amber;
    case ClimateMode.cool:
      return NexusColors.blue;
    case ClimateMode.auto:
      return NexusColors.green;
  }
}

NexusGlyph _climateModeGlyph(ClimateMode mode) {
  switch (mode) {
    case ClimateMode.off:
      return NexusGlyph.power;
    case ClimateMode.heat:
      return NexusGlyph.sun;
    case ClimateMode.cool:
      return NexusGlyph.snowflake;
    case ClimateMode.auto:
      return NexusGlyph.auto;
  }
}

String _statusLine(ClimateDevice device) {
  if (device.mode == ClimateMode.off) return 'System off';
  if (device.hold != null) return 'Holding ${device.hold}';
  switch (device.mode) {
    case ClimateMode.heat:
      return 'Heating to';
    case ClimateMode.cool:
      return 'Cooling to';
    case ClimateMode.auto:
      return 'Holding at';
    case ClimateMode.off:
      return 'System off';
  }
}

class ClimateRow extends StatefulWidget {
  const ClimateRow({super.key, required this.device});

  final ClimateDevice device;

  @override
  State<ClimateRow> createState() => _ClimateRowState();
}

class _ClimateRowState extends State<ClimateRow> {
  bool _expanded = false;
  bool _scheduleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    final device = widget.device;
    final color = climateModeColor(device.mode);
    final summary = device.mode == ClimateMode.off
        ? '${device.temp.round()}° now · system off'
        : '${device.temp.round()}° now · ${device.set.round()}° set · ${device.hold != null ? "holding" : "following schedule"}';

    return DeviceRowShell(
      onTap: () => setState(() => _expanded = !_expanded),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
        child: Center(child: NexusIcon(NexusGlyph.thermostat, size: 19, color: color)),
      ),
      title: device.name,
      subtitle: summary,
      trailing: const SizedBox.shrink(),
      expanded: _expanded,
      child: ExpandSection(
        expanded: _expanded,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Column(
            children: [
              _ModeSelector(device: device, onSelect: (m) => store.setClimateMode(device.id, m)),
              const SizedBox(height: 18),
              Opacity(
                opacity: device.mode == ClimateMode.off ? 0.4 : 1,
                child: IgnorePointer(
                  ignoring: device.mode == ClimateMode.off,
                  child: Column(
                    children: [
                      ArcDial(
                        min: 55,
                        max: 85,
                        value: device.set,
                        currentTemp: device.temp,
                        color: color,
                        enabled: device.mode != ClimateMode.off,
                        onChanged: (v) => store.setClimateTarget(device.id, v),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -14),
                        child: Column(
                          children: [
                            Text(_statusLine(device), style: NexusText.footnote),
                            const SizedBox(height: 2),
                            Text(
                              '${device.temp.round()}° now',
                              style: NexusText.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: device.mode == ClimateMode.off ? 0.4 : 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _NudgeButton(
                      glyph: NexusGlyph.minus,
                      onTap: device.mode == ClimateMode.off
                          ? null
                          : () => store.nudgeClimateTarget(device.id, -1),
                    ),
                    const SizedBox(width: 20),
                    _NudgeButton(
                      glyph: NexusGlyph.plus,
                      onTap: device.mode == ClimateMode.off
                          ? null
                          : () => store.nudgeClimateTarget(device.id, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('Fan', style: NexusText.footnote),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NexusSegmentedControl<FanMode>(
                      value: device.fan,
                      segments: const [
                        NexusSegment(FanMode.auto, 'Auto'),
                        NexusSegment(FanMode.on, 'On'),
                      ],
                      onChanged: (v) => store.setFanMode(device.id, v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ScheduleRow(
                device: device,
                expanded: _scheduleExpanded,
                onToggle: () => setState(() => _scheduleExpanded = !_scheduleExpanded),
                onSelect: (hold) {
                  store.setHold(device.id, hold);
                  setState(() => _scheduleExpanded = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.device, required this.onSelect});

  final ClimateDevice device;
  final ValueChanged<ClimateMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in ClimateMode.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: PressScale(
                onTap: () => onSelect(mode),
                child: AnimatedContainer(
                  duration: NexusDurations.fast,
                  height: 60,
                  decoration: BoxDecoration(
                    color: device.mode == mode
                        ? climateModeColor(mode).withValues(alpha: 0.14)
                        : NexusColors.secondarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: device.mode == mode ? climateModeColor(mode) : const Color(0x00000000),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      NexusIcon(
                        _climateModeGlyph(mode),
                        size: 16,
                        color: device.mode == mode ? climateModeColor(mode) : NexusColors.textMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _label(mode),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: device.mode == mode ? climateModeColor(mode) : NexusColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _label(ClimateMode mode) {
    switch (mode) {
      case ClimateMode.off:
        return 'Off';
      case ClimateMode.heat:
        return 'Heat';
      case ClimateMode.cool:
        return 'Cool';
      case ClimateMode.auto:
        return 'Auto';
    }
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.glyph, required this.onTap});

  final NexusGlyph glyph;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: NexusColors.secondarySurface, shape: BoxShape.circle),
        child: Center(child: NexusIcon(glyph, size: 16, color: NexusColors.textPrimary)),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.device,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final ClimateDevice device;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String?> onSelect;

  static const _options = <String?, String>{
    null: 'Follow schedule',
    'until 6:00 PM': 'Hold until 6:00 PM',
    'for 2 hours': 'Hold for 2 hours',
    'permanently': 'Hold permanently',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: NexusColors.secondarySurface, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    device.hold == null ? 'Follow schedule' : 'Hold ${device.hold}',
                    style: NexusText.bodyMedium,
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: NexusDurations.fast,
                  child: NexusIcon(NexusGlyph.chevronDown, size: 13, color: NexusColors.textFaint),
                ),
              ],
            ),
          ),
        ),
        ExpandSection(
          expanded: expanded,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                for (final entry in _options.entries)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(entry.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.value, style: NexusText.body)),
                          if (device.hold == entry.key)
                            NexusIcon(NexusGlyph.check, size: 15, color: NexusColors.blue),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
