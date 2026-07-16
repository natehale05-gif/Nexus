import 'dart:convert';
import 'dart:io';

import 'package:nexus_shared/nexus_shared.dart';

/// Loads/saves a [Compound] snapshot to disk so server state survives a
/// restart. Writes atomically (temp file + rename) so a crash mid-write
/// can't corrupt the snapshot. The snapshot is a small namespaced JSON
/// object (`{"compound": {...}}`) so later work (media playback progress,
/// integration secrets) can add sibling sections without a second
/// persistence mechanism.
class CompoundPersistence {
  CompoundPersistence(this.file);

  final File file;

  Compound? load() {
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final compoundJson = decoded['compound'] as Map<String, dynamic>?;
      if (compoundJson == null) return null;
      return Compound.fromJson(compoundJson);
    } catch (_) {
      // Corrupt or incompatible snapshot - fall back to the demo seed
      // rather than crashing the server on boot.
      return null;
    }
  }

  void save(Compound compound) {
    file.parent.createSync(recursive: true);
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(jsonEncode({'compound': compound.toJson()}));
    tmp.renameSync(file.path);
  }
}
