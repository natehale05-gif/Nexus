import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'press_scale.dart';

/// Small modal prompts for building the compound out - naming a building or
/// room, picking a device type, confirming a delete.
///
/// These use the app's own surface/typography tokens rather than Material's
/// AlertDialog so they don't break the look everywhere else maintains.

/// Asks for a single line of text. Returns null if dismissed, and never
/// returns an empty string - the caller can treat a non-null result as usable.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  String? subtitle,
  String initialValue = '',
  String confirmLabel = 'Add',
}) {
  final controller = TextEditingController(text: initialValue);
  final focus = FocusNode();
  return showDialog<String>(
    context: context,
    builder: (context) => _Sheet(
      title: title,
      subtitle: subtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: NexusColors.secondarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: EditableText(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              style: NexusText.body,
              cursorColor: NexusColors.blue,
              backgroundCursorColor: NexusColors.textFaint,
              onSubmitted: (value) => _popName(context, value),
            ),
          ),
          const SizedBox(height: 18),
          _Actions(
            confirmLabel: confirmLabel,
            onConfirm: () => _popName(context, controller.text),
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    controller.dispose();
    focus.dispose();
  });
}

void _popName(BuildContext context, String value) {
  final trimmed = value.trim();
  Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
}

/// Device type picker. Lock is described in gate/lock terms because it's the
/// one type that attaches to the building rather than a room.
Future<DeviceType?> promptForDeviceType(BuildContext context) {
  const labels = {
    DeviceType.light: ('Light', 'Dimmable or on/off'),
    DeviceType.climate: ('Climate', 'Thermostat or heater'),
    DeviceType.lock: ('Lock or gate', 'Attaches to the building'),
    DeviceType.media: ('Media', 'Speaker, TV or receiver'),
    DeviceType.grill: ('Grill', 'Temperature and probes'),
  };
  return showDialog<DeviceType>(
    context: context,
    builder: (context) => _Sheet(
      title: 'Add a device',
      subtitle: 'What kind?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in labels.entries) ...[
            PressScale(
              onTap: () => Navigator.of(context).pop(entry.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: NexusColors.secondarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.value.$1, style: NexusText.bodyMedium),
                          const SizedBox(height: 2),
                          Text(entry.value.$2, style: NexusText.footnote),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          _Actions(onConfirm: null, onCancelOnly: true),
        ],
      ),
    ),
  );
}

/// Destructive confirm. [detail] should spell out what else disappears -
/// removing a building also removes its rooms and devices, and that is not
/// something to discover afterwards.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String detail,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _Sheet(
      title: title,
      subtitle: detail,
      child: _Actions(
        confirmLabel: 'Delete',
        destructive: true,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    ),
  );
  return result ?? false;
}

/// Asks how to reach a real device: which local-HTTP protocol it speaks and
/// its address. Returning null means "track it in NEXUS but don't try to
/// control anything" - which is a legitimate choice, not a cancel.
Future<DeviceEndpoint?> promptForEndpoint(BuildContext context, {String? initialHost}) async {
  final protocol = await showDialog<DeviceProtocol?>(
    context: context,
    builder: (context) => _Sheet(
      title: 'How does it connect?',
      subtitle: 'NEXUS talks to these over plain HTTP on your network - no '
          'cloud account, no vendor login.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in const {
            DeviceProtocol.shellyGen1: ('Shelly (gen 1)', 'Shelly 1/2.5/Dimmer'),
            DeviceProtocol.shellyGen2: ('Shelly (Plus / Pro)', 'Gen 2+ RPC firmware'),
            DeviceProtocol.tasmota: ('Tasmota', 'Any Tasmota-flashed device'),
            DeviceProtocol.wled: ('WLED', 'Addressable LED controllers'),
          }.entries)
            PressScale(
              onTap: () => Navigator.of(context).pop(entry.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: NexusColors.secondarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.value.$1, style: NexusText.bodyMedium),
                    const SizedBox(height: 2),
                    Text(entry.value.$2, style: NexusText.footnote),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          PressScale(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: NexusColors.secondarySurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text('Skip - just track it', style: NexusText.bodyMedium),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  if (protocol == null || !context.mounted) return null;

  final host = await promptForName(
    context,
    title: 'Device address',
    subtitle: 'IP or hostname on your network, e.g. 192.168.1.50',
    initialValue: initialHost ?? '',
    confirmLabel: 'Save',
  );
  if (host == null) return null;
  return DeviceEndpoint(protocol: protocol, host: host);
}

/// What to do with an existing device.
enum DeviceAction { wiring, unwire, rename, remove }

Future<DeviceAction?> promptForDeviceAction(
  BuildContext context, {
  required String deviceName,
  String? wiredTo,
}) {
  return showDialog<DeviceAction>(
    context: context,
    builder: (context) => _Sheet(
      title: deviceName,
      subtitle: wiredTo == null
          ? 'Tracked in NEXUS but not wired to any hardware.'
          : 'Controlling $wiredTo',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in [
            (DeviceAction.wiring, wiredTo == null ? 'Connect to hardware' : 'Change address'),
            if (wiredTo != null) (DeviceAction.unwire, 'Disconnect from hardware'),
            (DeviceAction.rename, 'Rename'),
            (DeviceAction.remove, 'Delete device'),
          ])
            PressScale(
              onTap: () => Navigator.of(context).pop(entry.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: NexusColors.secondarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.$2,
                  style: NexusText.bodyMedium.copyWith(
                    color: entry.$1 == DeviceAction.remove
                        ? NexusColors.red
                        : NexusColors.textPrimary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          _Actions(onConfirm: null, onCancelOnly: true),
        ],
      ),
    ),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NexusColors.surface,
              borderRadius: BorderRadius.circular(NexusRadii.card),
              boxShadow: NexusShadows.raised,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: NexusText.headline),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: NexusText.subhead.copyWith(color: NexusColors.textMuted)),
                ],
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    this.confirmLabel = 'Add',
    required this.onConfirm,
    this.destructive = false,
    this.onCancelOnly = false,
  });

  final String confirmLabel;
  final VoidCallback? onConfirm;
  final bool destructive;
  final bool onCancelOnly;

  @override
  Widget build(BuildContext context) {
    final cancel = PressScale(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: NexusColors.secondarySurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Text('Cancel', style: NexusText.bodyMedium)),
      ),
    );
    if (onCancelOnly || onConfirm == null) return cancel;
    return Row(
      children: [
        Expanded(child: cancel),
        const SizedBox(width: 10),
        Expanded(
          child: PressScale(
            onTap: onConfirm,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: destructive ? NexusColors.red : NexusColors.blue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  confirmLabel,
                  style: NexusText.bodyMedium.copyWith(color: const Color(0xFFFFFFFF)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
