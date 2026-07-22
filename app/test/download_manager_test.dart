import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/state/download_manager_io.dart';

/// A tiny in-process stand-in for the server's `/media/stream/<id>` route -
/// serves a fixed byte body so we can exercise the native [DownloadManager]
/// without a real `nexus_server`.
class _FakeMediaServer {
  _FakeMediaServer(this.body);

  final List<int> body;
  HttpServer? _server;

  Future<Uri> start() async {
    _server = await HttpServer.bind('127.0.0.1', 0);
    _server!.listen((request) async {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('video', 'mp4')
        ..add(body);
      await request.response.close();
    });
    return Uri.parse('http://127.0.0.1:${_server!.port}/media/stream/test');
  }

  Future<void> stop() async => _server?.close(force: true);
}

void main() {
  late Directory tempDir;
  late _FakeMediaServer server;
  late Uri source;
  final body = List<int>.generate(4096, (i) => i % 256);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nexus_dl_test');
    server = _FakeMediaServer(body);
    source = await server.start();
  });

  tearDown(() async {
    await server.stop();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('downloads a title to disk, exposes it, and deletes it', () async {
    final manager = DownloadManager(directoryOverride: tempDir);
    addTearDown(manager.dispose);
    await manager.load();

    expect(manager.isSupported, isTrue);
    expect(manager.statusFor('test'), DownloadStatus.notDownloaded);
    expect(manager.localUri('test'), isNull);

    await manager.download('test', source, title: 'Test Movie', durationSeconds: 120);

    expect(manager.statusFor('test'), DownloadStatus.downloaded);
    expect(manager.downloaded.map((d) => d.id), contains('test'));
    final uri = manager.localUri('test');
    expect(uri, isNotNull);
    final file = File.fromUri(uri!);
    expect(file.existsSync(), isTrue);
    expect(file.readAsBytesSync(), body);

    await manager.delete('test');
    expect(manager.statusFor('test'), DownloadStatus.notDownloaded);
    expect(manager.localUri('test'), isNull);
    expect(file.existsSync(), isFalse);
  });

  test('a fresh manager reloads a previously-downloaded title from the index', () async {
    final first = DownloadManager(directoryOverride: tempDir);
    await first.load();
    await first.download('test', source, title: 'Test Movie', durationSeconds: 120);
    first.dispose();

    final second = DownloadManager(directoryOverride: tempDir);
    addTearDown(second.dispose);
    await second.load();

    expect(second.statusFor('test'), DownloadStatus.downloaded);
    expect(second.localUri('test'), isNotNull);
  });
}
