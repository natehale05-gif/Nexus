import 'package:flutter/material.dart';
import '../icons/nexus_icons.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'home/home_tab.dart';
import 'security/security_tab.dart';
import 'media/media_tab.dart';
import 'nexus_ai/nexus_ai_tab.dart';

enum NexusTab { home, security, media, nexusAi }

class _TabSpec {
  const _TabSpec(this.tab, this.label, this.glyph);
  final NexusTab tab;
  final String label;
  final NexusGlyph glyph;
}

const _tabs = [
  _TabSpec(NexusTab.home, 'Home', NexusGlyph.mapPinBase),
  _TabSpec(NexusTab.security, 'Security', NexusGlyph.camera),
  _TabSpec(NexusTab.media, 'Media', NexusGlyph.tv),
  _TabSpec(NexusTab.nexusAi, 'NEXUS', NexusGlyph.sparkle),
];

/// App shell: 4-tab bottom nav on phone widths, sidebar + detail-pane on
/// wide viewports (Section 1, "Platform priority" - macOS/web reflow
/// rather than stretch).
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
      case NexusTab.media:
        return const MediaTab();
      case NexusTab.nexusAi:
        return const NexusAiTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= NexusBreakpoints.wide;
    final body = IndexedStack(
      index: _tabs.indexWhere((t) => t.tab == _active),
      children: [for (final t in _tabs) _bodyFor(t.tab)],
    );

    if (wide) {
      // Home stays full-bleed edge-to-edge even on wide viewports (Section
      // 3); the other tabs get a centered max-width reading column instead
      // of just stretching the phone layout (Section 1).
      final detailPane = _active == NexusTab.home
          ? body
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: body,
              ),
            );

      return Scaffold(
        backgroundColor: NexusColors.background,
        body: Row(
          children: [
            _Sidebar(active: _active, onSelect: (t) => setState(() => _active = t)),
            const VerticalDivider(width: 1, color: NexusColors.separator),
            Expanded(child: detailPane),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: NexusColors.background,
      body: body,
      bottomNavigationBar: _PhoneTabBar(active: _active, onSelect: (t) => setState(() => _active = t)),
    );
  }
}

class _PhoneTabBar extends StatelessWidget {
  const _PhoneTabBar({required this.active, required this.onSelect});

  final NexusTab active;
  final ValueChanged<NexusTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NexusColors.surface,
        border: Border(top: BorderSide(color: NexusColors.separator, width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (final spec in _tabs)
                Expanded(
                  child: _TabButton(
                    spec: spec,
                    selected: spec.tab == active,
                    onTap: () => onSelect(spec.tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.spec, required this.selected, required this.onTap});

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NexusColors.blue : NexusColors.textFaint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NexusIcon(spec.glyph, size: 22, color: color),
          const SizedBox(height: 3),
          Text(spec.label, style: NexusText.caption.copyWith(color: color, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.active, required this.onSelect});

  final NexusTab active;
  final ValueChanged<NexusTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: NexusColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text('NEXUS', style: NexusText.title),
            ),
            for (final spec in _tabs)
              _SidebarItem(spec: spec, selected: spec.tab == active, onTap: () => onSelect(spec.tab)),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.spec, required this.selected, required this.onTap});

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? NexusColors.blue.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              NexusIcon(spec.glyph, size: 19, color: selected ? NexusColors.blue : NexusColors.textMuted),
              const SizedBox(width: 12),
              Text(
                spec.label,
                style: NexusText.bodyMedium.copyWith(
                  color: selected ? NexusColors.blue : NexusColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
