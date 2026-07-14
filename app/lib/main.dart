import 'package:flutter/material.dart';
import 'state/compound_scope.dart';
import 'state/compound_store.dart';
import 'state/nexus_data_source.dart';
import 'state/server_client.dart';
import 'theme/app_theme.dart';
import 'screens/root_shell.dart';

void main() {
  runApp(const NexusApp());
}

class NexusApp extends StatefulWidget {
  const NexusApp({super.key});

  @override
  State<NexusApp> createState() => _NexusAppState();
}

class _NexusAppState extends State<NexusApp> {
  late final NexusDataSource _store = _createDataSource();

  /// Defaults to local-demo-mode ([CompoundStore]) exactly like the build
  /// order calls for ("wired to local state first, no server yet"). Pass
  /// `?server=<host:port>` in the URL (web) to point the app at a real
  /// running `nexus_server` instance instead - e.g.
  /// `?server=192.168.1.50:8765` on your LAN, or a Tailscale hostname for
  /// remote access (Section 8).
  NexusDataSource _createDataSource() {
    final server = Uri.base.queryParameters['server'];
    if (server != null && server.isNotEmpty) {
      return ServerClient(hostOrUrl: server);
    }
    return CompoundStore();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompoundScope(
      store: _store,
      child: MaterialApp(
        title: 'NEXUS',
        debugShowCheckedModeBanner: false,
        theme: buildNexusTheme(),
        home: const RootShell(),
      ),
    );
  }
}
