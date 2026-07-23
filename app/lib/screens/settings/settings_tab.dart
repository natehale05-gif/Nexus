import 'package:flutter/widgets.dart';

import '../../ai/ai_provider.dart';
import '../../ai/ai_settings.dart';
import '../../ai/provider_registry.dart';
import '../../state/ai_scope.dart';
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

  // AI provider settings (see ai/).
  final _aiModelController = TextEditingController();
  final _aiKeyController = TextEditingController();
  final _aiUrlController = TextEditingController();
  final _aiModelFocus = FocusNode();
  final _aiKeyFocus = FocusNode();
  final _aiUrlFocus = FocusNode();
  AiProviderKind _aiKind = AiProviderKind.local;
  bool _aiSaved = false;

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
      final ai = AiScope.of(context).config;
      _aiKind = ai.kind;
      _aiModelController.text = ai.model ?? '';
      _seedAiCredentialFields(ai);
    }
  }

  /// Populates the key/URL field for whichever provider is selected.
  void _seedAiCredentialFields(AiConfig ai) {
    switch (_aiKind) {
      case AiProviderKind.macStudio:
        _aiUrlController.text = ai.macStudioUrl ?? '';
      case AiProviderKind.anthropic:
        _aiKeyController.text = ai.anthropicKey ?? '';
      case AiProviderKind.openai:
        _aiKeyController.text = ai.openAiKey ?? '';
      case AiProviderKind.local:
        break;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _tokenController.dispose();
    _addressFocusNode.dispose();
    _tokenFocusNode.dispose();
    _aiModelController.dispose();
    _aiKeyController.dispose();
    _aiUrlController.dispose();
    _aiModelFocus.dispose();
    _aiKeyFocus.dispose();
    _aiUrlFocus.dispose();
    super.dispose();
  }

  /// When the user switches provider in the picker, re-seed the credential
  /// field from what's already stored for that provider.
  void _selectAiKind(AiProviderKind kind, AiConfig stored) {
    setState(() {
      _aiKind = kind;
      _aiSaved = false;
      _aiKeyController.text = switch (kind) {
        AiProviderKind.anthropic => stored.anthropicKey ?? '',
        AiProviderKind.openai => stored.openAiKey ?? '',
        _ => '',
      };
      _aiUrlController.text = kind == AiProviderKind.macStudio ? (stored.macStudioUrl ?? '') : '';
    });
  }

  Future<void> _saveAi(ProviderRegistry registry) async {
    final stored = registry.config;
    final model = _aiModelController.text.trim();
    final key = _aiKeyController.text.trim();
    final url = _aiUrlController.text.trim();
    await registry.update(AiConfig(
      kind: _aiKind,
      model: model.isEmpty ? null : model,
      // Preserve the other provider's key even when it isn't the one being
      // edited right now.
      anthropicKey: _aiKind == AiProviderKind.anthropic ? key : stored.anthropicKey,
      openAiKey: _aiKind == AiProviderKind.openai ? key : stored.openAiKey,
      macStudioUrl: _aiKind == AiProviderKind.macStudio ? url : stored.macStudioUrl,
    ));
    if (mounted) setState(() => _aiSaved = true);
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
    final registry = AiScope.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([store, registry]),
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
                    if (store.connectionStatus == ConnectionStatus.connected) ...[
                      const SizedBox(height: 20),
                      Text('Media Library', style: NexusText.footnote),
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
                              '${store.compound.mediaStats.movieCount} movies · '
                              '${store.compound.mediaStats.showCount} shows · '
                              '${store.compound.mediaStats.episodeCount} episodes',
                              style: NexusText.body,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scanned from the folder set by NEXUS_MEDIA_ROOT on the server.',
                              style: NexusText.footnote,
                            ),
                            const SizedBox(height: 16),
                            PressScale(
                              onTap: store.rescanLibrary,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                  color: NexusColors.secondarySurface,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    'Rescan Library',
                                    style: NexusText.headline.copyWith(color: NexusColors.blue),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ..._aiSection(registry),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _aiSection(ProviderRegistry registry) {
    final needsCredential = _aiKind != AiProviderKind.local;
    final isKeyProvider = _aiKind == AiProviderKind.anthropic || _aiKind == AiProviderKind.openai;
    return [
      Text('AI Model', style: NexusText.footnote),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: NexusColors.surface, borderRadius: BorderRadius.circular(NexusRadii.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Which backend answers in the NEXUS tab, on this device.', style: NexusText.subhead),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in AiProviderKind.values)
                  _AiProviderChip(
                    label: kind.label,
                    selected: kind == _aiKind,
                    onTap: () => _selectAiKind(kind, registry.config),
                  ),
              ],
            ),
            if (_aiKind == AiProviderKind.local) ...[
              const SizedBox(height: 12),
              Text(
                'Runs entirely on this device, no network - great offline. '
                '(Neural on-device models can slot in here later.)',
                style: NexusText.footnote,
              ),
            ],
            if (_aiKind == AiProviderKind.macStudio) ...[
              const SizedBox(height: 16),
              Text('Mac Studio URL', style: NexusText.footnote),
              const SizedBox(height: 6),
              _SettingsField(
                controller: _aiUrlController,
                focusNode: _aiUrlFocus,
                onChanged: (_) => setState(() => _aiSaved = false),
              ),
              const SizedBox(height: 4),
              Text('e.g. http://100.x.y.z:11434 (Tailscale) or http://192.168.1.50:11434', style: NexusText.footnote),
            ],
            if (isKeyProvider) ...[
              const SizedBox(height: 16),
              Text('${_aiKind.label} API key', style: NexusText.footnote),
              const SizedBox(height: 6),
              _SettingsField(
                controller: _aiKeyController,
                focusNode: _aiKeyFocus,
                obscureText: true,
                onChanged: (_) => setState(() => _aiSaved = false),
              ),
            ],
            if (needsCredential) ...[
              const SizedBox(height: 16),
              Text('Model (optional - a sensible default is used if blank)', style: NexusText.footnote),
              const SizedBox(height: 6),
              _SettingsField(
                controller: _aiModelController,
                focusNode: _aiModelFocus,
                onChanged: (_) => setState(() => _aiSaved = false),
              ),
            ],
            const SizedBox(height: 20),
            PressScale(
              onTap: () => _saveAi(registry),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(color: NexusColors.blue, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Text(
                    _aiSaved ? 'Saved' : 'Save AI Settings',
                    style: NexusText.headline.copyWith(color: const Color(0xFFFFFFFF)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// A pill for picking the active AI provider.
class _AiProviderChip extends StatelessWidget {
  const _AiProviderChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? NexusColors.blue.withValues(alpha: 0.12) : NexusColors.secondarySurface,
          borderRadius: BorderRadius.circular(NexusRadii.pill),
          border: Border.all(color: selected ? NexusColors.blue : const Color(0x00000000), width: 1.4),
        ),
        child: Text(
          label,
          style: NexusText.bodyMedium.copyWith(color: selected ? NexusColors.blue : NexusColors.textPrimary),
        ),
      ),
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
