import 'package:flutter/widgets.dart';

import '../update/update_checker.dart';
import '../update/update_installer.dart';

/// Holds the result of the automatic update check so any screen can show it,
/// following the same ChangeNotifier + InheritedNotifier shape as the other
/// scopes rather than introducing a state-management library for one flag.
class UpdateController extends ChangeNotifier {
  UpdateController({UpdateChecker? checker})
      : _checker = checker ?? UpdateChecker();

  final UpdateChecker _checker;

  UpdateInfo? _available;
  bool _checking = false;
  bool _installing = false;
  String? _error;
  bool _dismissed = false;

  UpdateInfo? get available => _dismissed ? null : _available;
  bool get checking => _checking;
  bool get installing => _installing;
  String? get error => _error;
  String get currentVersion => _checker.currentVersion;

  /// True when this build can install an update itself, rather than only
  /// pointing at the download.
  bool get canSelfInstall => currentUpdatePlatform != UpdatePlatform.none;

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    _error = null;
    notifyListeners();
    _available = await _checker.check(platform: currentUpdatePlatform);
    _checking = false;
    notifyListeners();
  }

  /// Downloads the installer and hands it to the OS.
  Future<void> install() async {
    final update = _available;
    if (update?.assetUrl == null || _installing) return;
    _installing = true;
    _error = null;
    notifyListeners();
    try {
      await downloadAndLaunch(update!.assetUrl!, update.assetName!);
    } catch (error) {
      _error = '$error';
    } finally {
      _installing = false;
      notifyListeners();
    }
  }

  /// Hides the banner for this session without marking the version skipped -
  /// it comes back next launch, since the update is still pending.
  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _checker.dispose();
    super.dispose();
  }
}

class UpdateScope extends InheritedNotifier<UpdateController> {
  const UpdateScope({super.key, required UpdateController controller, required super.child})
      : super(notifier: controller);

  static UpdateController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UpdateScope>();
    assert(scope != null, 'No UpdateScope found in context');
    return scope!.notifier!;
  }
}
