import 'dart:io';

import 'package:nexus_server/config.dart';
import 'package:nexus_server/media/library_index.dart';
import 'package:nexus_server/media/library_item.dart';
import 'package:nexus_server/media/library_scanner.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('nexus_lib_test');
    Directory('${root.path}/Movies').createSync();
    Directory('${root.path}/Shows/My Show').createSync(recursive: true);
    Directory('${root.path}/Photos/Barn Raising').createSync(recursive: true);
    Directory('${root.path}/Music/Some Album').createSync(recursive: true);
    File('${root.path}/Movies/Test Movie (2020).mp4').writeAsStringSync('x');
    File('${root.path}/Shows/My Show/My Show S01E02.mp4').writeAsStringSync('x');
    File('${root.path}/Photos/Barn Raising/DSC_0001.jpg').writeAsStringSync('x');
    File('${root.path}/Photos/Barn Raising/DSC_0002.png').writeAsStringSync('x');
    File('${root.path}/Music/Some Album/Track One.mp3').writeAsStringSync('x');
    File('${root.path}/notes.txt').writeAsStringSync('ignored');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('classifies movies, episodes, photos and music; ignores other files', () async {
    final index = LibraryIndex(LibraryScanner(root));
    await index.rescan();

    final kinds = index.items.map((i) => i.kind).toList();
    expect(kinds.where((k) => k == LibraryItemKind.movie).length, 1);
    expect(kinds.where((k) => k == LibraryItemKind.episode).length, 1);
    expect(kinds.where((k) => k == LibraryItemKind.photo).length, 2);
    expect(kinds.where((k) => k == LibraryItemKind.music).length, 1);
    // notes.txt is not a media file.
    expect(index.items.length, 5);
  });

  test('stats and projections split by kind', () async {
    final index = LibraryIndex(LibraryScanner(root));
    await index.rescan();

    final stats = index.stats();
    expect(stats.movieCount, 1);
    expect(stats.episodeCount, 1);
    expect(stats.showCount, 1);
    expect(stats.photoCount, 2);
    expect(stats.trackCount, 1);

    expect(index.photos().length, 2);
    expect(index.music().length, 1);
    // A photo's folder becomes its subtitle.
    expect(index.photos().first.subtitle, 'Barn Raising');
    // Continue Watching only offers watchable video.
    expect(index.continueWatching(const {}).length, 2);
  });

  group('NEXUS_CAMERAS parsing', () {
    test('reads Name=url pairs, trims, and derives stable ids', () {
      final cameras = ServerConfig.parseCameras(
        'Front Door=http://go2rtc:1984/api/stream.m3u8?src=front, Barn North =http://x/b.m3u8',
      );
      expect(cameras.length, 2);
      expect(cameras.first.name, 'Front Door');
      expect(cameras.first.id, 'cam_front_door');
      expect(cameras.first.streamUrl, 'http://go2rtc:1984/api/stream.m3u8?src=front');
      expect(cameras.first.isStreamable, isTrue);
      expect(cameras.last.name, 'Barn North');
      expect(cameras.last.id, 'cam_barn_north');
    });

    test('a bare name registers a camera with no stream', () {
      final cameras = ServerConfig.parseCameras('Shop Bay');
      expect(cameras.single.name, 'Shop Bay');
      expect(cameras.single.streamUrl, isNull);
      expect(cameras.single.isStreamable, isFalse);
    });

    test('empty/unset yields no cameras', () {
      expect(ServerConfig.parseCameras(null), isEmpty);
      expect(ServerConfig.parseCameras('   '), isEmpty);
      expect(ServerConfig.parseCameras(',,'), isEmpty);
    });
  });
}
