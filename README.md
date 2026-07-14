# NEXUS

NEXUS is the single control surface for a 50+ acre compound near Corvallis,
OR: a map-first Flutter app talking to a companion Dart server that bridges
every local protocol (WiFi, Zigbee, Z-Wave, Meshtastic mesh, gate GPIO) plus
a handful of cloud-dependent integrations (Jellyfin, Ollama, Frigate, UniFi,
and - the one integration that's inherently cloud-gated - Traeger).

This repo is a monorepo with three packages:

```
shared/   Pure-Dart models, enums, the insights engine, the demo/simulation
          logic, and the canonical seed compound - used by both the app and
          the server so they never drift out of sync.
app/      The Flutter app (iOS/Android/macOS/web). Mobile-first, map-first
          Home tab, bottom-sheet + full-screen building views, bespoke
          stroke-icon set, no third-party UI/state-management packages.
server/   The Dart server: WebSocket state sync (8765) + REST (8766),
          protocol bridge interfaces, and the proactive insights engine
          running server-side.
```

## Running the app

```bash
cd app
flutter pub get
flutter run -d chrome   # or -d macos / a connected iOS device / etc.
```

The app boots straight into **local-demo-mode**: `CompoundStore` seeds
itself from `nexus_shared`'s `buildDemoCompound()` and runs the same
simulation tick the server uses, so every screen is fully interactive with
no server required. This matches the build order in the original spec
(Section 9, step 5: "wired to local state first, no server yet").

## Running the server

```bash
cd server
dart pub get
dart run bin/server.dart
```

This starts:
- `ws://localhost:8765` - state sync (pushes the full compound on connect
  and again on every change; accepts `command` and `chat` messages - see
  `server/lib/transport/websocket_hub.dart` for the wire protocol).
- `http://localhost:8766` - REST (`/health`, `/state`, `/command/<name>`,
  `/chat` - see `server/lib/transport/rest_api.dart`).

The server boots from the same seed compound as the app and runs the same
simulation ticker, so `curl localhost:8766/state` and the app's local demo
state look identical at boot.

### What's real vs. simulated in the server

This environment has no actual Zigbee2MQTT/Z-Wave JS UI/Frigate/UniFi/
Jellyfin instances, no Traeger account, and no physical mesh/GPIO hardware
to bridge to. Rather than faking protocol implementations that would look
real but do nothing, every bridge in `server/lib/integrations/` is a
clearly documented interface describing exactly what a real implementation
needs to do (which topics to subscribe to, which endpoints to poll, how
auth works), backed by `SimulationTicker` standing in for all of them.

The one exception is **Ollama** (`server/lib/integrations/ollama_bridge.dart`):
it's a real HTTP client against a local Ollama instance. If one happens to
be reachable, NEXUS AI chat actually goes through it, including `<action>`
tag parsing so the model can execute commands. If it isn't reachable (the
expected case without a Mac Studio nearby), it falls back to a small
rule-based responder over the same live compound context and says so.

## App -> server wiring

The app currently runs entirely off `CompoundStore` (local demo state).
Wiring it to the server's WebSocket instead is a drop-in swap: connect to
`ws://<server-host>:8765`, replace the local `_tick()`/mutation methods with
`command` messages, and replace the local `computeInsights` call with
whatever `state` messages push down - the wire format is `Compound.toJson()`
either way, so no UI code needs to change.

## Testing

```bash
cd shared && dart test    # insights engine + simulation behavior
cd server && dart test    # server-side state, command dispatch, Ollama action parsing
cd app && flutter test    # widget smoke test
cd app && flutter analyze # 0 issues
```
