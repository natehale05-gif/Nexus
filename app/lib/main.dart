import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nexus_shared/nexus_shared.dart';
import 'ai/ai_settings.dart';
import 'ai/provider_registry.dart';
import 'state/ai_scope.dart';
import 'state/app_mode.dart';
import 'state/compound_persistence.dart';
import 'state/compound_scope.dart';
import 'state/compound_store.dart';
import 'state/connection_scope.dart';
import 'state/connection_settings.dart';
import 'state/download_manager.dart';
import 'state/download_scope.dart';
import 'state/nexus_data_source.dart';
import 'state/update_scope.dart';
import 'state/server_client.dart';
import 'theme/app_theme.dart';
import 'screens/nexus_ai/chat_engine.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/root_shell.dart';

void main() {
  // Required once at startup before any media_kit Player is created (Media
  // tab real playback - see screens/media/media_tab.dart).
  MediaKit.ensureInitialized();
  runApp(const NexusApp());
}

class NexusApp extends StatefulWidget {
  const NexusApp({super.key});

  @override
  State<NexusApp> createState() => _NexusAppState();
}

class _NexusAppState extends State<NexusApp> {
  final _settings = ConnectionSettings();
  final _modeSettings = AppModeSettings();
  final _downloads = DownloadManager();
  final _updates = UpdateController();
  late NexusDataSource _store = _createInitialDataSource();
  StoredConnection? _current;

  /// Null until the persisted mode has been read. Onboarding shows only once
  /// that read has finished and come back empty - otherwise a slow keystore
  /// would flash the setup screen at someone who already chose.
  AppMode? _mode;
  bool _modeResolved = false;

  /// Multi-provider AI routing (on-device / Mac Studio / Anthropic / OpenAI).
  /// The `storeOf`/`systemContext`/`localResponder` callbacks close over the
  /// *current* store so the AI always sees live house state and can control
  /// devices, even after a reconnect swaps [_store].
  late final ProviderRegistry _ai = ProviderRegistry(
    settings: AiSettings(),
    storeOf: () => _store,
    systemContext: () => buildSystemContext(_store.compound),
    localResponder: (text) => generateAssistantReply(text, _store),
  );

  /// Defaults to local-demo-mode ([CompoundStore]) exactly like the build
  /// order calls for ("wired to local state first, no server yet"), same
  /// as before. `?server=<host:port>&token=<token>` in the URL (web)
  /// still works as a quick testing override and always wins.
  ///
  /// On top of that, if this device has previously paired with a server
  /// via the Settings tab, that persisted connection takes over
  /// automatically once it's loaded from secure storage - see
  /// [_loadPersistedConnection], called from [initState]. This replaces
  /// the old web-only query-param-or-nothing choice with a connection
  /// that works identically on every platform and survives relaunches.
  NexusDataSource _createInitialDataSource() {
    final server = Uri.base.queryParameters['server'];
    if (server != null && server.isNotEmpty) {
      final token = Uri.base.queryParameters['token'] ?? '';
      return ServerClient(hostOrUrl: server, token: token);
    }
    return CompoundStore();
  }

  @override
  void initState() {
    super.initState();
    _restoreMode();
    _loadPersistedConnection();
    // Load any previously-downloaded titles (native only; a no-op on web).
    _downloads.load();
    // Load this device's preferred AI provider/model + keys.
    _ai.load();
    // Look for a newer release in the background. No-ops on dev builds and
    // fails silently, so it can never block or interrupt startup.
    _updates.check();
  }

  /// Reads the saved mode and, for a local compound, the saved compound with
  /// it. The `?server=` override implies server mode without asking.
  Future<void> _restoreMode() async {
    if (_store is ServerClient) {
      if (mounted) {
        setState(() {
          _mode = AppMode.server;
          _modeResolved = true;
        });
      }
      return;
    }
    final mode = await _modeSettings.load();
    if (!mounted) return;
    if (mode == AppMode.local) {
      final saved = await loadCompound();
      if (!mounted) return;
      _switchTo(_localStore(saved), current: null);
    }
    setState(() {
      _mode = mode;
      _modeResolved = true;
    });
  }

  /// A store over the user's own compound: no simulation ticker, and every
  /// change written straight back to disk.
  CompoundStore _localStore(Compound? seed) =>
      CompoundStore(seed: seed ?? buildEmptyCompound(), simulate: false, onPersist: saveCompound);

  Future<void> _chooseMode(AppMode mode) async {
    await _modeSettings.save(mode);
    if (!mounted) return;
    switch (mode) {
      case AppMode.local:
        _switchTo(_localStore(null), current: null);
      case AppMode.demo:
        _switchTo(CompoundStore(), current: null);
      case AppMode.server:
        // Land in an empty local compound so the shell has something to
        // render, and let the Settings tab drive the actual pairing.
        _switchTo(_localStore(null), current: null);
    }
    setState(() => _mode = mode);
  }

  Future<void> _loadPersistedConnection() async {
    // The `?server=` override above always wins over a persisted setting.
    if (_store is ServerClient) return;
    StoredConnection? stored;
    try {
      stored = await _settings.load();
    } catch (_) {
      // No secure-storage backing available (e.g. an unconfigured
      // platform, or a widget test with no plugin bindings) - just stay
      // in local-demo-mode rather than crashing startup.
      return;
    }
    if (stored != null && mounted) {
      _switchTo(
        ServerClient(hostOrUrl: stored.serverAddress, token: stored.token),
        current: stored,
      );
    }
  }

  void _switchTo(NexusDataSource newStore, {StoredConnection? current}) {
    final old = _store;
    setState(() {
      _store = newStore;
      _current = current;
    });
    old.dispose();
  }

  Future<void> _connect(StoredConnection connection) async {
    await _settings.save(connection);
    await _modeSettings.save(AppMode.server);
    if (mounted) setState(() => _mode = AppMode.server);
    _switchTo(
      ServerClient(hostOrUrl: connection.serverAddress, token: connection.token),
      current: connection,
    );
  }

  Future<void> _forget() async {
    await _settings.clear();
    await _modeSettings.clear();
    _switchTo(_localStore(await loadCompound()), current: null);
    if (mounted) setState(() => _mode = null);
  }

  @override
  void dispose() {
    _store.dispose();
    _downloads.dispose();
    _updates.dispose();
    _ai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionScope(
      current: _current,
      onConnect: _connect,
      onForget: _forget,
      mode: _mode,
      onChooseMode: _chooseMode,
      child: UpdateScope(
        controller: _updates,
        child: AiScope(
          registry: _ai,
          child: DownloadScope(
            manager: _downloads,
            child: CompoundScope(
              store: _store,
              child: MaterialApp(
                title: 'NEXUS',
                debugShowCheckedModeBanner: false,
                theme: buildNexusTheme(),
                home: (_modeResolved && _mode == null)
                    ? OnboardingScreen(onChoose: _chooseMode)
                    : const RootShell(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
