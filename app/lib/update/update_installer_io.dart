/// Native: fetch the installer for this OS and hand it to the system.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

UpdatePlatform get currentUpdatePlatform {
  if (Platform.isWindows) return UpdatePlatform.windows;
  if (Platform.isMacOS) return UpdatePlatform.macos;
  if (Platform.isLinux) return UpdatePlatform.linux;
  // iOS/Android update through their app stores, not from GitHub Releases.
  return UpdatePlatform.none;
}

/// Downloads [url] and opens it with whatever the OS uses to install it.
///
/// This intentionally stops at "launch the installer" rather than swapping
/// files underneath the running app: on Windows a running .exe can't be
/// overwritten, and silently replacing an unsigned binary is exactly the
/// behavior SmartScreen and Smart App Control exist to stop. Handing the
/// signed-by-nobody installer to the user keeps them in the loop, which is
/// also what makes the prompt legible when SAC blocks it.
Future<void> downloadAndLaunch(String url, String fileName) async {
  final dir = await getApplicationSupportDirectory();
  final target = File('${dir.path}/updates/$fileName');
  target.parent.createSync(recursive: true);

  final client = HttpClient();
  try {
    // Release assets redirect to a CDN host, so follow redirects explicitly.
    final request = await client.getUrl(Uri.parse(url));
    request.followRedirects = true;
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('Update download failed (${response.statusCode})', uri: Uri.parse(url));
    }
    // Write to .part and rename, so an interrupted download can't leave a
    // truncated installer that looks complete and fails halfway through.
    final part = File('${target.path}.part');
    await response.pipe(part.openWrite());
    if (target.existsSync()) target.deleteSync();
    await part.rename(target.path);
  } finally {
    client.close();
  }

  await _open(target.path);
}

Future<void> _open(String path) async {
  if (Platform.isWindows) {
    // Inno Setup installs over the existing per-user install; it prompts to
    // close the running app itself.
    await Process.start(path, const [], mode: ProcessStartMode.detached);
  } else if (Platform.isMacOS) {
    // Mounts the .dmg and shows the drag-to-Applications window.
    await Process.start('open', [path], mode: ProcessStartMode.detached);
  } else if (Platform.isLinux) {
    // xdg-open hands the .deb to whatever package installer is present;
    // fall back to revealing it if there's no handler.
    try {
      await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
    } on ProcessException {
      throw const FileSystemException(
        'Downloaded, but no handler is installed to open it. '
        'Install it with: sudo apt install',
      );
    }
  }
}
