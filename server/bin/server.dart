import 'dart:developer';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:nexus_server/integrations/integrations_manager.dart';
import 'package:nexus_server/state/server_compound.dart';
import 'package:nexus_server/state/simulation_ticker.dart';
import 'package:nexus_server/transport/command_dispatcher.dart';
import 'package:nexus_server/transport/rest_api.dart';
import 'package:nexus_server/transport/websocket_hub.dart';

/// NEXUS server entry point (Section 8/9): WebSocket state sync on 8765,
/// REST on 8766, running on the Mac Studio M4 Max home server in a real
/// deployment. Run with `dart run bin/server.dart` from `server/`.
Future<void> main(List<String> args) async {
  final server = ServerCompound();
  final integrations = IntegrationsManager(server);
  final dispatcher = CommandDispatcher(server, integrations);
  final wsHub = WebSocketHub(server, dispatcher, integrations.ollama);
  final restApi = RestApi(server, dispatcher, integrations.ollama);
  final ticker = SimulationTicker(server);

  await integrations.startAll();
  wsHub.startBroadcasting();
  ticker.start();

  final wsServer = await shelf_io.serve(wsHub.handler, InternetAddress.anyIPv4, 8765);
  log('WebSocket state sync listening on ws://${wsServer.address.host}:${wsServer.port}', name: 'nexus.server');

  final restHandler = const Pipeline().addMiddleware(logRequests()).addHandler(restApi.handler);
  final restServer = await shelf_io.serve(restHandler, InternetAddress.anyIPv4, 8766);
  log('REST API listening on http://${restServer.address.host}:${restServer.port}', name: 'nexus.server');

  ProcessSignal.sigint.watch().listen((_) async {
    log('shutting down', name: 'nexus.server');
    ticker.stop();
    await integrations.stopAll();
    await wsServer.close(force: true);
    await restServer.close(force: true);
    server.dispose();
    exit(0);
  });
}
