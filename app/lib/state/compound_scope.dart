import 'package:flutter/widgets.dart';
import 'compound_store.dart';

/// Lightweight `InheritedNotifier`-based access to [CompoundStore] - no
/// third-party state-management package, per the "no third-party
/// middleware" spirit of the build prompt (Section 1 talks about the smart
/// home platform, but the app layer stays dependency-light too).
class CompoundScope extends InheritedNotifier<CompoundStore> {
  const CompoundScope({
    super.key,
    required CompoundStore store,
    required super.child,
  }) : super(notifier: store);

  static CompoundStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CompoundScope>();
    assert(scope != null, 'No CompoundScope found in context');
    return scope!.notifier!;
  }
}
