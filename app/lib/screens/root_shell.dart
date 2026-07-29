import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'buildings/buildings_tab.dart';
import 'home/home_tab.dart';
import 'security/security_tab.dart';
import 'media/media_tab.dart';
import 'nexus_ai/nexus_ai_tab.dart';
import 'settings/settings_tab.dart';
import 'nav_menu.dart';

/// App shell. Navigation is a single Apple-style pop-up menu in the top-right
/// (see [NexusMenuButton]) rather than a bottom tab bar - it floats over the
/// map on Home and sits in the header on the other sections. The active
/// section + setter are shared down the tree via [NexusNavScope].
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  NexusTab _active = NexusTab.home;

  Widget _bodyFor(NexusTab tab) {
    switch (tab) {
      case NexusTab.home:
        return const HomeTab();
      case NexusTab.buildings:
        return const BuildingsTab();
      case NexusTab.security:
        return const SecurityTab();
      case NexusTab.media:
        return const MediaTab();
      case NexusTab.nexusAi:
        return const NexusAiTab();
      case NexusTab.settings:
        return const SettingsTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= NexusBreakpoints.wide;

    final stack = IndexedStack(
      index: nexusTabs.indexWhere((t) => t.tab == _active),
      children: [for (final t in nexusTabs) _bodyFor(t.tab)],
    );

    // Home is always full-bleed. On wide viewports the reading-oriented
    // sections get a centered max-width column instead of just stretching.
    final Widget content = (wide && _active != NexusTab.home)
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: stack,
            ),
          )
        : stack;

    return Scaffold(
      backgroundColor: NexusColors.background,
      body: NexusNavScope(
        active: _active,
        onSelect: (t) => setState(() => _active = t),
        child: content,
      ),
    );
  }
}
