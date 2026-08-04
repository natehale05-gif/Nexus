import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'drive/drive_tab.dart';
import 'home/home_tab.dart';
import 'security/security_tab.dart';
import 'media/tv_tab.dart';
import 'nexus_ai/nexus_ai_tab.dart';
import 'settings/settings_tab.dart';
import 'nav_menu.dart';

/// App shell. Navigation is always on screen: a bottom tab bar on phone-sized
/// windows, a left rail once there's room for one. Home is the exception in
/// how the bar is drawn - the map runs full-bleed underneath a frosted bar,
/// Apple Maps style - but it's the same bar, in the same place, either way.
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
      case NexusTab.security:
        return const SecurityTab();
      case NexusTab.tv:
        return const TvTab();
      case NexusTab.drive:
        return const DriveTab();
      case NexusTab.nexusAi:
        return const NexusAiTab();
      case NexusTab.settings:
        return const SettingsTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= NexusBreakpoints.wide;
    final onHome = _active == NexusTab.home;

    // IndexedStack keeps each section's scroll position and any playing video
    // alive across switches, which is most of why switching feels instant.
    final stack = IndexedStack(
      index: nexusTabs.indexWhere((t) => t.tab == _active),
      children: [for (final t in nexusTabs) _bodyFor(t.tab)],
    );

    // Home is always full-bleed. On wide viewports the reading-oriented
    // sections get a centered max-width column instead of just stretching.
    final Widget content = (wide && !onHome)
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: stack,
            ),
          )
        : stack;

    final Widget body;
    if (wide) {
      body = Row(
        children: [
          const NexusSidebar(),
          Expanded(child: content),
        ],
      );
    } else if (onHome) {
      // Over the map, so the scene keeps the full height of the screen.
      body = Stack(
        children: [
          Positioned.fill(child: content),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NexusTabBar(onDark: true),
          ),
        ],
      );
    } else {
      // Under content, so nothing scrolls beneath the bar and gets clipped.
      body = Column(
        children: [
          Expanded(child: content),
          const NexusTabBar(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: NexusColors.background,
      body: NexusNavScope(
        active: _active,
        onSelect: (t) => setState(() => _active = t),
        child: body,
      ),
    );
  }
}
