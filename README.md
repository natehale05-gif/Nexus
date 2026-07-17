# NEXUS

NEXUS is the single control surface for a 50+ acre compound near Corvallis,
OR: a map-first Flutter app talking to a companion Dart server that bridges
every local protocol (WiFi, Zigbee, Z-Wave, Meshtastic mesh, gate GPIO),
**replaces Jellyfin/Plex outright** with its own media library scanner +
streamer (not a bridge to an external Jellyfin instance), and adds a handful
of other integrations (Ollama, Frigate, UniFi, and - the one that's
inherently cloud-gated - Traeger).

This repo is a monorepo with three packages:

```
shared/   Pure-Dart models, enums, the insights engine, the demo/simulation
          logic, and the canonical seed compound - used by both the app and
          the server so they never drift out of sync.
app/      The Flutter app (iOS/Android/macOS/web). Mobile-first, map-first
          Home tab, bottom-sheet + full-screen building views, bespoke
          stroke-icon set, no third-party UI/state-management packages. On the
          web build the Home map is a live CesiumJS 3D scene (web/cesium/),
          embedded as a platform view.
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

## The 3D compound map (CesiumJS)

On the **web** build, the Home tab's map is a real 3D scene rendered with
[CesiumJS](https://cesium.com/platform/cesiumjs/), living in
[`app/web/cesium/`](app/web/cesium/):

- **Google Photorealistic 3D Tiles** (real-world buildings + terrain) as the
  only base layer - there's no alternate terrain/imagery mode to switch to.
- **Colored 3D compound buildings** - the Main House, Barn, Shop, Cabin, and
  Gates are extruded footprints colored by status (green = nominal, amber =
  attention, red = critical), with floating labels.
- **3D vehicles** - the F-250 is a glTF model patrolling the perimeter road,
  and the Model Y sits parked in the driveway. Tap any building or vehicle for
  a themed status panel.

The buildings/vehicles are laid out from the same normalized map coordinates
the Flutter app uses, projected onto real ground at a configurable anchor.

**Offline fallback.** Photorealistic 3D Tiles need a live connection to
Cesium ion/Google - if it can't load (no internet, or the tileset is
otherwise unreachable) or the browser goes offline mid-session, the page
automatically switches to a self-contained, dependency-free 2D schematic of
the compound (`app/web/cesium/offline_map.js`, drawn straight from the same
building/vehicle data with no network calls of its own), with an "OFFLINE"
badge shown next to the brand chip. Building/vehicle taps still open the same
info panel. When connectivity returns, the page reloads back into the normal
3D view.

**Configuring the location.** Edit `center` (and optionally `spanMeters` /
`heading`) at the top of [`app/web/cesium/data.js`](app/web/cesium/data.js),
or override per-visit with URL query params, e.g.
`.../cesium/?lat=44.59&lon=-123.24&span=380`. The default anchor is flat
Willamette Valley farmland just east of Corvallis, OR.

**Cesium ion token.** The map authenticates to Cesium ion (for the
Photorealistic 3D Tiles + terrain) with the public client token in
`data.js` (`NEXUS_CONFIG.ionToken`). It's a browser-side access token, so
it's fine to commit; swap in your own from
[cesium.com/ion/tokens](https://cesium.com/ion/tokens) if you prefer.

The map is a self-contained static bundle (Cesium loads from a CDN), so you
can also open it **standalone** without the Flutter shell - handy for quick
iteration - at `.../cesium/` (see the GitHub Pages section below).

## Running the server

```bash
cd server
dart pub get
dart run bin/server.dart
```

This starts (bound to all interfaces by default, so it's reachable at
`localhost` locally or the machine's LAN/Tailscale address remotely):
- `ws://<host>:8765` - state sync (pushes the full compound on connect
  and again on every change; accepts `command` and `chat` messages - see
  `server/lib/transport/websocket_hub.dart` for the wire protocol).
- `http://<host>:8766` - REST (`/health`, `/state`, `/command/<name>`,
  `/chat` - see `server/lib/transport/rest_api.dart`).

The server boots from the same seed compound as the app and runs the same
simulation ticker, so `curl localhost:8766/state` and the app's local demo
state look identical at boot.

**Configuration.** All of the following are optional environment variables
(see `server/lib/config.dart`); the defaults match a plain local run:

