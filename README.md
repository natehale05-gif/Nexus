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

## App -> server live mode

The app defaults to local-demo-mode (`CompoundStore`), but it can also run
live against a real `nexus_server` instance via `ServerClient` - both
implement the same `NexusDataSource` interface, so no screen code cares
which one is active.

To use live mode on web, append `?server=<host>:8765` to the app's URL,
e.g. `http://localhost:PORT/?server=localhost:8765` for `flutter run -d
chrome`, or `https://your-pages-url/?server=192.168.1.50:8765` for a
built/deployed copy talking to a server on your LAN or over Tailscale.

`ServerClient` mirrors whatever the server pushes over WebSocket and sends
every mutation back as a `command` message instead of applying it
locally - the server is the single source of truth. This has been
verified end-to-end: server-side REST mutations show up in the app
instantly via the WebSocket push, and app-side taps show up in the
server's state immediately, with no page reload either direction.

## Testing it live (GitHub Pages)

A GitHub Actions workflow (`.github/workflows/deploy-web.yml`) builds the
Flutter web app and publishes it to GitHub Pages on every push to `main`
(and to `cursor/**` branches, for testing before merge).

**One-time setup required** (repo admin, can't be done from a PR): in the
repo's **Settings -> Pages**, set **Build and deployment -> Source** to
**"GitHub Actions"**. After that, pushes automatically deploy, and the app
is reachable at:

```
https://<owner>.github.io/<repo>/
```

This is a real (if secondary, per the mobile-first design) build of the
app - it defaults to local-demo-mode, so it's fully interactive with no
backend required. If you have a `nexus_server` reachable from your
browser (e.g. over Tailscale), append `?server=<host>:8765` to the Pages
URL to point it at live data instead.

## Testing

```bash
cd shared && dart test    # insights engine + simulation behavior
cd server && dart test    # server-side state, command dispatch, Ollama action parsing
cd app && flutter test    # widget smoke test
cd app && flutter analyze # 0 issues
```
