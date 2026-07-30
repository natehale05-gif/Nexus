/* global window, document, requestAnimationFrame, cancelAnimationFrame, performance */
// NEXUS compound - offline fallback map.
//
// A self-contained Canvas2D top-down schematic of the compound, drawn
// straight from the same NEXUS_BUILDINGS/NEXUS_VEHICLES/NEXUS_STATUS data
// (data.js) the CesiumJS view uses - no network access required at all, so
// this keeps working when Photorealistic 3D Tiles can't load (offline, or
// Cesium ion/Google's tileset is unreachable). This page is also served
// completely standalone outside the Flutter app, so this fallback can't lean
// on the Flutter shell's own 2D map - it has to be self-sufficient here.
//
// Deliberately a legibility fallback, not a precision map: rotation
// (NEXUS_CONFIG.heading) is ignored and the patrolling vehicle is linearly
// interpolated along its route rather than eased like the 3D view.
(function () {
  'use strict';

  const cfg = window.NEXUS_CONFIG;
  const STATUS = window.NEXUS_STATUS;
  const VEHICLE_COLOR = '#6ee7f7';

  const container = document.getElementById('offlineMap');
  const canvas = document.getElementById('offlineCanvas');
  const badge = document.getElementById('offlineBadge');
  const ctx = canvas ? canvas.getContext('2d') : null;

  let active = false;
  let rafId = null;
  let startTime = 0;
  let layout = { scale: 0, offsetX: 0, offsetY: 0 };
  let hitList = [];

  function resize() {
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(1, Math.round(rect.width * dpr));
    canvas.height = Math.max(1, Math.round(rect.height * dpr));
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    const pad = 40;
    const size = Math.max(40, Math.min(rect.width, rect.height) - pad * 2);
    layout = {
      scale: size,
      offsetX: (rect.width - size) / 2,
      offsetY: (rect.height - size) / 2,
      width: rect.width,
      height: rect.height,
    };
  }

  function toPx(x, y) {
    return { px: layout.offsetX + x * layout.scale, py: layout.offsetY + y * layout.scale };
  }

  function metersToPx(meters) {
    return (meters / cfg.spanMeters) * layout.scale;
  }

  // Position of a vehicle at `elapsed` seconds - linear interpolation along
  // `route` waypoints on a loop, or a fixed point for parked vehicles.
  function vehiclePosition(v, elapsed) {
    if (!v.route || v.route.length < 2) return { x: v.mapX, y: v.mapY };
    const route = v.route;
    const n = route.length;
    const loop = v.loopSeconds || 120;
    const t = elapsed % loop;
    const segLen = loop / (n - 1);
    const idx = Math.min(n - 2, Math.floor(t / segLen));
    const frac = (t - idx * segLen) / segLen;
    const [x1, y1] = route[idx];
    const [x2, y2] = route[idx + 1];
    return { x: x1 + (x2 - x1) * frac, y: y1 + (y2 - y1) * frac };
  }

  function drawLabel(text, px, py) {
    ctx.font = '600 12px -apple-system, Segoe UI, Roboto, sans-serif';
    ctx.textAlign = 'center';
    ctx.lineWidth = 3;
    ctx.strokeStyle = 'rgba(11,15,30,0.85)';
    ctx.strokeText(text, px, py);
    ctx.fillStyle = '#f4f6fb';
    ctx.fillText(text, px, py);
  }

  function drawBackground() {
    ctx.fillStyle = '#12172a';
    ctx.fillRect(0, 0, layout.width, layout.height);
    ctx.strokeStyle = 'rgba(110,231,247,0.06)';
    ctx.lineWidth = 1;
    const step = 32;
    for (let x = 0; x < layout.width; x += step) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, layout.height);
      ctx.stroke();
    }
    for (let y = 0; y < layout.height; y += step) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(layout.width, y);
      ctx.stroke();
    }
  }

  function roundRect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function render() {
    if (!active) return;
    const elapsed = (performance.now() - startTime) / 1000;
    hitList = [];

    drawBackground();

    for (const b of window.NEXUS_BUILDINGS) {
      const { px, py } = toPx(b.mapX, b.mapY);
      const w = Math.max(18, metersToPx(b.footprint[0]));
      const h = Math.max(18, metersToPx(b.footprint[1]));
      const x = px - w / 2;
      const y = py - h / 2;
      const color = STATUS[b.status] || STATUS.nominal;

      roundRect(x, y, w, h, Math.min(6, w / 4, h / 4));
      ctx.fillStyle = color;
      ctx.globalAlpha = 0.85;
      ctx.fill();
      ctx.globalAlpha = 1;
      ctx.lineWidth = 1.5;
      ctx.strokeStyle = 'rgba(0,0,0,0.35)';
      ctx.stroke();

      drawLabel(b.name, px, y - 8);

      hitList.push({ kind: 'building', data: b, shape: { type: 'rect', x, y, w, h } });
    }

    for (const v of window.NEXUS_VEHICLES) {
      const pos = vehiclePosition(v, elapsed);
      const { px, py } = toPx(pos.x, pos.y);
      const r = 8;

      ctx.beginPath();
      ctx.arc(px, py, r, 0, Math.PI * 2);
      ctx.fillStyle = VEHICLE_COLOR;
      ctx.fill();
      ctx.lineWidth = 1.5;
      ctx.strokeStyle = 'rgba(11,15,30,0.8)';
      ctx.stroke();

      drawLabel(v.name, px, py - r - 8);

      hitList.push({ kind: 'vehicle', data: v, shape: { type: 'circle', x: px, y: py, r: r + 4 } });
    }

    rafId = requestAnimationFrame(render);
  }

  function hitTest(x, y) {
    for (let i = hitList.length - 1; i >= 0; i--) {
      const { shape } = hitList[i];
      if (shape.type === 'rect') {
        if (x >= shape.x && x <= shape.x + shape.w && y >= shape.y && y <= shape.y + shape.h) {
          return hitList[i];
        }
      } else if (shape.type === 'circle') {
        const dx = x - shape.x;
        const dy = y - shape.y;
        if (dx * dx + dy * dy <= shape.r * shape.r) return hitList[i];
      }
    }
    return null;
  }

  if (canvas) {
    canvas.addEventListener('click', (e) => {
      if (!active) return;
      const hit = hitTest(e.offsetX, e.offsetY);
      const panel = window.NexusInfoPanel;
      if (!panel) return;
      if (hit && hit.kind === 'building') panel.showBuildingInfo(hit.data);
      else if (hit && hit.kind === 'vehicle') panel.showVehicleInfo(hit.data);
      else panel.hideInfo();
    });
  }

  window.addEventListener('resize', () => {
    if (active) resize();
  });

  window.NexusOfflineMap = {
    get active() {
      return active;
    },
    activate() {
      if (active || !canvas) return;
      active = true;
      startTime = performance.now();
      if (container) container.hidden = false;
      if (badge) badge.hidden = false;
      resize();
      rafId = requestAnimationFrame(render);
    },
    deactivate() {
      if (!active) return;
      active = false;
      if (container) container.hidden = true;
      if (badge) badge.hidden = true;
      if (rafId) cancelAnimationFrame(rafId);
      rafId = null;
    },
  };
})();