| Variable | Default | Purpose |
|---|---|---|
| `NEXUS_BIND_ADDRESS` | `0.0.0.0` | Interface to bind both servers to |
| `NEXUS_WS_PORT` | `8765` | WebSocket state-sync port |
| `NEXUS_REST_PORT` | `8766` | REST API port |
| `NEXUS_DATA_DIR` | `~/.nexus` | Where the pairing token and state snapshot live |
| `NEXUS_MEDIA_ROOT` | `$NEXUS_DATA_DIR/media` | Folder the media library scanner walks for movies/TV |

**State persistence.** The server snapshots its compound state to
`$NEXUS_DATA_DIR/state.json` a few seconds after every change (and once
more on a clean shutdown), and loads it back on the next boot - restarting
the server no longer resets every device to the demo seed.

**Pairing token (auth).** On first boot, the server generates a random
pairing token and writes it to `$NEXUS_DATA_DIR/pairing_token`, printing it
once to the console:

```
generated a new pairing token - enter this in the app to connect:
  <token>
```

Every device has to present this token to connect (as a `Bearer` header on
REST, or as the first WebSocket message) - see
`server/lib/auth/pairing_token.dart`. It's a single shared secret for the
household, not per-user login; delete the token file and restart the
server to rotate it (this immediately disconnects every paired device
until they're re-entered in Settings).

### What's real vs. simulated in the server

This environment has no actual Zigbee2MQTT/Z-Wave JS UI/Frigate/UniFi
instances, no Traeger account, and no physical mesh/GPIO hardware to bridge
to. Rather than faking protocol implementations that would look real but do
nothing, every bridge in `server/lib/integrations/` other than the two
below is a clearly documented interface describing exactly what a real
implementation needs to do (which topics to subscribe to, which endpoints
to poll, how auth works), backed by `SimulationTicker` standing in for all
of them.

Two exceptions are real:

- **Ollama** (`server/lib/integrations/ollama_bridge.dart`) - a real HTTP
  client against a local Ollama instance. If one happens to be reachable,
  NEXUS AI chat actually goes through it, including `<action>` tag parsing
  so the model can execute commands. If it isn't reachable (the expected
  case without a Mac Studio nearby), it falls back to a small rule-based
  responder over the same live compound context and says so.
- **Media** (`server/lib/media/`) - a real filesystem library scanner and
  HTTP range-request streaming server for movies/TV, replacing Jellyfin
  outright rather than bridging to one. See **Media library** below.

### Media library (replacing Jellyfin)

`server/lib/media/` scans `NEXUS_MEDIA_ROOT` for `.mp4`/`.mkv`/`.mov`/`.m4v`/
`.avi`/`.webm` files (recursively), derives titles/years/episode numbers
from file and folder names (no metadata service like TMDB - results are
heuristic, not perfect), and serves them with real HTTP range-request
support at `GET /media/stream/<id>` so seeking works in the app's player.

