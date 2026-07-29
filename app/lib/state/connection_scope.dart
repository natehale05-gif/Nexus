import 'package:flutter/widgets.dart';

import 'app_mode.dart';
import 'connection_settings.dart';

/// Lets the Settings screen ask [NexusApp] to swap the app's active
/// [NexusDataSource] between local-demo-mode and a live server connection,
/// without needing to know how that swap happens - mirrors how
/// [NexusNavScope] hands a callback down for switching tabs.
class ConnectionScope extends InheritedWidget {
  const ConnectionScope({
    super.key,
    required this.current,
    required this.onConnect,
    required this.onForget,
    required this.mode,
    required this.onChooseMode,
    required super.child,
  });

  /// The persisted connection currently in use, or null in local-demo-mode.
  final StoredConnection? current;

  /// Persists [connection] and switches the app to a live [ServerClient]
  /// pointed at it.
  final Future<void> Function(StoredConnection connection) onConnect;

  /// Clears any persisted connection and switches back to local-demo-mode.
  final Future<void> Function() onForget;

  /// How this device is currently running - null before the stored value has
  /// been read, or after it's been reset (which re-shows onboarding).
  final AppMode? mode;

  /// Switches modes and persists the choice. Settings offers this so the
  /// first-run decision isn't a one-way door.
  final Future<void> Function(AppMode mode) onChooseMode;

  static ConnectionScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ConnectionScope>();
    assert(scope != null, 'No ConnectionScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(ConnectionScope oldWidget) =>
      oldWidget.current != current || oldWidget.mode != mode;
}
