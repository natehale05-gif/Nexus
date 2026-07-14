import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:nexus_shared/nexus_shared.dart';

import '../state/server_compound.dart';
import 'integration.dart';

/// Ollama bridge (Section 8) - powers the NEXUS AI tab.
///
/// Unlike the other bridges in this folder, this one is a real, working
/// HTTP client against a local Ollama instance (`llama3.1:70b` or
/// whatever model is configured) - if one happens to be reachable at
/// [host] in this environment, chat requests actually go through it. If
/// it isn't reachable (the expected case here, since there's no Mac
/// Studio in this sandbox), [generateReply] falls back to a small
/// rule-based responder over the same live [buildSystemContext] data
/// rather than failing outright, and says so.
///
/// `<action>` tag execution: the model is instructed (via the system
/// prompt) to emit self-closing `<action name="..." .../>` tags to
/// actually change compound state instead of only describing changes -
/// see [executeActionTags]. Supported action names mirror
/// [ServerCompound]'s mutators: `turnOffAllLights`, `setLocked`,
/// `toggleLight`, `setBrightness`, `setGrillOn`, `setMediaOn`.
class OllamaBridge extends Integration {
  OllamaBridge(
    super.server, {
    this.host = 'http://localhost:11434',
    this.model = 'llama3.1:70b',
    HttpClient? httpClient,
  }) : _client = httpClient ?? HttpClient();

  final String host;
  final String model;
  final HttpClient _client;

  @override
  String get name => 'ollama';

  @override
  Future<void> start() async {
    log('[$name] configured for $host ($model) - falls back to local heuristics if unreachable', name: 'nexus.ollama');
  }

  @override
  Future<void> stop() async {
    _client.close(force: true);
  }

  Future<String> generateReply(String userMessage) async {
    final systemPrompt = buildSystemContext(server.compound);
    try {
      final uri = Uri.parse('$host/api/generate');
      final request = await _client.postUrl(uri).timeout(const Duration(seconds: 2));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'model': model,
        'system': systemPrompt,
        'prompt': userMessage,
        'stream': false,
      }));
      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('Ollama returned ${response.statusCode}: $body');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final raw = decoded['response'] as String? ?? '';
      final executed = executeActionTags(raw, server);
      final visible = stripActionTags(raw).trim();
      if (executed.isEmpty) return visible;
      return '$visible\n\n(${executed.join('; ')})'.trim();
    } catch (error) {
      log('[$name] unreachable, falling back to local heuristics: $error', name: 'nexus.ollama');
      return _fallbackReply(userMessage);
    }
  }

  String _fallbackReply(String userMessage) {
    final text = userMessage.toLowerCase();
    final compound = server.compound;

    if (text.contains('turn off all lights')) {
      final onCount = compound.devices.whereType<LightDevice>().where((l) => l.on).length;
      server.turnOffAllLights();
      return onCount == 0 ? 'All lights were already off.' : 'Turned off $onCount light(s) across the compound.';
    }
    if (text.contains('any alerts')) {
      final active = compound.alerts.where((a) => a.level != Level.info).toList();
      return active.isEmpty
          ? 'No active alerts.'
          : active.map((a) => '${a.level.name}: ${a.message}').join('; ');
    }

    final lightsOn = compound.devices.whereType<LightDevice>().where((l) => l.on).length;
    return "Ollama isn't reachable at $host right now, so I'm answering from local state only: "
        '$lightsOn light(s) on across the compound.';
  }
}

/// Regex-based, minimal `<action name="..." attr="val" .../>` parser.
/// Kept intentionally simple (no XML dependency) since the model is
/// instructed to only ever emit this exact self-closing shape.
final _actionTagPattern = RegExp(r'<action\s+([^/>]+?)\s*/>');
final _attrPattern = RegExp(r'(\w+)="([^"]*)"');

