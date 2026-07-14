import 'package:flutter/widgets.dart';
import 'nexus_data_source.dart';

/// Lightweight `InheritedNotifier`-based access to whichever
/// [NexusDataSource] is active (local demo [CompoundStore] or live
/// [ServerClient]) - no third-party state-management package, per the
/// "no third-party middleware" spirit of the build prompt (Section 1
/// talks about the smart home platform, but the app layer stays
/// dependency-light too).
class CompoundScope extends InheritedNotifier<NexusDataSource> {
  const CompoundScope({
    super.key,
    required NexusDataSource store,
    required super.child,
  }) : super(notifier: store);

  static NexusDataSource of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CompoundScope>();
    assert(scope != null, 'No CompoundScope found in context');
    return scope!.notifier!;
  }
}
