import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../icons/nexus_icons.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../widgets/press_scale.dart';

/// The top-level sections.
enum NexusTab { home, buildings, security, media, nexusAi, settings }

class NexusTabSpec {
  const NexusTabSpec(this.tab, this.label, this.glyph);
  final NexusTab tab;
  final String label;
  final NexusGlyph glyph;
}

const List<NexusTabSpec> nexusTabs = [
  NexusTabSpec(NexusTab.home, 'Home', NexusGlyph.mapPinBase),
  NexusTabSpec(NexusTab.buildings, 'Buildings', NexusGlyph.gate),
  NexusTabSpec(NexusTab.security, 'Security', NexusGlyph.camera),
  NexusTabSpec(NexusTab.media, 'Media', NexusGlyph.tv),
  NexusTabSpec(NexusTab.nexusAi, 'NEXUS', NexusGlyph.sparkle),
  NexusTabSpec(NexusTab.settings, 'Settings', NexusGlyph.gear),
];

NexusTabSpec specFor(NexusTab tab) => nexusTabs.firstWhere((s) => s.tab == tab);

/// Exposes the active section + a setter to anything below the root shell, so
/// deep content can navigate without threading callbacks through every widget.
class NexusNavScope extends InheritedWidget {
  const NexusNavScope({
    super.key,
    required this.active,
    required this.onSelect,
    required super.child,
  });

  final NexusTab active;
  final ValueChanged<NexusTab> onSelect;

  static NexusNavScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NexusNavScope>();
    assert(scope != null, 'No NexusNavScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(NexusNavScope oldWidget) => oldWidget.active != active;
}

/// Height of [NexusTabBar] above the home-indicator inset.
const double kNexusTabBarHeight = 54;

/// Persistent bottom navigation.
///
/// This used to be a pop-up menu in the top-right, which meant every section
/// change cost two taps and hid where you could even go. A tab bar makes the
/// whole app visible at once and switching a single tap - the thing that most
/// made this feel fiddly to use.
///
/// [onDark] tunes it for the dark map on Home, where it floats over the scene
/// rather than sitting under content.
class NexusTabBar extends StatelessWidget {
  const NexusTabBar({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final nav = NexusNavScope.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return PointerInterceptor(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: onDark ? const Color(0xB3101528) : const Color(0xF2FFFFFF),
              border: Border(
                top: BorderSide(
                  color: onDark ? const Color(0x26FFFFFF) : NexusColors.cardBorder,
                  width: 0.6,
                ),
              ),
            ),
            child: SizedBox(
              height: kNexusTabBarHeight,
              child: Row(
                children: [
                  for (final spec in nexusTabs)
                    Expanded(
                      child: _BarItem(
                        spec: spec,
                        selected: spec.tab == nav.active,
                        onDark: onDark,
                        onTap: () => nav.onSelect(spec.tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.spec,
    required this.selected,
    required this.onDark,
    required this.onTap,
  });

  final NexusTabSpec spec;
  final bool selected;
  final bool onDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (selected) {
      color = onDark ? const Color(0xFF5AC8FA) : NexusColors.blue;
    } else {
      color = onDark ? const Color(0x99FFFFFF) : NexusColors.textFaint;
    }

    return PressScale(
      scale: 0.9,
      onTap: onTap,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The selected icon animates rather than swapping instantly, so a
            // tap reads as movement between sections instead of a repaint.
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: NexusDurations.fast,
              curve: Curves.easeOut,
              child: NexusIcon(spec.glyph, size: 21, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: NexusText.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Width of [NexusSidebar].
const double kNexusSidebarWidth = 232;

/// The same navigation on a wide window, where a bottom bar wastes the space
/// a desktop actually has: a permanent left rail with room for full labels.
class NexusSidebar extends StatelessWidget {
  const NexusSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = NexusNavScope.of(context);
    return Container(
      width: kNexusSidebarWidth,
      decoration: const BoxDecoration(
        color: NexusColors.surface,
        border: Border(right: BorderSide(color: NexusColors.cardBorder, width: 0.6)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Text(
                'NEXUS',
                style: NexusText.headline.copyWith(letterSpacing: 2, fontWeight: FontWeight.w700),
              ),
            ),
            for (final spec in nexusTabs)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: _RailItem(
                  spec: spec,
                  selected: spec.tab == nav.active,
                  onTap: () => nav.onSelect(spec.tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.spec, required this.selected, required this.onTap});

  final NexusTabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NexusColors.blue : NexusColors.textSecondary;
    return PressScale(
      scale: 0.98,
      onTap: onTap,
      child: AnimatedContainer(
        duration: NexusDurations.fast,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? NexusColors.blue.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            NexusIcon(spec.glyph, size: 19, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                spec.label,
                style: NexusText.body.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
