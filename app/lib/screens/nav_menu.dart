import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../icons/nexus_icons.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../widgets/press_scale.dart';

/// The top-level sections. Navigation moved from a bottom tab bar to a
/// single Apple-style pop-up menu in the top-right (see [NexusMenuButton]).
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
/// the pop-up menu can live wherever it reads best (floating over the map on
/// Home, in the header on the other tabs) without threading callbacks.
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

/// The top-right navigation control: a translucent pop-up button showing the
/// current section, which opens a blurred Apple-style menu to switch sections.
///
/// [onDark] tunes it for the dark map (Home) vs. the light section screens.
class NexusMenuButton extends StatefulWidget {
  const NexusMenuButton({super.key, this.onDark = false});

  final bool onDark;

  @override
  State<NexusMenuButton> createState() => _NexusMenuButtonState();
}

class _NexusMenuButtonState extends State<NexusMenuButton> {
  OverlayEntry? _entry;
  GlobalKey<_MenuOverlayState>? _menuKey;

  @override
  void dispose() {
    // Remove synchronously - the overlay owns its own ticker, but on teardown
    // we can't wait for an exit animation.
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _toggle() {
    if (_entry != null) {
      _menuKey?.currentState?.close();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    final nav = NexusNavScope.of(context);
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final screen = MediaQuery.of(context).size;
    final topLeft = box.localToGlobal(Offset.zero);
    final top = topLeft.dy + box.size.height + 10;
    final right = screen.width - (topLeft.dx + box.size.width);

    final key = GlobalKey<_MenuOverlayState>();
    _menuKey = key;
    _entry = OverlayEntry(
      builder: (context) => _MenuOverlay(
        key: key,
        top: top,
        right: right,
        active: nav.active,
        onSelected: (tab) {
          if (tab != nav.active) nav.onSelect(tab);
        },
        onClosed: () {
          _entry?.remove();
          _entry = null;
          _menuKey = null;
        },
      ),
    );
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    final active = NexusNavScope.of(context).active;
    final spec = specFor(active);
    final fg = widget.onDark ? const Color(0xFFFFFFFF) : NexusColors.textPrimary;
    final bg = widget.onDark ? const Color(0x40101528) : const Color(0xCCFFFFFF);
    final border =
        widget.onDark ? const Color(0x33FFFFFF) : const Color(0x14000000);

    return PointerInterceptor(
      child: PressScale(
        onTap: _toggle,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(NexusRadii.pill),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 40,
              padding: const EdgeInsets.fromLTRB(13, 0, 11, 0),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(NexusRadii.pill),
                border: Border.all(color: border, width: 0.8),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NexusIcon(spec.glyph, size: 17, color: fg),
                  const SizedBox(width: 7),
                  Text(
                    spec.label,
                    style: NexusText.bodyMedium.copyWith(color: fg, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 5),
                  NexusIcon(NexusGlyph.chevronDown, size: 13, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuOverlay extends StatefulWidget {
  const _MenuOverlay({
    super.key,
    required this.top,
    required this.right,
    required this.active,
    required this.onSelected,
    required this.onClosed,
  });

  final double top;
  final double right;
  final NexusTab active;
  final ValueChanged<NexusTab> onSelected;
  final VoidCallback onClosed;

  @override
  State<_MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<_MenuOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 210),
    reverseDuration: const Duration(milliseconds: 150),
  )..forward();
  bool _closing = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void close() {
    if (_closing) return;
    _closing = true;
    _c.reverse().whenComplete(widget.onClosed);
  }

  void _pick(NexusTab tab) {
    widget.onSelected(tab);
    close();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _c,
      curve: NexusCurves.sheetUp,
      reverseCurve: Curves.easeInCubic,
    );
    return Stack(
      children: [
        // Full-screen dismiss barrier (intercepts taps even over the map iframe).
        Positioned.fill(
          child: PointerInterceptor(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          top: widget.top,
          right: widget.right,
          child: AnimatedBuilder(
            animation: curved,
            builder: (context, child) {
              return Opacity(
                opacity: curved.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.92 + 0.08 * curved.value,
                  alignment: Alignment.topRight,
                  child: child,
                ),
              );
            },
            child: PointerInterceptor(
              child: _MenuCard(active: widget.active, onPick: _pick),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.active, required this.onPick});

  final NexusTab active;
  final ValueChanged<NexusTab> onPick;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          width: 224,
          decoration: BoxDecoration(
            color: const Color(0xF2FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14000000), width: 0.8),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < nexusTabs.length; i++) ...[
                if (i != 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      height: 0.6,
                      width: double.infinity,
                      child: ColoredBox(color: Color(0x11000000)),
                    ),
                  ),
                _MenuItem(
                  spec: nexusTabs[i],
                  selected: nexusTabs[i].tab == active,
                  onTap: () => onPick(nexusTabs[i].tab),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.spec, required this.selected, required this.onTap});

  final NexusTabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NexusColors.blue : NexusColors.textPrimary;
    return PressScale(
      scale: 0.97,
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 10),
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
            if (selected) NexusIcon(NexusGlyph.check, size: 16, color: NexusColors.blue),
          ],
        ),
      ),
    );
  }
}
