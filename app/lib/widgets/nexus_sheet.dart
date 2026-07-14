import 'package:flutter/material.dart' show Material;
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';

/// Bottom sheet with a drag handle, sliding up with the spec's
/// `cubic-bezier(.32,.72,0,1)` easing (Section 2/3). Tapping the scrim
/// behind the sheet dismisses it.
Future<T?> showNexusSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxHeightFraction = 0.76,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: NexusColors.overlayScrim,
    transitionDuration: NexusDurations.sheet,
    pageBuilder: (context, animation, secondaryAnimation) {
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * maxHeightFraction,
            ),
            child: Builder(builder: builder),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: NexusCurves.sheetUp);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

class NexusSheet extends StatelessWidget {
  const NexusSheet({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x00000000),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: NexusColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(NexusRadii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Flexible(
              child: Padding(
                padding: padding ?? const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
