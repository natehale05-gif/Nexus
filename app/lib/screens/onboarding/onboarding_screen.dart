import 'package:flutter/widgets.dart';

import '../../state/app_mode.dart';
import '../../state/connection_scope.dart';
import '../../state/connection_settings.dart';
import '../../state/local_server_scope.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/nexus_button.dart';
import '../../widgets/press_scale.dart';
import 'connect_sheet.dart';

/// First launch. Two questions, because there are only two answers.
///
/// Either this machine *is* the compound server, or it talks to one that
/// already exists. Everything else - what a compound is, where media lives,
/// which device holds what - follows from that one choice, and asking it in
/// those words means nobody has to work out what "local mode" was going to do
/// to them.
///
/// The demo is still reachable, as a line of text at the bottom rather than a
/// third headline option: offering it as a peer to the two real answers made
/// the real answers look like two of three guesses.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onChoose});

  final ValueChanged<AppMode> onChoose;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _busy = false;
  String? _error;

  /// Makes this device the server, and pairs it to itself in one step.
  ///
  /// "Start a server" that then made you go and connect to it by hand would be
  /// a strange thing to offer.
  Future<void> _startServer() async {
    final local = LocalServerScope.of(context);
    final connection = ConnectionScope.of(context);
    if (!local.available) {
      // Nothing to run here (a phone, or a dev checkout with no bundled
      // binary), so hold the compound on this device instead - the choice
      // still does what its label promised.
      widget.onChoose(AppMode.local);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final handle = await local.start();
    if (!mounted) return;
    if (handle == null) {
      setState(() {
        _busy = false;
        _error = local.error ?? 'The server could not be started.';
      });
      return;
    }
    await connection.onConnect(StoredConnection(
      serverAddress: handle.address,
      token: handle.token,
      alternates: handle.addresses,
    ));
  }

  Future<void> _connect() async {
    setState(() => _error = null);
    await showConnectSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final local = LocalServerScope.of(context);
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
                    'Your compound, on your own hardware.',
                    style: NexusText.subhead.copyWith(color: NexusColors.textMuted),
                  ),
                  const SizedBox(height: 28),
                  _Choice(
                    title: 'Start a server',
                    body: local.supported
                        ? 'Make this computer the one that holds everything - the '
                            'compound, your files, your movies, the cameras and the '
                            'AI. Every other device connects to it.'
                        : 'This device can\'t host a server, so it will hold a '
                            'compound of its own until you set one up elsewhere.',
                    action: _busy ? 'Starting…' : 'Use this device',
                    onTap: _busy ? null : _startServer,
                    primary: true,
                  ),
                  const SizedBox(height: 14),
                  _Choice(
                    title: 'Connect to a server',
                    body: 'One is already running somewhere. Scan its QR code or '
                        'paste its pairing code and this device joins it.',
                    action: 'Scan or paste a code',
                    onTap: _busy ? null : _connect,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: NexusText.footnote.copyWith(color: NexusColors.red),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PressScale(
                    onTap: () => widget.onChoose(AppMode.demo),
                    child: Text(
                      'Just looking? Open the example compound',
                      textAlign: TextAlign.center,
                      style: NexusText.footnote.copyWith(color: NexusColors.blue),
                    ),
                  ),
                  const SizedBox(height: 10),
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
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NexusColors.surface,
        borderRadius: BorderRadius.circular(NexusRadii.card),
        // The recommended path gets a blue edge; the other keeps the standard
        // hairline, so the difference reads as emphasis rather than as two
        // unrelated card styles.
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
          const SizedBox(height: 16),
          NexusButton(
            label: action,
            style: primary ? NexusButtonStyle.primary : NexusButtonStyle.tinted,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}
