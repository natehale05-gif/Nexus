import 'package:flutter/widgets.dart';

import '../ai/provider_registry.dart';

/// Provides the app-wide [ProviderRegistry] to the widget tree and rebuilds
/// dependents when the active provider/model changes - same
/// `InheritedNotifier` shape as [CompoundScope]/[DownloadScope].
class AiScope extends InheritedNotifier<ProviderRegistry> {
  const AiScope({
    super.key,
    required ProviderRegistry registry,
    required super.child,
  }) : super(notifier: registry);

  static ProviderRegistry of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AiScope>();
    assert(scope != null, 'No AiScope found in context');
    return scope!.notifier!;
  }
}