List<String> executeActionTags(String modelOutput, ServerCompound server) {
  final executed = <String>[];
  for (final match in _actionTagPattern.allMatches(modelOutput)) {
    final attrs = <String, String>{};
    for (final attrMatch in _attrPattern.allMatches(match.group(1)!)) {
      attrs[attrMatch.group(1)!] = attrMatch.group(2)!;
    }
    final action = attrs['name'];
    if (action == null) continue;
    switch (action) {
      case 'turnOffAllLights':
        server.turnOffAllLights();
        executed.add('turned off all lights');
      case 'toggleLight':
        if (attrs['id'] != null) {
          server.toggleLight(attrs['id']!);
          executed.add('toggled ${attrs['id']}');
        }
      case 'setBrightness':
        if (attrs['id'] != null && attrs['value'] != null) {
          server.setBrightness(attrs['id']!, num.tryParse(attrs['value']!) ?? 100);
          executed.add('set brightness on ${attrs['id']}');
        }
      case 'setLocked':
        if (attrs['id'] != null && attrs['value'] != null) {
          server.setLocked(attrs['id']!, attrs['value'] == 'true');
          executed.add('set lock ${attrs['id']} to ${attrs['value']}');
        }
      case 'setGrillOn':
        if (attrs['id'] != null && attrs['value'] != null) {
          server.setGrillOn(attrs['id']!, attrs['value'] == 'true');
          executed.add('set grill ${attrs['id']} to ${attrs['value']}');
        }
      case 'setMediaOn':
        if (attrs['id'] != null && attrs['value'] != null) {
          server.setMediaOn(attrs['id']!, attrs['value'] == 'true');
          executed.add('set media ${attrs['id']} to ${attrs['value']}');
        }
    }
  }
  return executed;
}

String stripActionTags(String modelOutput) => modelOutput.replaceAll(_actionTagPattern, '').trim();

/// Section 5: "System prompt context must include, live, on every
/// request: building names, which lights are on, which locks are open,
/// grill status per grill..., current media playback, mesh node health
/// summary, weather, vehicle locations, and any active proactive
/// insights."
String buildSystemContext(Compound compound) {
  final buildings = compound.buildings.map((b) => b.name).join(', ');
  final lightsOn = compound.devices.whereType<LightDevice>().where((l) => l.on).map((l) => l.name).toList();
  final openLocks = compound.devices.whereType<LockDevice>().where((l) => !l.locked).map((l) => l.name).toList();
  final grills = compound.devices.whereType<GrillDevice>().map((g) {
    final probe = g.probe != null ? ', probe ${g.probe!.round()}/${g.probeTarget?.round()}' : '';
    return '${g.name}: ${g.on ? "on ${g.temp.round()}/${g.set.round()}$probe pellets ${g.pellets}%" : "off"}'
        '${g.cloudOnline ? "" : " (cloud unreachable)"}';
  }).join('; ');
  final media = compound.nowPlaying == null
      ? 'nothing playing'
      : '${compound.nowPlaying!.title} (${compound.nowPlaying!.isPlaying ? "playing" : "paused"})';
  final meshSummary =
      compound.meshNodes.map((m) => '${m.name}: ${m.online ? "online ${m.batteryPercent}%" : "OFFLINE"}').join('; ');
  final vehicles = compound.vehicles.map((v) => '${v.name}: ${v.locationDescription}').join('; ');
  final insights = compound.insights.map((i) => '[${i.level.name}] ${i.message}').join('; ');
  final weather = compound.weather;

  return '''
You are NEXUS, the AI assistant for a private compound. Answer concisely.
To actually change device state, emit a self-closing tag like
<action name="turnOffAllLights"/> or <action name="setLocked" id="lk_barn" value="false"/>
Supported action names: turnOffAllLights, toggleLight, setBrightness, setLocked, setGrillOn, setMediaOn.

Buildings: $buildings
Lights on: ${lightsOn.isEmpty ? 'none' : lightsOn.join(', ')}
Open locks/gates: ${openLocks.isEmpty ? 'none' : openLocks.join(', ')}
Grills: ${grills.isEmpty ? 'none' : grills}
Media: $media
Mesh health: $meshSummary
Weather: ${weather == null ? 'unknown' : '${weather.tempF.round()}F, ${weather.condition}'}
Vehicles: $vehicles
Active insights: ${insights.isEmpty ? 'none' : insights}
''';
}
