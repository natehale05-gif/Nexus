import 'package:flutter/widgets.dart';

import 'package:nexus_shared/nexus_shared.dart';

import '../../ai/ai_provider.dart';
import '../../ai/ai_settings.dart';
import '../../ai/hugging_face.dart';
import '../../ai/provider_registry.dart';
import '../../ai/providers/mac_studio_provider.dart';
import '../../state/ai_scope.dart';
import '../../state/app_mode.dart';
import '../../state/compound_scope.dart';
import '../../state/connection_scope.dart';
import '../../state/connection_settings.dart';
import '../../state/local_server_scope.dart';
import '../../state/map_settings.dart';
import '../../state/nexus_data_source.dart';
import '../../state/update_scope.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/status_pill.dart';
import '../security/tab_header.dart';
import '../../widgets/nexus_card.dart';

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

/// Settings is a short index of pages rather than one long scroll. It had
/// grown to six stacked sections - server, run-a-server, version, mode, map,
/// AI - and finding anything meant scrolling past everything else.
enum _SettingsPage { server, compound, media, ai, map, about }

class _SettingsTabState extends State<SettingsTab> {
  _SettingsPage? _page;
  final _addressController = TextEditingController();
  final _tokenController = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _tokenFocusNode = FocusNode();

  // AI provider settings (see ai/).
  final _aiModelController = TextEditingController();
  final _aiKeyController = TextEditingController();
  final _aiUrlController = TextEditingController();
  final _mediaRootController = TextEditingController();
  final _mediaRootFocus = FocusNode();
  final _ionTokenController = TextEditingController();
  final _ionTokenFocus = FocusNode();
  bool _ionSaved = true;
  List<String>? _ollamaModels;
  bool _probingOllama = false;
  // Hugging Face model browser.
  final _hfQueryController = TextEditingController();
  final _hfQueryFocus = FocusNode();
  List<HfModel>? _hfResults;
  bool _hfSearching = false;
  String? _hfError;
  String? _pullingModel;
  String _pullStatus = '';
  double? _pullFraction;
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
      _ionTokenController.text = loadIonToken() ?? '';
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
    _mediaRootController.dispose();
    _mediaRootFocus.dispose();
    _ionTokenController.dispose();
    _ionTokenFocus.dispose();
    _hfQueryController.dispose();
    _hfQueryFocus.dispose();
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

  /// Asks the configured Ollama what it actually has installed. Typing a
  /// model name blind is the main way this goes wrong - a wrong name comes
  /// back as an opaque 404 at chat time.
  Future<void> _probeOllama() async {
    final url = _aiUrlController.text.trim().isEmpty
        ? 'http://127.0.0.1:11434'
        : _aiUrlController.text.trim();
    setState(() => _probingOllama = true);
    final models = await MacStudioProvider.listModels(url);
    if (!mounted) return;
    setState(() {
      _ollamaModels = models;
      _probingOllama = false;
      // Fill in the URL we actually probed, so the default isn't invisible.
      if (_aiUrlController.text.trim().isEmpty) _aiUrlController.text = url;
    });
  }


  String get _ollamaUrl => _aiUrlController.text.trim().isEmpty
      ? 'http://127.0.0.1:11434'
      : _aiUrlController.text.trim();

  /// Searches Hugging Face for GGUF models this Ollama can run.
  Future<void> _searchHuggingFace() async {
    setState(() {
      _hfSearching = true;
      _hfError = null;
    });
    final catalog = HuggingFaceCatalog();
    try {
      final results = await catalog.search(_hfQueryController.text);
      if (mounted) setState(() => _hfResults = results);
    } catch (error) {
      if (mounted) setState(() => _hfError = '$error');
    } finally {
      catalog.dispose();
      if (mounted) setState(() => _hfSearching = false);
    }
  }

