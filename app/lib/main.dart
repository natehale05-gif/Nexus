import 'package:flutter/material.dart';
import 'state/compound_scope.dart';
import 'state/compound_store.dart';
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
  late final CompoundStore _store = CompoundStore();

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
