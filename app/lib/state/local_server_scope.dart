import 'package:flutter/widgets.dart';

import '../server/local_server.dart';

/// Drives the bundled `nexus_server` from the UI, in the same
/// ChangeNotifier + InheritedNotifier shape as the other scopes.
class LocalServerController extends ChangeNotifier {
  bool _busy = false;
  String? _error;
  LocalServerHandle? _handle;

  bool get busy => _busy;
  String? get error => _error;
  LocalServerHandle? get handle => _handle;
  bool get running => localServerRunning;

  /// False in a dev checkout or on web - the Settings section hides itself
  /// rather than offering a button that can only fail.
  bool get available => localServerSupported && localServerPath != null;
  bool get supported => localServerSupported;

  String? get log => localServerLog;

  Future<LocalServerHandle?> start({String? mediaRoot}) async {
    if (_busy) return null;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _handle = await startLocalServer(mediaRoot: mediaRoot);
      return _handle;
    } catch (error) {
      _error = '$error';
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await stopLocalServer();
      _handle = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Don't outlive the app - a stale server would hold the port and make the
    // next launch's start fail for no visible reason.
    stopLocalServer();
    super.dispose();
  }
}

class LocalServerScope extends InheritedNotifier<LocalServerController> {
  const LocalServerScope({
    super.key,
    required LocalServerController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocalServerController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocalServerScope>();
    assert(scope != null, 'No LocalServerScope found in context');
    return scope!.notifier!;
  }
}