  /// Hands the Hugging Face repo to Ollama to download. Ollama takes
  /// `hf.co/owner/repo` directly, so the model lands where the existing chat
  /// path can already use it - no separate model store to manage.
  Future<void> _pullModel(HfModel model) async {
    setState(() {
      _pullingModel = model.id;
      _pullStatus = 'starting';
      _pullFraction = null;
      _hfError = null;
    });
    try {
      await for (final progress in MacStudioProvider.pullModel(_ollamaUrl, model.ollamaRef)) {
        if (!mounted) return;
        setState(() {
          _pullStatus = progress.status;
          _pullFraction = progress.fraction;
        });
      }
      if (!mounted) return;
      // Select what was just downloaded and refresh the installed list, so
      // finishing a download leaves it usable rather than needing two more taps.
      setState(() {
        _aiModelController.text = model.ollamaRef;
        _aiKind = AiProviderKind.macStudio;
        _aiSaved = false;
      });
      await _probeOllama();
    } catch (error) {
      if (mounted) {
        setState(() => _hfError = error is AiException ? error.displayMessage : '$error');
      }
    } finally {
      if (mounted) setState(() => _pullingModel = null);
    }
  }

  /// Browse-and-download for local models. Only meaningful for the Ollama
  /// provider - it's Ollama that does the downloading and the running.
  List<Widget> _huggingFaceSection() {
    final results = _hfResults;
    return [
      const SizedBox(height: 18),
      Container(height: 1, color: NexusColors.separator),
      const SizedBox(height: 18),
      Text('Download a model from Hugging Face', style: NexusText.bodyMedium),
      const SizedBox(height: 4),
      Text(
        'Searches Hugging Face for GGUF models - the format Ollama runs - and '
        'downloads them into the Ollama above. Nothing leaves your network once '
        'a model is on disk.',
        style: NexusText.footnote,
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _SettingsField(
              controller: _hfQueryController,
              focusNode: _hfQueryFocus,
              onChanged: (_) {},
            ),
          ),
          const SizedBox(width: 8),
          PressScale(
            onTap: _hfSearching ? () {} : _searchHuggingFace,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: NexusColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _hfSearching ? '…' : 'Search',
                style: NexusText.bodyMedium.copyWith(color: NexusColors.blue),
              ),
            ),
          ),
        ],
      ),
      if (_hfError != null) ...[
        const SizedBox(height: 10),
        Text(_hfError!, style: NexusText.footnote.copyWith(color: NexusColors.red)),
      ],
      if (_pullingModel != null) ...[
        const SizedBox(height: 12),
        Text('Downloading $_pullingModel', style: NexusText.footnote),
        const SizedBox(height: 6),
        // A determinate bar only while Ollama reports bytes; the manifest and
        // verify phases have no total, and a frozen 0% would look hung.
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: NexusColors.secondarySurface,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _pullFraction ?? 0.06,
            child: Container(
              decoration: BoxDecoration(
                color: NexusColors.blue,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _pullFraction == null
              ? _pullStatus
              : '$_pullStatus  ${(_pullFraction! * 100).round()}%',
          style: NexusText.footnote,
        ),
      ],
      if (results != null) ...[
        const SizedBox(height: 12),
        if (results.isEmpty)
          Text('No GGUF models matched.', style: NexusText.footnote)
        else
          for (final model in results.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PressScale(
                onTap: _pullingModel != null ? () {} : () => _pullModel(model),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: NexusColors.secondarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.name, style: NexusText.bodyMedium),
                      const SizedBox(height: 2),
                      Text(
                        [
                          model.owner,
                          if (model.parameterHint != null) model.parameterHint!,
                          // Stating the RAM up front beats finding out by
                          // watching a 40 GB download fail to load.
                          if (estimatedRamGb(model.parameterHint) != null)
                            '~${estimatedRamGb(model.parameterHint)!.toStringAsFixed(0)} GB RAM',
                          '${model.downloads} downloads',
                        ].join(' · '),
                        style: NexusText.footnote,
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    ];
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
    final updates = UpdateScope.of(context);
    final local = LocalServerScope.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([store, registry, updates, local]),
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
              TabHeader(
                title: switch (_page) {
                  null => 'Settings',
                  _SettingsPage.server => 'Server',
                  _SettingsPage.compound => 'Compound',
                  _SettingsPage.media => 'Media & files',
                  _SettingsPage.ai => 'AI',
                  _SettingsPage.map => 'Map',
                  _SettingsPage.about => 'About',
                },
                pillLabel: _page == null ? statusLabel : null,
                pillColor: _page == null ? statusColor : null,
              ),
              if (_page != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: PressScale(
                      onTap: () => setState(() => _page = null),
                      child: Text(
                        '‹  All settings',
                        style: NexusText.bodyMedium.copyWith(color: NexusColors.blue),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    if (_page == null)
                      ..._indexRows(connectionScope, store)
                    else
                      ...switch (_page!) {
                        _SettingsPage.server => [
                            ..._localServerSection(LocalServerScope.of(context), connectionScope),
                            ..._serverSection(statusLabel, statusColor, connectionScope, store),
                          ],
                        _SettingsPage.compound => _compoundSection(store),
                        _SettingsPage.media => _mediaSection(store),
                        _SettingsPage.ai => _aiSection(registry),
                        _SettingsPage.map => _mapSection(),
                        _SettingsPage.about => [
                            ..._updateSection(UpdateScope.of(context)),
                            ..._modeSection(connectionScope),
                          ],
                      },
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The 3D compound map is served by Cesium ion, which authorizes tile
  /// requests per-account - so the token can't be shipped in the repo and has
  /// to be pasted in per install. Hidden on platforms with no CesiumJS map.
  /// Lets someone move between the demo, their own local compound, and a
  /// paired server after first run - the onboarding screen promises this is
  /// changeable, so it has to actually be reachable.
  /// Version + update state. Desktop can install the update itself; web
  /// updates by reloading, and mobile goes through the app stores, so the
  /// button only appears where it does something.

  /// The index: one row per area, each saying what it's currently set to so
  /// the state of the system is readable without opening anything.
  List<Widget> _indexRows(ConnectionScope scope, NexusDataSource store) {
    final compound = store.compound;
    final connected = store.connectionStatus == ConnectionStatus.connected;
    final rows = <(_SettingsPage, String, String)>[
      (
        _SettingsPage.server,
        'Server',
        connected
            ? 'Connected to ${scope.current?.serverAddress ?? 'a server'}'
            : 'Not connected - run one here, or pair with one',
      ),
      (
        _SettingsPage.compound,
        'Compound',
        '${compound.buildings.length} buildings · ${compound.rooms.length} rooms · '
            '${compound.devices.length} devices · ${compound.vehicles.length} vehicles',
      ),
      (
        _SettingsPage.media,
        'Media & files',
        '${compound.mediaStats.movieCount} movies · ${compound.mediaStats.episodeCount} episodes · '
            '${compound.photos.length} photos · ${compound.music.length} tracks',
      ),
      (
        _SettingsPage.ai,
        'AI',
        _aiKind == AiProviderKind.macStudio && _aiModelController.text.isNotEmpty
            ? _aiModelController.text
            : _aiKind.label,
      ),
      (
        _SettingsPage.map,
        'Map',
        loadIonToken() == null ? '2D satellite' : 'Photoreal 3D (ion token set)',
      ),
      (_SettingsPage.about, 'About', 'Version, updates and mode'),
    ];

    return [
      for (final (page, title, subtitle) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PressScale(
            onTap: () => setState(() => _page = page),
            child: NexusCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: NexusText.bodyMedium),
                        const SizedBox(height: 3),
                        Text(subtitle, style: NexusText.footnote),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '›',
                    style: NexusText.title.copyWith(
                      color: NexusColors.textFaint,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  /// Compound structure lives in the Buildings tab, where you can see what
  /// you're editing. This page points there rather than duplicating the
  /// editor somewhere it has no context.
  List<Widget> _compoundSection(NexusDataSource store) {
    final compound = store.compound;
    return [
      _infoCard(
        'Buildings, rooms and devices',
        'Open the Buildings tab to add or edit them - the editor lives beside '
            'what it edits, so you can see the result immediately.\n\n'
            'Buildings hold rooms; rooms hold lights, climate, media and grills. '
            'Locks and gates attach to a building rather than a room.',
        stats: [
          ('Buildings', '${compound.buildings.length}'),
          ('Rooms', '${compound.rooms.length}'),
          ('Devices', '${compound.devices.length}'),
          ('Vehicles', '${compound.vehicles.length}'),
          ('Gates & locks', '${compound.devices.whereType<LockDevice>().length}'),
        ],
      ),
    ];
  }

  /// Where the server looks for media. Only meaningful for a server this
  /// device is running - a remote server's folders are on its own disk.
  List<Widget> _mediaSection(NexusDataSource store) {
    final compound = store.compound;
    return [
      _infoCard(
        'Library',
        'The server scans one folder for everything: movies, TV, photos and '
            'music. Set it under Server → Run a server here, then rescan.',
        stats: [
          ('Movies', '${compound.mediaStats.movieCount}'),
          ('Shows', '${compound.mediaStats.showCount}'),
          ('Episodes', '${compound.mediaStats.episodeCount}'),
          ('Photos', '${compound.photos.length}'),
          ('Tracks', '${compound.music.length}'),
          ('Cameras', '${compound.cameras.length}'),
        ],
      ),
      const SizedBox(height: 12),
      PressScale(
        onTap: store.rescanLibrary,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: NexusColors.blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text('Rescan library', style: NexusText.bodyMedium.copyWith(color: NexusColors.blue)),
          ),
        ),
      ),
    ];
  }

  Widget _infoCard(String title, String body, {List<(String, String)> stats = const []}) {
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: NexusText.bodyMedium),
          const SizedBox(height: 6),
          Text(body, style: NexusText.subhead.copyWith(color: NexusColors.textMuted)),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                for (final (label, value) in stats)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: NexusText.headline),
                      Text(label, style: NexusText.footnote),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Pairing with a server that already exists (or forgetting one).
  List<Widget> _serverSection(
    String statusLabel,
    Color statusColor,
    ConnectionScope connectionScope,
    NexusDataSource store,
  ) {
    return [
      Row(
        children: [
          Text('Server'.toUpperCase(), style: NexusText.sectionHeader),
          const Spacer(),
          StatusPill(label: statusLabel, color: statusColor),
        ],
      ),
      const SizedBox(height: 10),
      NexusCard(
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
        NexusCard(
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
    ];
  }

  /// Run the bundled nexus_server on this machine and pair to it in one
  /// step, so "set up a server" doesn't mean opening a terminal.
  List<Widget> _localServerSection(LocalServerController local, ConnectionScope scope) {
    if (!local.supported) return const [];
    return [
      Text('Run a server here'.toUpperCase(), style: NexusText.sectionHeader),
      const SizedBox(height: 10),
      NexusCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Make this computer the compound server. Your phone and other '
                    'devices then pair to it over the LAN or Tailscale.',
                    style: NexusText.subhead,
                  ),
                ),
                if (local.running) ...[
                  const SizedBox(width: 10),
                  StatusPill(label: 'Running', color: NexusColors.green),
                ],
              ],
            ),
            if (!local.available) ...[
              const SizedBox(height: 12),
              Text(
                'No server binary is bundled with this build. Release downloads '
                'include one; a local `flutter run` does not.',
                style: NexusText.footnote,
              ),
            ] else ...[
              const SizedBox(height: 14),
              Text('Media folder (optional)', style: NexusText.footnote),
              const SizedBox(height: 6),
              _SettingsField(
                controller: _mediaRootController,
                focusNode: _mediaRootFocus,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              Text(
                'Where your movies, shows, photos and music live. Leave blank to '
                'use the default folder inside the server data directory.',
                style: NexusText.footnote,
              ),
              if (local.error != null) ...[
                const SizedBox(height: 10),
                Text(local.error!, style: NexusText.footnote.copyWith(color: NexusColors.red)),
              ],
              const SizedBox(height: 16),
              PressScale(
                onTap: local.busy
                    ? () {}
                    : (local.running
                        ? local.stop
                        : () => _startLocalServer(local, scope)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: local.running ? NexusColors.secondarySurface : NexusColors.blue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      local.busy
                          ? 'Working…'
                          : local.running
                              ? 'Stop server'
                              : 'Start server and pair this device',
                      style: NexusText.headline.copyWith(
                        color: local.running ? NexusColors.textPrimary : const Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ),
              ),
              if (local.running && local.handle != null) ...[
                const SizedBox(height: 12),
                Text('Pairing token for your other devices', style: NexusText.footnote),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: NexusColors.secondarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(local.handle!.token, style: NexusText.body),
                ),
                const SizedBox(height: 6),
                Text(
                  'On another device, enter this computer\'s address and that token '
                  'in Settings -> Server.',
                  style: NexusText.footnote,
                ),
              ],
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  /// Starts the server, then immediately pairs this device to it - starting a
  /// server you then have to hand-connect to would be a pointless extra step.
  Future<void> _startLocalServer(LocalServerController local, ConnectionScope scope) async {
    final handle = await local.start(mediaRoot: _mediaRootController.text);
    if (handle == null || !mounted) return;
    _addressController.text = handle.address;
    _tokenController.text = handle.token;
    await scope.onConnect(StoredConnection(
      serverAddress: handle.address,
      token: handle.token,
    ));
  }

  List<Widget> _updateSection(UpdateController updates) {
    final update = updates.available;
    return [
      Text('Version'.toUpperCase(), style: NexusText.sectionHeader),
      const SizedBox(height: 10),
      NexusCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('NEXUS ${updates.currentVersion}', style: NexusText.bodyMedium),
                const Spacer(),
                if (updates.checking)
                  Text('Checking…', style: NexusText.footnote)
                else if (update != null)
                  StatusPill(label: '${update.version} available', color: NexusColors.blue)
                else
                  Text('Up to date', style: NexusText.footnote),
              ],
            ),
            if (updates.error != null) ...[
              const SizedBox(height: 10),
              Text(updates.error!, style: NexusText.footnote.copyWith(color: NexusColors.red)),
            ],
            const SizedBox(height: 14),
            if (update != null && update.assetUrl != null && updates.canSelfInstall)
              PressScale(
                onTap: updates.installing ? () {} : updates.install,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(color: NexusColors.blue, borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: Text(
                      updates.installing ? 'Downloading…' : 'Download and install ${update.version}',
                      style: NexusText.headline.copyWith(color: const Color(0xFFFFFFFF)),
                    ),
                  ),
                ),
              )
            else
              PressScale(
                onTap: updates.checking ? () {} : updates.check,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: NexusColors.secondarySurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text('Check for updates', style: NexusText.bodyMedium)),
                ),
              ),
            if (update != null && update.assetUrl == null) ...[
              const SizedBox(height: 8),
              Text(
                'Version ${update.version} is out, but this release has no installer for '
                'this platform - grab it from the releases page.',
                style: NexusText.footnote,
              ),
            ],
            if (updates.currentVersion.endsWith('-dev')) ...[
              const SizedBox(height: 8),
              Text(
                'This is a local build, so update checks are skipped.',
                style: NexusText.footnote,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _modeSection(ConnectionScope scope) {
    const copy = {
      AppMode.server: 'Paired with a server. It owns the compound, media and cameras.',
      AppMode.local: 'This device holds your compound. Edit it from the Buildings tab.',
      AppMode.demo: 'The example compound. Nothing here is real.',
    };
    return [
      Text('Mode'.toUpperCase(), style: NexusText.sectionHeader),
      const SizedBox(height: 10),
      NexusCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scope.mode == null ? 'Not set up yet.' : copy[scope.mode]!,
              style: NexusText.subhead,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in AppMode.values)
                  _AiProviderChip(
                    label: switch (mode) {
                      AppMode.server => 'My server',
                      AppMode.local => 'This device',
                      AppMode.demo => 'Demo',
                    },
                    selected: scope.mode == mode,
                    onTap: () => scope.onChooseMode(mode),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Switching to "This device" keeps whatever compound you have already '
              'built here; the demo is regenerated fresh each time and never '
              'overwrites it.',
              style: NexusText.footnote,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _mapSection() {
    if (!mapTokenConfigurable) return const [];
    return [
      Text('Map'.toUpperCase(), style: NexusText.sectionHeader),
      const SizedBox(height: 10),
      NexusCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The Home map shows 2D satellite imagery by default - no setup, no '
              'account. Adding a Cesium ion token upgrades it to a photoreal 3D '
              'globe; tokens are tied to an ion account, so this one is yours.',
              style: NexusText.subhead,
            ),
            const SizedBox(height: 14),
            Text('Cesium ion access token', style: NexusText.footnote),
            const SizedBox(height: 6),
            _SettingsField(
              controller: _ionTokenController,
              focusNode: _ionTokenFocus,
              obscureText: true,
              onChanged: (_) => setState(() => _ionSaved = false),
            ),
            const SizedBox(height: 4),
            Text(
              'Optional. Create one at ion.cesium.com/tokens with the default scopes (it must '
              'include assets:read), and make sure Google Photorealistic 3D Tiles is added to '
              'that account’s assets. Leave this blank and the map stays 2D satellite, which '
              'works fine.',
              style: NexusText.footnote,
            ),
            const SizedBox(height: 20),
            PressScale(
              onTap: _saveIonToken,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(color: NexusColors.blue, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Text(
                    _ionSaved ? 'Saved — reload to apply' : 'Save token',
                    style: NexusText.headline.copyWith(color: const Color(0xFFFFFFFF)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  void _saveIonToken() {
    saveIonToken(_ionTokenController.text);
    setState(() => _ionSaved = true);
  }

  List<Widget> _aiSection(ProviderRegistry registry) {
    final needsCredential = _aiKind != AiProviderKind.local;
    final isKeyProvider = _aiKind == AiProviderKind.anthropic || _aiKind == AiProviderKind.openai;
    return [
      Text('AI Model'.toUpperCase(), style: NexusText.sectionHeader),
      const SizedBox(height: 10),
      NexusCard(
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
              Text('Ollama URL', style: NexusText.footnote),
              const SizedBox(height: 6),
              _SettingsField(
                controller: _aiUrlController,
                focusNode: _aiUrlFocus,
                onChanged: (_) => setState(() {
                  _aiSaved = false;
                  // The detected list belongs to the old URL.
                  _ollamaModels = null;
                }),
              ),
              const SizedBox(height: 4),
              Text(
                'http://127.0.0.1:11434 runs the model on this machine - fully '
                'local, no API key. A Tailscale or LAN address uses another box.',
                style: NexusText.footnote,
              ),
              const SizedBox(height: 12),
              PressScale(
                onTap: _probingOllama ? () {} : _probeOllama,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: NexusColors.secondarySurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _probingOllama ? 'Checking…' : 'Detect installed models',
                      style: NexusText.bodyMedium,
                    ),
                  ),
                ),
              ),
              ..._huggingFaceSection(),
              if (_ollamaModels != null) ...[
                const SizedBox(height: 10),
                if (_ollamaModels!.isEmpty)
                  Text(
                    'No Ollama answered there. Install it from ollama.com, run '
                    '`ollama pull llama3.1`, and check again.',
                    style: NexusText.footnote.copyWith(color: NexusColors.red),
                  )
                else ...[
                  Text('Installed - tap to use', style: NexusText.footnote),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final model in _ollamaModels!)
                        _AiProviderChip(
                          label: model,
                          selected: _aiModelController.text == model,
                          onTap: () => setState(() {
                            _aiModelController.text = model;
                            _aiSaved = false;
                          }),
                        ),
                    ],
                  ),
                ],
              ],
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
