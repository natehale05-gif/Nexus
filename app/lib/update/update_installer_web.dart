/// Web: the newest build is whatever the server serves, so there's nothing
/// to download or run. Reloading picks it up.
library;

import 'update_checker.dart';

UpdatePlatform get currentUpdatePlatform => UpdatePlatform.none;

Future<void> downloadAndLaunch(String url, String fileName) async {}
