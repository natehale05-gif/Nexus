import 'package:flutter/widgets.dart';

import 'download_manager.dart';

/// Provides the app-wide [DownloadManager] to the widget tree and rebuilds
/// dependents when download state changes (progress, completion, deletion) -
/// same `InheritedNotifier` shape as [CompoundScope].
class DownloadScope extends InheritedNotifier<DownloadManager> {
  const DownloadScope({
    super.key,
    required DownloadManager manager,
    required super.child,
  }) : super(notifier: manager);

  static DownloadManager of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DownloadScope>();
    assert(scope != null, 'No DownloadScope found in context');
    return scope!.notifier!;
  }
}