**Requires `ffprobe`** (part of [ffmpeg](https://ffmpeg.org)) on the host to
read file durations - install it and make sure it's on `PATH` before
starting the server. If it's missing, the library still scans, just with
unknown durations for every item, rather than failing outright.

**Direct-play only** - there's no transcoding, so a file's codec/container
needs to be something the viewing device/browser can decode natively
(H.264/AAC in an `.mp4` is the safest bet). This is a deliberate, named
scope limit, not a bug.

Playback position is tracked per item and persists across restarts/rescans
(`Compound.playbackPositions`, part of the regular state snapshot). The
Settings tab shows the scanned library's item counts and has a **Rescan
Library** button (run it after adding/removing files - the library isn't
watched automatically).

## App -> server live mode

The app defaults to local-demo-mode (`CompoundStore`), but it can also run
live against a real `nexus_server` instance via `ServerClient` - both
implement the same `NexusDataSource` interface, so no screen code cares
which one is active.

**Settings tab (recommended, all platforms).** Open the section menu ->
**Settings**, enter the server's address and the pairing token printed in
its startup log, and tap **Connect**. This is persisted on-device (secure
storage), so the app reconnects automatically on every future launch -
no relaunching, no URL to retype. **Forget This Server** clears it and
drops back to local-demo-mode.

**`?server=` query param (web, quick testing only).** Append
`?server=<host>&token=<token>` to the app's URL, e.g.
`http://localhost:PORT/?server=localhost:8765&token=<token>` for `flutter
run -d chrome`. This always overrides a persisted Settings connection,
which makes it handy for one-off testing against a different server
without touching the paired connection.

Either path accepts a bare host (`192.168.1.50`, defaults to `ws://`) or a
Tailscale MagicDNS name (`myhouse.tailnet-name.ts.net`, defaults to
`wss://` - see **Remote access with Tailscale** below for why). Either way,
if no port is given it defaults to `8765` (the WebSocket port); the app
derives the REST/streaming base URL from that automatically as "one port
higher" (`8766`), so there's only ever one address to configure - just keep
that same pairing if you customize the ports via `NEXUS_WS_PORT`/
`NEXUS_REST_PORT`. An explicit `ws://`/`wss://` scheme, or an explicit port,
always wins over the default.

`ServerClient` mirrors whatever the server pushes over WebSocket and sends
every mutation back as a `command` message instead of applying it
locally - the server is the single source of truth. This has been
verified end-to-end: server-side REST mutations show up in the app
instantly via the WebSocket push, and app-side taps show up in the
server's state immediately, with no page reload either direction.

## Remote access with Tailscale

To reach your `nexus_server` from any device, anywhere - not just on the
home LAN - install [Tailscale](https://tailscale.com) on the server
machine and on every device running the app, then front the server with
`tailscale serve` so it gets a real HTTPS/WSS address via your tailnet's
MagicDNS name and auto-provisioned cert:

```bash
tailscale serve --bg --https=8765 8765  # WebSocket state sync
tailscale serve --bg --https=8766 8766  # REST + media streaming
```

(matching ports on both sides keeps the app's "REST is the WebSocket port
+1" derivation - see **App -> server live mode** above - working unchanged
whether you're on the LAN or going through Tailscale.) Then use that
MagicDNS name (e.g. `myhouse.tailnet-name.ts.net`) as the server address in
the app's Settings tab. This matters for more than convenience: a browser
will flatly refuse to open a plain `ws://` connection from an `https://`
page (the GitHub Pages build is always served over HTTPS), so reaching the
server from the Pages build - or any `https://` deployment - requires a
real `wss://` front door like this one, not a raw LAN IP.

No public ports need to be opened on your router for this - Tailscale's
own encrypted mesh handles reachability, and only devices in your tailnet
can resolve or reach the MagicDNS name.

## Testing it live (GitHub Pages)

A GitHub Actions workflow (`.github/workflows/deploy-web.yml`) builds the
Flutter web app and publishes it to GitHub Pages on every push to `main`
(and to `cursor/**` / `claude/**` branches, for testing before merge).

**One-time setup required** (repo admin, can't be done from a PR): in the
repo's **Settings -> Pages**, set **Build and deployment -> Source** to
**"GitHub Actions"**. After that, pushes automatically deploy, and the app
is reachable at:

```
https://<owner>.github.io/<repo>/
```

This is a real (if secondary, per the mobile-first design) build of the
app - it defaults to local-demo-mode, so it's fully interactive with no
backend required. The Home tab shows the CesiumJS 3D compound map described
above; the Media tab shows simulated demo titles with no real video. To
point it at a real server instead - for real device control, real media
playback, and everything else backed by `server/lib/` - use the in-app
**Settings** tab (persists across visits) or append
`?server=<host>&token=<token>` to the Pages URL for a one-off test - either
way, since this page is served over HTTPS, the server needs a
`wss://`-capable front door (see **Remote access with Tailscale** above)
rather than a raw LAN `ws://` address. GitHub Pages itself never runs any
server-side code - it's purely the client half of this, always talking to
a `nexus_server` you run somewhere real.

The 3D map is also served **standalone** (outside the Flutter shell) at:

```
https://<owner>.github.io/<repo>/cesium/
```

which is the quickest way to test the Cesium view on its own - it loads the
Photorealistic 3D Tiles, colored buildings, and 3D vehicles directly.

## Testing

```bash
cd shared && dart test    # insights engine + simulation behavior
cd server && dart test    # server-side state, command dispatch, Ollama action parsing
cd app && flutter test    # widget smoke test
cd app && flutter analyze # 0 issues
```
