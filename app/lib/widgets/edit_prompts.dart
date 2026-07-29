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
