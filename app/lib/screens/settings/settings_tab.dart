import 'package:flutter/widgets.dart';

import '../../state/compound_scope.dart';
import '../../state/connection_scope.dart';
import '../../state/connection_settings.dart';
import '../../state/nexus_data_source.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/status_pill.dart';
import '../security/tab_header.dart';

/// Settings tab: where a device pairs with a `nexus_server` instance (or
/// drops back to local-demo-mode). Replaces the old web-only `?server=`
/// query-param hack with a persisted, cross-platform connect flow - see
/// the root README's "Remote access" section for the Tailscale side of
/// reaching a server from outside the LAN.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _addressController = TextEditingController();
  final _tokenController = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _tokenFocusNode = FocusNode();
  bool _seeded = false;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One-time seed from whatever's already persisted, so re-opening this
    // tab shows the connection currently in use rather than blank fields.
    if (!_seeded) {
      _seeded = true;
      final current = ConnectionScope.of(context).current;
      if (current != null) {
        _addressController.text = current.serverAddress;
        _tokenController.text = current.token;
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _tokenController.dispose();
    _addressFocusNode.dispose();
    _tokenFocusNode.dispose();
    super.dispose();
  }

  bool get _canConnect =>
      !_busy && _addressController.text.trim().isNotEmpty && _tokenController.text.trim().isNotEmpty;

  Future<void> _connect() async {
    final scope = ConnectionScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scope.onConnect(StoredConnection(
        serverAddress: _addressController.text.trim(),
        token: _tokenController.text.trim(),
      ));
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save that connection: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forget() async {
    setState(() => _busy = true);
    try {
      await ConnectionScope.of(context).onForget();
      _addressController.clear();
      _tokenController.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionScope = ConnectionScope.of(context);
    final store = CompoundScope.of(context);

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final (statusLabel, statusColor) = switch (store.connectionStatus) {
          ConnectionStatus.demo => ('Local Demo Mode', NexusColors.textMuted),
          ConnectionStatus.connecting => ('Connecting…', NexusColors.amber),
          ConnectionStatus.connected => ('Connected', NexusColors.green),
          ConnectionStatus.reconnecting => ('Reconnecting…', NexusColors.amber),
        };

        return Container(
          color: NexusColors.background,
          child: Column(
            children: [
              const TabHeader(title: 'Settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    Row(
                      children: [
                        Text('Server', style: NexusText.footnote),
                        const Spacer(),
                        StatusPill(label: statusLabel, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NexusColors.surface,
                        borderRadius: BorderRadius.circular(NexusRadii.card),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter the address of a nexus_server instance - a Tailscale name '
                            '(myhouse.tailnet-name.ts.net) for remote access, or a LAN address '
                            '(192.168.1.50:8765) at home - and the pairing token shown in its '
                            'startup log.',
                            style: NexusText.subhead,
                          ),
                          const SizedBox(height: 16),
                          Text('Server address', style: NexusText.footnote),
                          const SizedBox(height: 6),
                          _SettingsField(
                            controller: _addressController,
                            focusNode: _addressFocusNode,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          Text('Pairing token', style: NexusText.footnote),
                          const SizedBox(height: 6),
                          _SettingsField(
                            controller: _tokenController,
                            focusNode: _tokenFocusNode,
                            obscureText: true,
                            onChanged: (_) => setState(() {}),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!, style: NexusText.footnote.copyWith(color: NexusColors.red)),
                          ],
                          const SizedBox(height: 20),
                          PressScale(
                            onTap: _canConnect ? _connect : null,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: _canConnect ? NexusColors.blue : NexusColors.secondarySurface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  _busy ? 'Connecting…' : 'Connect',
                                  style: NexusText.headline.copyWith(
                                    color: _canConnect ? const Color(0xFFFFFFFF) : NexusColors.textFaint,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (connectionScope.current != null) ...[
                            const SizedBox(height: 10),
                            PressScale(
                              onTap: _busy ? null : _forget,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                  color: NexusColors.secondarySurface,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    'Forget This Server',
                                    style: NexusText.headline.copyWith(color: NexusColors.red),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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

class _SettingsField extends StatelessWidget {
  const _SettingsField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: NexusColors.secondarySurface, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: EditableText(
        controller: controller,
        focusNode: focusNode,
        style: NexusText.body,
        cursorColor: NexusColors.blue,
        backgroundCursorColor: NexusColors.textFaint,
        obscureText: obscureText,
        onChanged: onChanged,
      ),
    );
  }
}
