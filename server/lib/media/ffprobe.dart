import 'dart:io';

/// Probes a media file's duration via `ffprobe` (part of the ffmpeg suite -
/// a real deployment prerequisite, see the root README). Returns `0` rather
/// than throwing if `ffprobe` is missing or the file can't be probed, so a
/// scan degrades gracefully (an item with unknown duration) instead of
/// failing entirely.
Future<double> probeDurationSeconds(String path) async {
  try {
    final result = await Process.run('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      path,
    ]);
    if (result.exitCode != 0) return 0;
    return double.tryParse(result.stdout.toString().trim()) ?? 0;
  } catch (_) {
    return 0;
  }
}
