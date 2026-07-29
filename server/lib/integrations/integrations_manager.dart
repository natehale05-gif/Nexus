import '../state/server_compound.dart';
import 'ecobee_bridge.dart';
import 'frigate_bridge.dart';
import 'gate_gpio_bridge.dart';
import 'meshtastic_bridge.dart';
import 'ollama_bridge.dart';
import 'traeger_bridge.dart';
import 'unifi_bridge.dart';
import 'wifi_bridge.dart';
import 'zigbee_bridge.dart';
import 'zwave_bridge.dart';

/// Starts every protocol bridge in the order Section 9's build order
/// prescribes (WebSocket state sync first, then each integration in the
/// order listed in Section 8, Traeger last).
class IntegrationsManager {
  IntegrationsManager(ServerCompound server)
      : wifi = WifiBridge(server),
        zigbee = ZigbeeBridge(server),
        zwave = ZWaveBridge(server),
        ecobee = EcobeeBridge(server),
        meshtastic = MeshtasticBridge(server),
        gateGpio = GateGpioBridge(server),
        ollama = OllamaBridge(server),
        frigate = FrigateBridge(server),
        unifi = UniFiBridge(server),
        traeger = TraegerBridge(server);

  final WifiBridge wifi;
  final ZigbeeBridge zigbee;
  final ZWaveBridge zwave;
  final EcobeeBridge ecobee;
  final MeshtasticBridge meshtastic;
  final GateGpioBridge gateGpio;
  final OllamaBridge ollama;
  final FrigateBridge frigate;
  final UniFiBridge unifi;
  final TraegerBridge traeger;

  Future<void> startAll() async {
    for (final bridge in [wifi, zigbee, zwave, ecobee, meshtastic, gateGpio, frigate, unifi]) {
      await bridge.start();
    }
    await ollama.start();
    await traeger.start();
  }

  Future<void> stopAll() async {
    for (final bridge in [wifi, zigbee, zwave, ecobee, meshtastic, gateGpio, ollama, frigate, unifi, traeger]) {
      await bridge.stop();
    }
  }
}
