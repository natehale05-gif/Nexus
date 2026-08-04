import 'package:flutter/services.dart' show Clipboard, ClipboardData;
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
import '../../ai/model_catalog.dart';
import '../../state/local_ai_scope.dart';
import '../../state/local_server_scope.dart';
import '../../state/map_settings.dart';
import '../../state/nexus_data_source.dart';
import '../../state/update_scope.dart';
import '../../state/web_app_url.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/status_pill.dart';
import '../security/tab_header.dart';
import '../../widgets/nexus_button.dart';
import '../../widgets/nexus_card.dart';
import '../../widgets/qr_view.dart';

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

  // Pairing by code - the path most people should take.
  final _pairCodeController = TextEditingController();
  final _pairCodeFocus = FocusNode();
  String? _pairError;
  bool _manualEntryOpen = false;
  bool _advancedAiOpen = false;

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
    _pairCodeController.dispose();
    _pairCodeFocus.dispose();
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
              hint: 'Search Hugging Face',
              onChanged: (_) {},
            ),
          ),
          const SizedBox(width: 8),
          NexusButton(
            label: _hfSearching ? 'Searching…' : 'Search',
            style: NexusButtonStyle.tinted,
            compact: true,
            expand: false,
            onTap: _hfSearching ? null : _searchHuggingFace,
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
              // Everything dims while a pull is running, so it's obvious the
              // list is not accepting a second download rather than just
              // ignoring the tap.
              child: Opacity(
                opacity: _pullingModel == null ? 1 : 0.4,
                child: PressScale(
                  onTap: _pullingModel != null ? () {} : () => _pullModel(model),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                              Text(model.name, style: NexusText.bodyMedium),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  model.owner,
                                  if (model.parameterHint != null) model.parameterHint!,
                                  // Stating the RAM up front beats finding out
                                  // by watching a 40 GB download fail to load.
                                  if (estimatedRamGb(model.parameterHint) != null)
                                    '~${estimatedRamGb(model.parameterHint)!.toStringAsFixed(0)} GB RAM',
                                  '${model.downloads} downloads',
                                ].join(' · '),
                                style: NexusText.footnote,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Rows that look like plain list items don't read as
                        // "this starts a multi-gigabyte download".
                        Text(
                          'Download',
                          style: NexusText.footnote.copyWith(
                            color: NexusColors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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

  /// Pairs from a code copied off the machine running the server.
  ///
  /// The code carries every address that server answers on, so this device
  /// ends up able to reach it both at home and from elsewhere - which is the
  /// thing typing a single address into the manual form can never do.
  Future<void> _pairFromCode() async {
    final payload = PairingPayload.decode(_pairCodeController.text);
    if (payload == null) {
      setState(() => _pairError =
          "That doesn't look like a pairing code. Copy it again from Settings > "
          'Server on the computer running NEXUS.');
      return;
    }
    setState(() {
      _busy = true;
      _pairError = null;
    });
    try {
      await ConnectionScope.of(context).onConnect(StoredConnection.fromPayload(payload));
      if (!mounted) return;
      // Keep the fields in step so the manual form shows what was paired.
      _addressController.text = payload.addresses.first;
      _tokenController.text = payload.token;
      _pairCodeController.clear();
    } catch (error) {
      if (mounted) setState(() => _pairError = 'Could not save that pairing: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pastePairCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty || !mounted) return;
    setState(() {
      _pairCodeController.text = text.trim();
      _pairError = null;
    });
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
                        _SettingsPage.ai => [
                            ..._localAiSection(LocalAiScope.of(context), registry),
                            ..._aiSection(registry),
                          ],
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
            onTap: () {
              setState(() => _page = page);
              // Probing sockets and stat-ing paths is cheap, but pointless
              // for someone who never opens this page - so it happens on the
              // way in rather than at launch.
              if (page == _SettingsPage.ai) {
                final ai = LocalAiScope.of(context);
                if (ai.stage == LocalAiStage.unknown) ai.refresh();
              }
            },
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
            'music. Set it under Server > Run a server here, then rescan.',
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
      NexusButton(
        label: 'Rescan library',
        style: NexusButtonStyle.tinted,
        onTap: store.rescanLibrary,
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
      // The pairing code is the path that should feel obvious, so it comes
      // first and carries the whole flow: one paste, no address, no token,
      // and every address the server knows about rather than the single one
      // that happens to work where you're standing.
      NexusCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'On the computer running NEXUS, open Settings > Server and either '
              'scan the QR code with this device or copy the pairing code and '
              'paste it here.',
              style: NexusText.subhead,
            ),
            const SizedBox(height: 14),
            _SettingsField(
              controller: _pairCodeController,
              focusNode: _pairCodeFocus,
              hint: 'nexus://pair?…',
              onChanged: (_) => setState(() => _pairError = null),
            ),
            if (_pairError != null) ...[
              const SizedBox(height: 10),
              Text(_pairError!, style: NexusText.footnote.copyWith(color: NexusColors.red)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: NexusButton(
                    label: _busy ? 'Connecting…' : 'Pair',
                    onTap: _busy || _pairCodeController.text.trim().isEmpty
                        ? null
                        : _pairFromCode,
                  ),
                ),
                const SizedBox(width: 8),
                NexusButton(
                  label: 'Paste',
                  style: NexusButtonStyle.plain,
                  compact: true,
                  expand: false,
                  onTap: _pastePairCode,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      // Kept, but demoted: it's the fallback for a server you run yourself
      // somewhere NEXUS didn't start it, where there is no code to copy.
      _ExpandingSection(
        title: 'Enter an address manually',
        expanded: _manualEntryOpen,
        onToggle: () => setState(() => _manualEntryOpen = !_manualEntryOpen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A Tailscale name (myhouse.tailnet-name.ts.net) for remote access, '
              'or a LAN address (192.168.1.50:8765) at home, plus the pairing '
              'token from the server\'s startup log.',
              style: NexusText.subhead,
            ),
            const SizedBox(height: 16),
            Text('Server address', style: NexusText.footnote),
            const SizedBox(height: 6),
            _SettingsField(
              controller: _addressController,
              focusNode: _addressFocusNode,
              hint: '192.168.1.50:8765',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('Pairing token', style: NexusText.footnote),
            const SizedBox(height: 6),
            _SettingsField(
              controller: _tokenController,
              focusNode: _tokenFocusNode,
              obscureText: true,
              hint: 'From the server startup log',
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: NexusText.footnote.copyWith(color: NexusColors.red)),
            ],
            const SizedBox(height: 20),
            NexusButton(
              label: _busy ? 'Connecting…' : 'Connect',
              onTap: _canConnect ? _connect : null,
            ),
          ],
        ),
      ),
      if (connectionScope.current != null) ...[
        const SizedBox(height: 20),
        // Re-sharing from a paired device means you don't have to walk back to
        // the machine running the server to add a third device.
        _PairingInvite(payload: connectionScope.current!.payload),
        const SizedBox(height: 20),
        NexusButton(
          label: 'Forget this server',
          style: NexusButtonStyle.destructive,
          onTap: _busy ? null : _forget,
        ),
      ],
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
              NexusButton(
                label: 'Rescan library',
                style: NexusButtonStyle.tinted,
                onTap: store.rescanLibrary,
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
                hint: '/home/you/Media',
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
              NexusButton(
                label: local.busy
                    ? 'Working…'
                    : local.running
                        ? 'Stop server'
                        : 'Start server and pair this device',
                // Stopping is the destructive half of the pair, and it should
                // never be the button your thumb lands on by habit.
                style: local.running
                    ? NexusButtonStyle.destructive
                    : NexusButtonStyle.primary,
                onTap: local.busy
                    ? null
                    : (local.running ? local.stop : () => _startLocalServer(local, scope)),
              ),
              if (local.running && local.handle?.pairing != null) ...[
                const SizedBox(height: 18),
                _PairingInvite(payload: local.handle!.pairing!),
              ] else if (local.running) ...[
                const SizedBox(height: 12),
                Text(
                  'Running, but this machine reported no network address, so '
                  'other devices have nothing to connect to. Check that it is '
                  'on a network.',
                  style: NexusText.footnote.copyWith(color: NexusColors.red),
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
              NexusButton(
                label: updates.installing
                    ? 'Downloading…'
                    : 'Download and install ${update.version}',
                onTap: updates.installing ? null : updates.install,
              )
            else
              NexusButton(
                label: updates.checking ? 'Checking…' : 'Check for updates',
                style: NexusButtonStyle.plain,
                onTap: updates.checking ? null : updates.check,
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
              hint: 'Paste your ion token',
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
            NexusButton(
              label: _ionSaved ? 'Saved — reload to apply' : 'Save token',
              onTap: _saveIonToken,
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

  /// Local AI, in as few decisions as it can be reduced to.
  ///
  /// The old version of this screen asked you to install a separate program,
  /// start it, discover its URL, paste that in, and then pull a model by
  /// name - five steps, four of which are about plumbing. This is one button
  /// until there is genuinely something to choose.
  List<Widget> _localAiSection(LocalAiController ai, ProviderRegistry registry) {
    if (!ai.supported) {
      return [
        Text('NEXUS AI'.toUpperCase(), style: NexusText.sectionHeader),
        const SizedBox(height: 10),
        _infoCard(
          'Runs on your server, not here',
          'A browser can\'t hold a model in memory. Set up local AI on the '
              'computer running your NEXUS server and every paired device - '
              'including this one - can use it.',
        ),
        const SizedBox(height: 24),
      ];
    }

    final ram = ai.machineRam;
    return [
      Text('NEXUS AI'.toUpperCase(), style: NexusText.sectionHeader),
      const SizedBox(height: 10),
      NexusCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Run a model on this computer. Nothing leaves the '
                    'compound, no account, no API key.',
                    style: NexusText.subhead,
                  ),
                ),
                if (ai.stage == LocalAiStage.ready) ...[
                  const SizedBox(width: 10),
                  StatusPill(label: 'Ready', color: NexusColors.green),
                ],
              ],
            ),
            if (ram != null) ...[
              const SizedBox(height: 6),
              Text('${ram.round()} GB of memory on this machine.',
                  style: NexusText.footnote),
            ],
            if (ai.error != null) ...[
              const SizedBox(height: 12),
              Text(ai.error!, style: NexusText.footnote.copyWith(color: NexusColors.red)),
            ],
            if (ai.busy) ...[
              const SizedBox(height: 14),
              _ProgressBar(fraction: ai.progress),
              const SizedBox(height: 6),
              Text(
                ai.progress == null
                    ? ai.detail
                    : '${ai.detail}  ${(ai.progress! * 100).round()}%',
                style: NexusText.footnote,
              ),
            ] else ...[
              switch (ai.stage) {
                // Checking happens on its own when this page opens, so there
                // is nothing to ask for here - just say what's happening.
                LocalAiStage.unknown => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Checking this computer…', style: NexusText.footnote),
                  ),
                LocalAiStage.notInstalled || LocalAiStage.failed => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: NexusButton(
                      label: 'Set up local AI',
                      onTap: ai.setUp,
                    ),
                  ),
                _ => const SizedBox.shrink(),
              },
            ],
            if (!ai.busy &&
                (ai.stage == LocalAiStage.noModel || ai.stage == LocalAiStage.ready)) ...[
              const SizedBox(height: 18),
              Text('Model'.toUpperCase(), style: NexusText.sectionHeader),
              const SizedBox(height: 8),
              // Named by what they are for rather than by parameter count, and
              // greyed when this machine can't run them well - a model that
              // swaps reads as broken, not slow.
              for (final model in localModelCatalog)
                _ModelRow(
                  model: model,
                  installed: ai.installedModels.any((m) => m.startsWith(model.id.split(':').first)),
                  recommended: model.id == ai.recommended.id,
                  fits: model.fitsIn(ram),
                  active: registry.activeModel == model.id,
                  onTap: () => ai.downloadModel(model),
                ),
              if (ai.installedModels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('On this computer', style: NexusText.footnote),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final model in ai.installedModels)
                      _AiProviderChip(
                        label: model,
                        selected: registry.activeModel == model,
                        onTap: () => ai.selectModel(model),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _aiSection(ProviderRegistry registry) {
    final needsCredential = _aiKind != AiProviderKind.local;
    final isKeyProvider = _aiKind == AiProviderKind.anthropic || _aiKind == AiProviderKind.openai;
    return [
      // Collapsed by default. Cloud keys and hand-configured engines are real
      // options, but putting four radio buttons above "Set up local AI" makes
      // a one-button feature look like a configuration screen.
      _ExpandingSection(
        title: 'Advanced - cloud keys, other engines',
        expanded: _advancedAiOpen,
        onToggle: () => setState(() => _advancedAiOpen = !_advancedAiOpen),
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
                hint: 'http://127.0.0.1:11434',
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
              NexusButton(
                label: _probingOllama ? 'Checking…' : 'Detect installed models',
                style: NexusButtonStyle.plain,
                onTap: _probingOllama ? null : _probeOllama,
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
                hint: 'Paste your API key',
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
                hint: 'llama3.1',
                onChanged: (_) => setState(() => _aiSaved = false),
              ),
            ],
            const SizedBox(height: 20),
            NexusButton(
              label: _aiSaved ? 'Saved' : 'Save AI settings',
              onTap: () => _saveAi(registry),
            ),
          ],
        ),
      ),
    ];
  }
}


/// A pill for picking the active AI provider.
/// A determinate bar while there are bytes to count, indeterminate-looking
/// otherwise. A frozen 0% during a phase with no measurable size reads as
/// hung, which on a multi-gigabyte download is the difference between waiting
/// and force-quitting.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double? fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: NexusColors.secondarySurface,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction ?? 0.08,
        child: Container(
          decoration: BoxDecoration(
            color: NexusColors.blue,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// One model in the picker: what it's for, what it costs, and whether this
/// machine can actually run it.
class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.installed,
    required this.recommended,
    required this.fits,
    required this.active,
    required this.onTap,
  });

  final LocalModel model;
  final bool installed;
  final bool recommended;
  final bool fits;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (installed) 'Installed' else '${formatGb(model.downloadGb)} download',
      '${model.needsRamGb.round()} GB memory',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        // Dimmed rather than hidden: knowing a bigger model exists, and that
        // this machine is why it's unavailable, is useful information.
        opacity: fits ? 1 : 0.45,
        child: PressScale(
          onTap: fits ? onTap : () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: active
                  ? NexusColors.blue.withValues(alpha: 0.10)
                  : NexusColors.secondarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? NexusColors.blue : const Color(0x00000000),
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(model.name, style: NexusText.bodyMedium),
                          if (recommended && fits) ...[
                            const SizedBox(width: 8),
                            StatusPill(
                              label: 'Recommended',
                              color: NexusColors.blue,
                              dense: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(model.blurb, style: NexusText.footnote),
                      const SizedBox(height: 2),
                      Text(subtitle, style: NexusText.footnote),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  active
                      ? 'In use'
                      : fits
                          ? (installed ? 'Use' : 'Get')
                          : 'Too big',
                  style: NexusText.footnote.copyWith(
                    color: active ? NexusColors.blue : NexusColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A collapsed card that opens on tap.
///
/// For the paths that have to exist but shouldn't be the first thing anyone
/// reads - manual address entry now that a pairing code does the same job in
/// one paste.
class _ExpandingSection extends StatelessWidget {
  const _ExpandingSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NexusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressScale(
            onTap: onToggle,
            child: Row(
              children: [
                Expanded(child: Text(title, style: NexusText.bodyMedium)),
                Text(
                  expanded ? '⌄' : '›',
                  style: NexusText.title.copyWith(
                    color: NexusColors.textFaint,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );
  }
}

/// Everything another device needs, as one thing to point a camera at.
///
/// The QR encodes an ordinary https link to the NEXUS web app with the
/// pairing in its fragment. That means a phone's *built-in* camera opens it -
/// no app to install first, nothing to launch, and no in-app scanner to get
/// the permissions wrong on. The same pairing pasted into an installed app
/// works identically, which is what the text code underneath is for.
class _PairingInvite extends StatefulWidget {
  const _PairingInvite({required this.payload});

  final PairingPayload payload;

  @override
  State<_PairingInvite> createState() => _PairingInviteState();
}

class _PairingInviteState extends State<_PairingInvite> {
  bool _copied = false;
  bool _showCode = false;

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;
    final remote = payload.remoteAddresses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add another device'.toUpperCase(), style: NexusText.sectionHeader),
        const SizedBox(height: 8),
        Text(
          'Point a phone camera at this. It opens NEXUS already connected - '
          'nothing to type, nothing to install first.',
          style: NexusText.subhead.copyWith(color: NexusColors.textMuted),
        ),
        const SizedBox(height: 14),
        Center(child: QrView(data: payload.encodeWebLink(nexusWebAppUrl))),
        const SizedBox(height: 14),
        // Whether this pairing survives leaving the house is the single most
        // useful thing to know here, and it is invisible otherwise.
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: remote.isEmpty ? NexusColors.amber : NexusColors.green,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                remote.isEmpty
                    ? 'Home network only. Install Tailscale on this machine to '
                        'reach it while travelling.'
                    : 'Works away from home too, over ${remote.first.split(':').first}.',
                style: NexusText.footnote,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            NexusButton(
              label: _copied ? 'Copied' : 'Copy code',
              style: NexusButtonStyle.tinted,
              compact: true,
              expand: false,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: payload.encode()));
                if (mounted) setState(() => _copied = true);
              },
            ),
            const SizedBox(width: 8),
            NexusButton(
              label: _showCode ? 'Hide code' : 'Show code',
              style: NexusButtonStyle.plain,
              compact: true,
              expand: false,
              onTap: () => setState(() => _showCode = !_showCode),
            ),
          ],
        ),
        if (_showCode) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: NexusColors.secondarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(payload.encode(), style: NexusText.footnote),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste this into Settings > Server on any device that already has '
            'NEXUS installed. Treat it like a password: it grants full control '
            'of the compound.',
            style: NexusText.footnote,
          ),
        ],
      ],
    );
  }
}

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
    this.hint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool obscureText;

  /// An example of what belongs here. EditableText draws no decoration of its
  /// own, so without this every field is an anonymous grey box - which is
  /// exactly the wrong thing on the screen where you type a server address.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: NexusColors.secondarySurface, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Stack(
        children: [
          if (hint != null)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? IgnorePointer(
                      child: Text(
                        hint!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NexusText.body.copyWith(color: NexusColors.textFaint),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          EditableText(
            controller: controller,
            focusNode: focusNode,
            style: NexusText.body,
            cursorColor: NexusColors.blue,
            backgroundCursorColor: NexusColors.textFaint,
            obscureText: obscureText,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
