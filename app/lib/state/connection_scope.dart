import 'package:flutter/widgets.dart';

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
    required super.child,
  });

  /// The persisted connection currently in use, or null in local-demo-mode.
  final StoredConnection? current;

  /// Persists [connection] and switches the app to a live [ServerClient]
  /// pointed at it.
  final Future<void> Function(StoredConnection connection) onConnect;

  /// Clears any persisted connection and switches back to local-demo-mode.
  final Future<void> Function() onForget;

  static ConnectionScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ConnectionScope>();
    assert(scope != null, 'No ConnectionScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(ConnectionScope oldWidget) => oldWidget.current != current;
}
