/* global NEXUS_CONFIG */
// NEXUS compound - 2D satellite map.
//
// The default map. Real aerial imagery, pan and zoom, compound buildings drawn
// on top - and crucially it needs no account and no API key, so a fresh
// install shows the actual property immediately instead of demanding a Cesium
// ion token before rendering anything.
//
// Tiles come from Esri's World Imagery service, which is free for this kind of
// use and requires no key. Attribution is drawn on the canvas because that's
// the condition of using it.
//
// Implemented directly on Canvas2D rather than pulling in Leaflet/MapLibre:
// the whole job is "draw a tile grid and some markers", the tile math is
// twenty lines, and it keeps the page dependency-free and instant to load.

(function () {
  'use strict';

  const TILE_SIZE = 256;
  const TILE_URL =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  const ATTRIBUTION = 'Imagery © Esri, Maxar, Earthstar Geographics';
  const MIN_ZOOM = 3;
  // Esri World Imagery has usable detail to ~19 in most populated areas.
  const MAX_ZOOM = 19;

  const STATUS = window.NEXUS_STATUS || {
    nominal: '#34c759',
    warn: '#ff9f0a',
    crit: '#ff3b30',
  };

  // --- Web Mercator ---------------------------------------------------------
  // Standard slippy-map projection. Exposed for tests; pure functions.

  function lonToTileX(lon, zoom) {
    return ((lon + 180) / 360) * Math.pow(2, zoom);
  }

  function latToTileY(lat, zoom) {
    const rad = (lat * Math.PI) / 180;
    return (
      ((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2) *
      Math.pow(2, zoom)
    );
  }

  function tileXToLon(x, zoom) {
    return (x / Math.pow(2, zoom)) * 360 - 180;
  }

  function tileYToLat(y, zoom) {
    const n = Math.PI - (2 * Math.PI * y) / Math.pow(2, zoom);
    return (180 / Math.PI) * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)));
  }

  // --- State ---------------------------------------------------------------
  let canvas = null;
  let ctx = null;
  let active = false;
  let zoom = 17; // Close enough to read a compound at a glance.
  let centerLat = 0;
  let centerLon = 0;
  let dragging = false;
  let dragMoved = false;
  let lastPointer = { x: 0, y: 0 };
  let tilesFailed = 0;
  let tilesTried = 0;

  /// Loaded tile images, keyed z/x/y. Values are Image, 'loading', or 'error'.
  const tiles = new Map();

  function tileKey(z, x, y) {
    return z + '/' + x + '/' + y;
  }

  function getTile(z, x, y) {
    const key = tileKey(z, x, y);
    const existing = tiles.get(key);
    if (existing) return existing === 'loading' || existing === 'error' ? null : existing;

    const image = new Image();
    // Not strictly needed (we never read pixels back) but keeps the canvas
    // untainted in case that changes.
    image.crossOrigin = 'anonymous';
    tiles.set(key, 'loading');
    tilesTried++;
    image.onload = () => {
      tiles.set(key, image);
      render();
    };
    image.onerror = () => {
      tiles.set(key, 'error');
      tilesFailed++;
      // If essentially nothing is loading, we're offline (or the service is
      // blocked) - hand off to the schematic rather than showing a void.
      if (tilesTried >= 4 && tilesFailed >= tilesTried) {
        if (window.NexusMapFallback) window.NexusMapFallback('offline');
      }
    };
    image.src = TILE_URL.replace('{z}', z).replace('{x}', x).replace('{y}', y);
    return null;
  }

  // --- Projection to screen -------------------------------------------------

  function centerPixel() {
    return {
      x: lonToTileX(centerLon, zoom) * TILE_SIZE,
      y: latToTileY(centerLat, zoom) * TILE_SIZE,
    };
  }

  function lonLatToScreen(lon, lat) {
    const c = centerPixel();
    return {
      x: lonToTileX(lon, zoom) * TILE_SIZE - c.x + canvas.width / 2 / dpr(),
      y: latToTileY(lat, zoom) * TILE_SIZE - c.y + canvas.height / 2 / dpr(),
    };
  }

  function dpr() {
    return window.devicePixelRatio || 1;
  }

  /// Compound-local normalized (0..1, y-down) -> lon/lat, matching the same
  /// anchor/span/heading the 3D map uses so both show the same layout.
  function normToLonLat(nx, ny) {
    const cfg = window.NEXUS_CONFIG;
    const span = cfg.spanMeters;
    const heading = (cfg.heading * Math.PI) / 180;
    const east = (nx - 0.5) * span;
    const north = (0.5 - ny) * span;
    const e = east * Math.cos(heading) + north * Math.sin(heading);
    const n = -east * Math.sin(heading) + north * Math.cos(heading);
    // Local metres -> degrees. Good to well under a metre at compound scale.
    const latitude = cfg.center.lat + (n / 111320);
    const longitude =
      cfg.center.lon + e / (111320 * Math.cos((cfg.center.lat * Math.PI) / 180));
    return { lon: longitude, lat: latitude };
  }

  // --- Rendering -----------------------------------------------------------

  function resize() {
    if (!canvas) return;
    const ratio = dpr();
    const rect = canvas.parentElement.getBoundingClientRect();
    // Fall back to the viewport if the container hasn't been laid out yet, or
    // if it collapsed. Trusting the parent alone is what produced a 150px-tall
    // strip when its CSS didn't match.
    const width = rect.width > 1 ? rect.width : window.innerWidth;
    const height = rect.height > 1 ? rect.height : window.innerHeight;
    canvas.width = Math.max(1, Math.floor(width * ratio));
    canvas.height = Math.max(1, Math.floor(height * ratio));
    canvas.style.width = width + 'px';
    canvas.style.height = height + 'px';
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    render();
  }

  function drawTiles() {
    const width = canvas.width / dpr();
    const height = canvas.height / dpr();
    const c = centerPixel();
    const originX = c.x - width / 2;
    const originY = c.y - height / 2;
    const count = Math.pow(2, zoom);

    const firstX = Math.floor(originX / TILE_SIZE);
    const firstY = Math.floor(originY / TILE_SIZE);
    const lastX = Math.floor((originX + width) / TILE_SIZE);
    const lastY = Math.floor((originY + height) / TILE_SIZE);

    for (let x = firstX; x <= lastX; x++) {
      for (let y = firstY; y <= lastY; y++) {
        // Wrap horizontally, clamp vertically - there are no tiles past the poles.
        if (y < 0 || y >= count) continue;
        const wrappedX = ((x % count) + count) % count;
        const image = getTile(zoom, wrappedX, y);
        const dx = Math.round(x * TILE_SIZE - originX);
        const dy = Math.round(y * TILE_SIZE - originY);
        if (image) {
          ctx.drawImage(image, dx, dy, TILE_SIZE, TILE_SIZE);
        } else {
          // Placeholder in the map's own palette, so loading reads as
          // deliberate rather than broken.
          ctx.fillStyle = '#16203a';
          ctx.fillRect(dx, dy, TILE_SIZE, TILE_SIZE);
        }
      }
    }
  }

  function drawBuildings() {
    const buildings = window.NEXUS_BUILDINGS || [];
    for (const building of buildings) {
      const { lon, lat } = normToLonLat(building.mapX, building.mapY);
      const p = lonLatToScreen(lon, lat);
      const color = STATUS[building.status] || STATUS.nominal;

      // Halo, so a marker stays legible over bright imagery.
      ctx.beginPath();
      ctx.arc(p.x, p.y, 13, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(8,12,24,0.55)';
      ctx.fill();

      ctx.beginPath();
      ctx.arc(p.x, p.y, 7, 0, Math.PI * 2);
      ctx.fillStyle = color;
      ctx.fill();
      ctx.lineWidth = 2;
      ctx.strokeStyle = 'rgba(255,255,255,0.9)';
      ctx.stroke();

      ctx.font = '600 12px -apple-system, system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.lineWidth = 3;
      ctx.strokeStyle = 'rgba(8,12,24,0.8)';
      ctx.strokeText(building.name, p.x, p.y - 18);
      ctx.fillStyle = '#ffffff';
      ctx.fillText(building.name, p.x, p.y - 18);
    }
  }

  function drawAttribution() {
    const height = canvas.height / dpr();
    const width = canvas.width / dpr();
    ctx.font = '10px -apple-system, system-ui, sans-serif';
    ctx.textAlign = 'right';
    const text = ATTRIBUTION;
    const w = ctx.measureText(text).width + 12;
    ctx.fillStyle = 'rgba(8,12,24,0.55)';
    ctx.fillRect(width - w - 4, height - 20, w, 16);
    ctx.fillStyle = 'rgba(255,255,255,0.85)';
    ctx.fillText(text, width - 10, height - 8);
  }

  let frame = null;
  function render() {
    if (!active || !ctx) return;
    if (frame) return;
    frame = requestAnimationFrame(() => {
      frame = null;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      drawTiles();
      drawBuildings();
      drawAttribution();
    });
  }

  // --- Interaction ---------------------------------------------------------

  function onPointerDown(event) {
    dragging = true;
    dragMoved = false;
    lastPointer = { x: event.clientX, y: event.clientY };
    canvas.setPointerCapture(event.pointerId);
  }

  function onPointerMove(event) {
    if (!dragging) return;
    const dx = event.clientX - lastPointer.x;
    const dy = event.clientY - lastPointer.y;
    if (Math.abs(dx) > 2 || Math.abs(dy) > 2) dragMoved = true;
    lastPointer = { x: event.clientX, y: event.clientY };

    const c = centerPixel();
    const scale = Math.pow(2, zoom) * TILE_SIZE;
    centerLon = tileXToLon((c.x - dx) / TILE_SIZE, zoom);
    // Clamp latitude short of the poles, where Mercator diverges.
    const nextY = Math.min(scale - 1, Math.max(1, c.y - dy));
    centerLat = tileYToLat(nextY / TILE_SIZE, zoom);
    render();
  }

  function onPointerUp(event) {
    if (dragging && !dragMoved) handleTap(event);
    dragging = false;
  }

  function onWheel(event) {
    event.preventDefault();
    const next = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, zoom + (event.deltaY < 0 ? 1 : -1)));
    if (next === zoom) return;
    zoom = next;
    render();
  }

  /// Tapping a building marker opens the same info panel the 3D map uses, so
  /// the two maps behave identically.
  function handleTap(event) {
    const rect = canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    const buildings = window.NEXUS_BUILDINGS || [];
    for (const building of buildings) {
      const { lon, lat } = normToLonLat(building.mapX, building.mapY);
      const p = lonLatToScreen(lon, lat);
      if (Math.hypot(p.x - x, p.y - y) <= 16) {
        const panel = window.NexusInfoPanel;
        if (panel) panel.showBuildingInfo(building);
        return;
      }
    }
    // Tapping empty imagery dismisses the panel, same as the other maps.
    const panel = window.NexusInfoPanel;
    if (panel) panel.hideInfo();
  }

  // --- Public API ----------------------------------------------------------

  window.NexusSatelliteMap = {
    activate() {
      if (active) return;
      const container = document.getElementById('satelliteMap');
      canvas = document.getElementById('satelliteCanvas');
      if (!container || !canvas) return;
      container.hidden = false;
      ctx = canvas.getContext('2d');
      active = true;

      const cfg = window.NEXUS_CONFIG;
      centerLat = cfg.center.lat;
      centerLon = cfg.center.lon;

      canvas.style.touchAction = 'none';
      canvas.addEventListener('pointerdown', onPointerDown);
      canvas.addEventListener('pointermove', onPointerMove);
      canvas.addEventListener('pointerup', onPointerUp);
      canvas.addEventListener('pointercancel', () => { dragging = false; });
      canvas.addEventListener('wheel', onWheel, { passive: false });
      window.addEventListener('resize', resize);
      resize();
      // The container was hidden a moment ago, so its box may not be final on
      // this frame. Re-measure once layout settles - cheap, and the difference
      // between a correct map and a clipped one.
      requestAnimationFrame(resize);
      // Rotating a phone or an iframe being resized by the Flutter shell can
      // land after that, so keep watching the element itself where supported.
      if (typeof ResizeObserver === 'function') {
        new ResizeObserver(resize).observe(canvas.parentElement);
      }
    },

    deactivate() {
      active = false;
      const container = document.getElementById('satelliteMap');
      if (container) container.hidden = true;
      window.removeEventListener('resize', resize);
    },

    get active() {
      return active;
    },

    // Exposed for the smoke test in tool/.
    _projection: { lonToTileX, latToTileY, tileXToLon, tileYToLat },
  };
})();
