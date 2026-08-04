import 'package:flutter/widgets.dart';

import '../../state/app_mode.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';

/// First-launch choice: what is this device actually for?
///
/// Before this existed the app always opened on the seeded example compound,
/// which meant a new install looked identical whether or not it was set up -
/// fake buildings, fake rooms, fake devices, and no signal that none of it
/// was real. Asking once, up front, makes the demo something you opt into
/// rather than the thing you have to work out how to escape.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onChoose});

  final ValueChanged<AppMode> onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NexusColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('NEXUS', style: NexusText.largeTitle),
                  const SizedBox(height: 8),
                  Text(
                    'Set up how this device runs.',
                    style: NexusText.subhead.copyWith(color: NexusColors.textMuted),
                  ),
                  const SizedBox(height: 28),
                  _Choice(
                    title: 'Connect to my server',
                    body:
                        'Pair with a nexus_server on your network or over Tailscale. '
                        'The server holds the compound, media library and cameras; '
                        'every device you pair stays in sync.',
                    action: 'Set up connection',
                    onTap: () => onChoose(AppMode.server),
                    primary: true,
                  ),
                  const SizedBox(height: 14),
                  _Choice(
                    title: 'Start a compound here',
                    body:
                        'Build it yourself on this device - add your buildings, '
                        'rooms and devices as you go. Saved locally, so it survives '
                        'restarts. You can pair a server later.',
                    action: 'Start empty',
                    onTap: () => onChoose(AppMode.local),
                  ),
                  const SizedBox(height: 14),
                  _Choice(
                    title: 'Look around the demo',
                    body:
                        'A fully populated example compound. Nothing here is real - '
                        'it exists to show what the app does.',
                    action: 'Open demo',
                    onTap: () => onChoose(AppMode.demo),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'You can change this any time in Settings.',
                    textAlign: TextAlign.center,
                    style: NexusText.footnote,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
    this.primary = false,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: NexusColors.surface,
          borderRadius: BorderRadius.circular(NexusRadii.card),
          // The recommended path gets a blue edge; the others keep the
          // standard hairline so the difference reads as emphasis, not as
          // two unrelated card styles.
          border: Border.all(
            color: primary ? NexusColors.blue : NexusColors.cardBorder,
            width: primary ? 1.5 : 0.5,
          ),
          boxShadow: NexusShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: NexusText.headline),
            const SizedBox(height: 6),
            Text(body, style: NexusText.subhead.copyWith(color: NexusColors.textMuted)),
            const SizedBox(height: 14),
            Text(
              action,
              style: NexusText.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: primary ? NexusColors.blue : NexusColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
