import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'state/compound_scope.dart';
import 'state/compound_store.dart';
import 'state/connection_scope.dart';
import 'state/connection_settings.dart';
import 'state/nexus_data_source.dart';
import 'state/server_client.dart';
import 'theme/app_theme.dart';
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
  late NexusDataSource _store = _createInitialDataSource();
  StoredConnection? _current;

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
    _loadPersistedConnection();
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
      _switchTo(ServerClient(hostOrUrl: stored.serverAddress, token: stored.token), current: stored);
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
    _switchTo(ServerClient(hostOrUrl: connection.serverAddress, token: connection.token), current: connection);
  }

  Future<void> _forget() async {
    await _settings.clear();
    _switchTo(CompoundStore(), current: null);
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionScope(
      current: _current,
      onConnect: _connect,
      onForget: _forget,
      child: CompoundScope(
        store: _store,
        child: MaterialApp(
          title: 'NEXUS',
          debugShowCheckedModeBanner: false,
          theme: buildNexusTheme(),
          home: const RootShell(),
        ),
      ),
    );
  }
}
