/// Native implementation: a JSON file in the app documents directory.
library;

import 'dart:convert';
import 'dart:io';

import 'package:nexus_shared/nexus_shared.dart';
import 'package:path_provider/path_provider.dart';

Future<File> _file() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/nexus/compound.json');
}

Future<Compound?> loadCompound() async {
  try {
    final file = await _file();
    if (!file.existsSync()) return null;
    final raw = jsonDecode(await file.readAsString());
    return Compound.fromJson(raw as Map<String, dynamic>);
  } catch (_) {
    // A corrupt or half-written file shouldn't wedge the app on launch -
    // treat it as "nothing saved" and let onboarding run again.
    return null;
  }
}

Future<void> saveCompound(Compound compound) async {
  final file = await _file();
  file.parent.createSync(recursive: true);
  // Write-then-rename so a crash mid-write can't leave a truncated file that
  // would fail to parse on the next launch.
  final temp = File('${file.path}.part');
  await temp.writeAsString(jsonEncode(compound.toJson()), flush: true);
  await temp.rename(file.path);
}

Future<void> clearCompound() async {
  try {
    final file = await _file();
    if (file.existsSync()) await file.delete();
  } catch (_) {
    // Nothing to do - the next save overwrites it anyway.
  }
}
