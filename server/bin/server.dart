import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:nexus_server/auth/auth_middleware.dart';
import 'package:nexus_server/auth/pairing_token.dart';
import 'package:nexus_server/config.dart';
import 'package:nexus_server/integrations/integrations_manager.dart';
import 'package:nexus_server/media/library_index.dart';
import 'package:nexus_server/media/library_scanner.dart';
import 'package:nexus_server/state/persistence.dart';
import 'package:nexus_server/state/server_compound.dart';
import 'package:nexus_server/state/simulation_ticker.dart';
import 'package:nexus_server/transport/command_dispatcher.dart';
import 'package:nexus_server/transport/rest_api.dart';
import 'package:nexus_server/transport/websocket_hub.dart';

/// NEXUS server entry point (Section 8/9): WebSocket state sync on 8765,
/// REST on 8766, running on the Mac Studio M4 Max home server in a real
/// deployment. Run with `dart run bin/server.dart` from `server/`.
///
/// Configurable via environment variables (see `lib/config.dart`):
/// `NEXUS_BIND_ADDRESS`, `NEXUS_WS_PORT`, `NEXUS_REST_PORT`, `NEXUS_DATA_DIR`,
/// `NEXUS_MEDIA_ROOT`.
Future<void> main(List<String> args) async {
  final config = ServerConfig.fromEnvironment();

  final pairingToken = PairingToken(config.pairingTokenFile);
  if (pairingToken.isNew) {
    log('generated a new pairing token - enter this in the app to connect:', name: 'nexus.server');
    log('  ${pairingToken.value}', name: 'nexus.server');
  } else {
    log('loaded existing pairing token from ${config.pairingTokenFile.path}', name: 'nexus.server');
  }

  final persistence = CompoundPersistence(config.snapshotFile);
  final server = ServerCompound(seed: persistence.load());
  final integrations = IntegrationsManager(server);

  final library = LibraryIndex(LibraryScanner(Directory(config.mediaRoot)));
  log('scanning media library at ${config.mediaRoot}…', name: 'nexus.server');
  await library.rescan();
  server.compound.mediaStats = library.stats();
  server.compound.continueWatching = library.continueWatching(server.compound.playbackPositions);
  server.compound.photos = library.photos();
  server.compound.music = library.music();
  // Cameras come from NEXUS_CAMERAS, so the app renders what's actually
  // configured rather than a built-in list.
  server.compound.cameras = config.cameras;
  log('${config.cameras.length} camera(s) configured', name: 'nexus.server');
  log('found ${library.items.length} media item(s)', name: 'nexus.server');

  final dispatcher = CommandDispatcher(server, integrations, library);
  final wsHub = WebSocketHub(server, dispatcher, integrations.ollama, pairingToken);
  final restApi = RestApi(server, dispatcher, integrations.ollama, library, pairingToken);
  final ticker = SimulationTicker(server);

  Timer? saveTimer;
  server.onChange.listen((compound) {
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(seconds: 3), () => persistence.save(compound));
  });

  await integrations.startAll();
  wsHub.startBroadcasting();
  ticker.start();

  final bindAddress = InternetAddress(config.bindAddress);

  final wsServer = await shelf_io.serve(wsHub.handler, bindAddress, config.wsPort);
  log('WebSocket state sync listening on ws://${wsServer.address.host}:${wsServer.port}', name: 'nexus.server');

  final restHandler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(requireToken(pairingToken))
      .addHandler(restApi.handler);
  final restServer = await shelf_io.serve(restHandler, bindAddress, config.restPort);
  log('REST API listening on http://${restServer.address.host}:${restServer.port}', name: 'nexus.server');

  ProcessSignal.sigint.watch().listen((_) async {
    log('shutting down', name: 'nexus.server');
    saveTimer?.cancel();
    persistence.save(server.compound);
    ticker.stop();
    await integrations.stopAll();
    await wsServer.close(force: true);
    await restServer.close(force: true);
    server.dispose();
    exit(0);
  });
}
