# NEXUS

NEXUS is the single control surface for a 50+ acre compound near Corvallis,
OR: a map-first Flutter app talking to a companion Dart server that bridges
every local protocol (WiFi, Zigbee, Z-Wave, Meshtastic mesh, gate GPIO),
**replaces Jellyfin/Plex outright** with its own media library scanner +
streamer (not a bridge to an external Jellyfin instance), and adds a handful
of other integrations (Ollama, Frigate, UniFi, and - the one that's
inherently cloud-gated - Traeger).

## Download

[![Download for Windows](https://img.shields.io/badge/Install-Windows-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/natehale05-gif/Nexus/releases/latest/download/NEXUS-windows-x64-setup.exe)
[![Download for macOS](https://img.shields.io/badge/Install-macOS-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/natehale05-gif/Nexus/releases/latest/download/NEXUS-macos.dmg)
[![Download for Linux](https://img.shields.io/badge/Install-Linux-F5A623?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/natehale05-gif/Nexus/releases/latest/download/NEXUS-linux-x64.deb)

These are **installers**, not folders of loose files:

| | Asset | What it does |
|---|---|---|
| Windows | `NEXUS-windows-x64-setup.exe` | Installs NEXUS, adds a Start Menu entry (and optionally a desktop shortcut), and registers an uninstaller in Add/Remove Programs. No admin rights needed. |
| macOS | `NEXUS-macos.dmg` | Opens the familiar drag-**NEXUS**-to-**Applications** window. |
| Linux | `NEXUS-linux-x64.deb` | `apt install`s to `/opt/nexus`, puts `nexus` on your PATH, and adds an icon + launcher entry to the applications menu. apt pulls the GTK/mpv/libsecret runtime libraries for you. |

Not on a Debian-based distro? [`NEXUS-linux-x64.tar.gz`](https://github.com/natehale05-gif/Nexus/releases/latest/download/NEXUS-linux-x64.tar.gz)
is a portable build you can extract and run anywhere.

Those three buttons always serve the newest published release - they're built
by [`.github/workflows/release.yml`](.github/workflows/release.yml) and
attached to the [latest GitHub Release](https://github.com/natehale05-gif/Nexus/releases/latest).
No Flutter, no Visual Studio, no Xcode needed on the machine you're
installing onto. See [Installing a download](#installing-a-download) for the
per-OS unsigned-app warnings you'll hit - in particular, Windows 11's **Smart
App Control** blocks unsigned installers with no "run anyway" option.

Prefer nothing to install? The web build runs in any browser - see
[Testing it live (GitHub Pages)](#testing-it-live-github-pages). It's the
same app, minus the two things a browser can't do: **offline downloads** and
**on-device AI**.

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
flutter run -d chrome   # or -d macos / -d windows / a connected iOS device
```

### Installing a download

None of the installers are code-signed - that needs a paid Apple Developer ID
and a Windows code-signing certificate this project doesn't have. So Windows
and macOS will warn you the first time. On macOS, and for Windows
SmartScreen, you can wave the warning through. **Windows 11's Smart App
Control is the exception - it has no override at all**; see below.

**Windows** - run `NEXUS-windows-x64-setup.exe`. It installs per-user under
`%LOCALAPPDATA%\Programs\NEXUS`, so there's no UAC prompt and you don't need
an admin account. Uninstall from **Settings → Apps** like anything else.

Windows 11 has *two* different gates, and they behave differently:

- **SmartScreen** - "Windows protected your PC". Click **More info** →
  **Run anyway**. This one has an override.
- **Smart App Control** - "Smart App Control blocked an app that may be
  unsafe". This one **has no override**. There is no "run anyway" button, and
  no amount of clicking will get past it, because SAC only permits apps
  signed by a certificate that already carries reputation with Microsoft.

If you hit Smart App Control, your options are:

1. **Use the web app instead** - open the GitHub Pages URL and install it as
   a PWA (Edge: ⋯ → Apps → Install this site as an app). Nothing to sign,
   nothing blocked. You give up offline downloads and on-device AI.
2. **Turn Smart App Control off** - Windows Security → **App & browser
   control** → **Smart App Control settings** → **Off**. Understand the
   trade before you do it: **this is one-way.** Microsoft does not let you
   switch SAC back on afterwards without reinstalling Windows, and it's a
   system-wide protection, not a per-app exception. Don't disable it just for
   this app unless you're comfortable with that permanently.
3. **Sign the installer** - the actual fix, and the only one that keeps SAC
   on. See [Code signing](#code-signing) below.

Building the app yourself on that machine also sidesteps it, since locally
compiled binaries never pick up the internet Mark-of-the-Web that triggers
the check - but that means installing Flutter and Visual Studio, which is
most of what these installers exist to avoid.

**macOS** - open `NEXUS-macos.dmg` and drag **NEXUS** onto **Applications**.
The first launch, Gatekeeper will refuse an unsigned app, so right-click
NEXUS in Applications → **Open** → **Open** (this is only needed once). If it
still refuses, clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/NEXUS.app
```

**Linux** - install the `.deb`; apt resolves the GTK/mpv/libsecret runtime
libraries as part of the install:

```bash
sudo apt install ./NEXUS-linux-x64.deb
```

Then launch **NEXUS** from your applications menu, or run `nexus` in a
terminal. Remove it with `sudo apt remove nexus`.

The `.deb` targets the current Ubuntu LTS. On a non-Debian distro use the
`.tar.gz` instead - extract it and run `./NEXUS/nexus`, with `libgtk-3`,
`libmpv`, `libsecret` and `libepoxy` installed from your own package manager.

### Updates

The desktop apps check GitHub Releases on launch and offer the new version in
**Settings → Version**. On Windows, macOS and Linux, *Download and install*
fetches the right asset for the platform and hands it to the OS - the Inno
Setup installer, the `.dmg`, or the `.deb`. The web build has nothing to
download; reloading always serves the newest deploy.

The check is deliberately conservative:

- It **stops at launching the installer** rather than swapping files under the
  running app. A running `.exe` can't be overwritten on Windows, and silently
  replacing an unsigned binary is the exact behavior SmartScreen and Smart App
  Control exist to stop - so you stay in the loop, and the prompt makes sense
  when SAC blocks it.
- A failed check is **silent**. Offline, rate-limited, or a malformed
  response all mean "no update this time", never an error dialog.
- Local builds (`flutter run`) report version `0.0.0-dev` and never check, so
  a working copy doesn't nag. CI stamps the real version in from the release
  tag via `--dart-define=NEXUS_VERSION`.

Because the installers are unsigned, **each update re-triggers the same
first-run warnings** as the original install. Signing fixes that too.

### Code signing

Nothing in this repo is signed, which is why Windows and macOS both push
back. If NEXUS is going on machines you'd rather not weaken, signing is worth
the money:

- **Windows** - [Azure Trusted Signing](https://learn.microsoft.com/azure/trusted-signing/)
  is the cheap route (roughly $10/month for an individual, subject to an
  identity check) and it satisfies both SmartScreen and Smart App Control. A
  traditional OV certificate is cheaper up front but builds SmartScreen
  reputation slowly and may still trip SAC; an EV certificate works
  immediately but runs several hundred dollars a year. A self-signed
  certificate does **not** help - SAC doesn't care that a signature exists,
  it cares whose it is.
- **macOS** - an Apple Developer ID ($99/year) plus notarization removes the
  Gatekeeper prompt entirely.

`release.yml` doesn't sign anything today. Wiring it up is a contained change
once a certificate exists: add the signing step after the build and feed the
credentials in as repository secrets.

There's also a **PWA** route on Windows and desktop Chrome/Edge: open the
GitHub Pages URL and use the address-bar **Install** button (Edge: ⋯ → Apps →
Install this site as an app). It gets its own window and the NEXUS icon - but
it's still the web build, so no offline downloads and no on-device AI.

## First run

The first launch asks what this device is for, and remembers the answer:

- **Connect to my server** - pair with a `nexus_server` (see
  [Remote access with Tailscale](#remote-access-with-tailscale)). The server
  owns the compound, media library and cameras, and every paired device stays
  in sync.
- **Start a compound here** - begin empty and build your own: add buildings,
  rooms and devices from the **Buildings** tab. Saved on the device (a JSON
  file in app documents on desktop/mobile, `localStorage` on web) so it
  survives restarts. You can pair a server later.
- **Look around the demo** - the seeded example compound from
  `buildDemoCompound()`, running the same simulation tick the server uses.
  Nothing in it is real; it exists to show what the app does.

Change it any time in **Settings → Mode**. Switching to *This device* keeps
whatever you've already built; the demo is regenerated fresh each launch and
never overwrites your compound.

### Building out your compound

In **Buildings**, with a local compound:

- **+ Building** at the end of the building strip, or the button on the empty
  state for the first one.
- Per building: **Add a room**, **Add a lock or gate** (locks attach to the
  building, not a room), **Rename**, **Delete**.
- Per room: **Add device** (light, climate, media, grill) and **Delete room**.

Deleting a building removes its rooms and devices too - the confirmation says
how many, since devices reference buildings by id and orphans would show up as
ghost entries elsewhere. These controls are hidden when paired with a server:
the server owns that state, so a local structural edit would be overwritten by
its next push.

## The 3D compound map (CesiumJS)

On the **web** build, the Home tab's map is a real 3D scene rendered with
[CesiumJS](https://cesium.com/platform/cesiumjs/), living in
[`app/web/cesium/`](app/web/cesium/):

- **Google Photorealistic 3D Tiles** (real-world buildings + terrain) as the
  only base layer - there's no alternate terrain/imagery mode to switch to.

> **The globe needs your own Cesium ion token.** ion authorizes tile requests
> per account, so no token can be committed here that works for everyone.
> Create one at [ion.cesium.com/tokens](https://ion.cesium.com/tokens) with
> the default scopes (it must include `assets:read`), confirm *Google
> Photorealistic 3D Tiles* is in that account's assets, then paste it into
> **Settings → 3D map** and reload. Without it the map shows the offline
> schematic and says exactly which of those steps is missing - it no longer
> fails silently. `?ionToken=...` on the map URL also works for a quick test.
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
| `NEXUS_MEDIA_ROOT` | `$NEXUS_DATA_DIR/media` | Folder the media library scanner walks for movies/TV/photos/music |
| `NEXUS_CAMERAS` | _(none)_ | Security cameras, `Name=streamUrl` comma-separated (see **Security cameras**) |

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

`server/lib/media/` scans `NEXUS_MEDIA_ROOT` recursively and classifies
every file it recognizes by extension:

| Kind | Extensions | Where it shows up |
|---|---|---|
| Movies / TV | `.mp4 .mkv .mov .m4v .avi .webm` | Now Playing + Continue Watching |
| Photos | `.jpg .jpeg .png .gif .webp .heic .bmp` | Media tab → **Photos** grid (tap for full screen) |
| Music | `.mp3 .m4a .flac .wav .aac .ogg .opus` | Media tab → **Music** list (plays as audio) |

Titles/years/episode numbers are derived from file and folder names (no
metadata service like TMDB - results are heuristic, not perfect); a photo
or track's parent folder becomes its subtitle, so `Photos/Barn Raising/
DSC_0001.jpg` reads as "DSC 0001 · Barn Raising". Everything is served with
real HTTP range-request support at `GET /media/stream/<id>` so seeking
works in the app's player.

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

**Offline downloads (native devices only).** On the native app builds
(iOS/Android/macOS/Windows/Linux) each device can save a title for offline
viewing: the download button on a Media-tab tile fetches the file to the
app's own storage (`app/lib/state/download_manager_io.dart`), and it then
plays from disk with no server or internet - it appears in a **Downloaded**
section on the Media tab and can be removed there. Downloads are
per-device local state, not synced through the server. This is inherently a
native-device capability, so **the web / GitHub Pages build does not offer
it** (a browser has no app-managed storage for large video to play back
offline) - the download affordances simply don't appear there, while online
streaming still works. To try offline downloads, run a native build (a
phone, or `flutter run -d macos`), download a title, then stop the server
or go offline and confirm it still plays.

### Security cameras

Cameras are declared server-side via `NEXUS_CAMERAS` as a comma-separated
list of `Name=streamUrl` pairs, and pushed to every client as part of the
compound - so the Security tab renders what you actually have rather than a
built-in list:

```bash
NEXUS_CAMERAS="Front Door=http://go2rtc.local:1984/api/stream.m3u8?src=front,Barn North=...,Shop Bay"
```

Tapping a camera with a stream URL plays it inline. A bare name (no `=`)
registers the camera but marks it **NO STREAM**, and says so when tapped,
rather than dead-ending on a tile that looks live.

**Use HLS (`.m3u8`) URLs.** NEXUS doesn't speak RTSP itself - put
[go2rtc](https://github.com/AlexxIT/go2rtc) (or similar) in front of your
RTSP/UniFi Protect cameras and point `NEXUS_CAMERAS` at its HLS endpoints.
That keeps the streaming concern in a tool built for it instead of
reimplementing RTSP in the app.

## Buildings tab (compound control)

Each building on the compound gets a tab (a pill in the horizontal selector,
with a status dot so problems are visible without switching). Selecting one
shows that building's summary (rooms, device count, mesh health), its
building-level **Locks & Gates**, then every **room as a room-widget card**
containing each device in that room - lights, climate, grills, media, and
room-scoped locks. Rooms with no devices still appear, so nothing is
silently missing.

The Home map remains the spatial view (where things are); Buildings is the
working view (operating a building room by room).

## Multi-provider AI (NEXUS tab)

The NEXUS AI tab routes chat through a pluggable provider abstraction
(`app/lib/ai/`) so each device can pick its own backend, streamed token by
token. `AiProvider.generate()` yields incremental text uniformly across four
implementations:

- **On-device** (`local`) - runs entirely on this device with no network,
  backed today by NEXUS's built-in house-aware rule-based responder (a real
  offline option). The same interface is designed to later host a neural
  on-device model (llama.cpp / MLX) with no call-site changes.
- **Mac Studio** (`mac_studio`) - a remote Ollama instance over a user-set
  base URL (`http://<host>:11434`), reached over Tailscale. Streams Ollama's
  NDJSON chat API.
- **Anthropic** - `api.anthropic.com/v1/messages`, SSE streaming.
- **OpenAI** - `api.openai.com/v1/chat/completions`, SSE streaming.

Pick the provider/model per device under **Settings → AI Model**; API keys
are stored with `flutter_secure_storage` (Keychain/Keystore/encrypted -
never plain prefs), and the choice persists per device. Every provider gets
the live compound context (buildings, lights, locks, grill, media, alerts…)
as a system prompt, and `<action>` tags in replies execute device commands -
so switching providers keeps the assistant house-aware and able to control
things. Errors are surfaced per-backend (auth / timeout / unreachable /
rate-limited) so it's obvious which one failed.

**Web/Pages caveat:** browsers block direct calls to Anthropic/OpenAI (CORS,
and shipping API keys into a browser is unsafe) and can't run on-device
inference, so multi-provider AI is primarily a **native-app** feature; the
existing server-routed Ollama path still answers on web. Provider request/
response parsing and error mapping are unit-tested against fake streams
(`app/test/ai_providers_test.dart`); live calls need real keys on a device.

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

CI pins **Flutter 3.44.8** ([`deploy-web.yml`](.github/workflows/deploy-web.yml),
[`release.yml`](.github/workflows/release.yml)). That floor is not arbitrary:
GitHub's `windows-latest` is now the `windows-2025-vs2026` image, and only
Flutter 3.44+ knows to ask CMake for the *Visual Studio 18 2026* generator -
older versions fall back to *Visual Studio 16 2019* and fail to configure.

## Cutting a release

`release.yml` builds all three desktop targets on every push, but it only
publishes a GitHub Release for a version tag:

```bash
git tag v0.2.0
git push origin v0.2.0
```

That builds Windows/macOS/Linux, attaches `NEXUS-windows-x64-setup.exe`,
`NEXUS-macos.dmg`, `NEXUS-linux-x64.deb` and `NEXUS-linux-x64.tar.gz` to a
Release named after the tag, and - because the README's buttons point at
`releases/latest/download/` - repoints all three download buttons at the new
build with no README edit. You can also run the workflow by hand from the
Actions tab and pass the tag as an input.
