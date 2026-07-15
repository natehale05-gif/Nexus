/* global Cesium */
// NEXUS compound - CesiumJS 3D map.
//
// Renders Google Photorealistic 3D Tiles (buildings + terrain) as the base,
// drops colored extruded "compound" buildings on the real ground, and adds
// 3D vehicles (glTF models with a stylized-box fallback), including one that
// patrols the perimeter road. Clicking a building or vehicle opens a themed
// info panel. A toggle swaps between Photorealistic tiles and Cesium World
// Terrain + OSM Buildings.

(function () {
  'use strict';

  const cfg = window.NEXUS_CONFIG;
  const STATUS = window.NEXUS_STATUS;

  const els = {
    loading: document.getElementById('loading'),
    loadingMsg: document.getElementById('loadingMsg'),
    toast: document.getElementById('toast'),
    info: document.getElementById('info'),
    infoTitle: document.getElementById('infoTitle'),
    infoZone: document.getElementById('infoZone'),
    infoStatus: document.getElementById('infoStatus'),
    infoBody: document.getElementById('infoBody'),
    infoMeta: document.getElementById('infoMeta'),
    infoClose: document.getElementById('infoClose'),
    btnLayer: document.getElementById('btnLayer'),
    btnLabels: document.getElementById('btnLabels'),
    btnReset: document.getElementById('btnReset'),
  };

  function setLoading(msg) {
    if (els.loadingMsg) els.loadingMsg.textContent = msg;
  }
  function hideLoading() {
    els.loading && els.loading.classList.add('hide');
  }
  function showToast(html) {
    if (!els.toast) return;
    els.toast.innerHTML = html;
    els.toast.classList.add('show');
  }

  // --- Local (compound) -> world helpers -----------------------------------
  let enuFrame = null; // Matrix4 east-north-up at compound center
  function initFrame() {
    const center = Cesium.Cartesian3.fromDegrees(cfg.center.lon, cfg.center.lat);
    enuFrame = Cesium.Transforms.eastNorthUpToFixedFrame(center);
  }
  const headingRad = Cesium.Math.toRadians(cfg.heading);

  // Normalized map (x right, y down) -> east/north meters, then rotated.
  function normToLocal(x, y) {
    const east = (x - 0.5) * cfg.spanMeters;
    const north = (0.5 - y) * cfg.spanMeters;
    const e = east * Math.cos(headingRad) + north * Math.sin(headingRad);
    const n = -east * Math.sin(headingRad) + north * Math.cos(headingRad);
    return { e, n };
  }
  // Local east/north (already rotated) -> Cartographic (height 0).
  function localToCarto(e, n) {
    const local = new Cesium.Cartesian3(e, n, 0);
    const world = Cesium.Matrix4.multiplyByPoint(
      enuFrame,
      local,
      new Cesium.Cartesian3()
    );
    return Cesium.Cartographic.fromCartesian(world);
  }
  function normToCarto(x, y) {
    const { e, n } = normToLocal(x, y);
    return localToCarto(e, n);
  }

  // --- Ground height sampling (photoreal tiles first, terrain fallback) -----
  async function sampleGround(viewer, cartos) {
    const scene = viewer.scene;
    try {
      if (scene.sampleHeightSupported && scene.globe && !scene.globe.show) {
        await scene.sampleHeightMostDetailed(cartos);
      }
    } catch (e) {
      /* fall through to terrain */
    }
    const missing = cartos.filter(
      (c) => c.height === undefined || Number.isNaN(c.height)
    );
    if (missing.length) {
      try {
        await Cesium.sampleTerrainMostDetailed(viewer.terrainProvider, missing);
      } catch (e) {
        /* ignore */
      }
    }
    cartos.forEach((c) => {
      if (c.height === undefined || Number.isNaN(c.height)) c.height = 0;
    });
    return cartos;
  }

  // --- Building footprint ---------------------------------------------------
  // Returns the 4 corner cartographics (height 0) for a building footprint.
  function buildingCorners(b) {
    const { e, n } = normToLocal(b.mapX, b.mapY);
    const hw = b.footprint[0] / 2;
    const hd = b.footprint[1] / 2;
    const r = Cesium.Math.toRadians(b.rotate || 0);
    const cos = Math.cos(r);
    const sin = Math.sin(r);
    const offs = [
      [-hw, -hd],
      [hw, -hd],
      [hw, hd],
      [-hw, hd],
    ];
    return offs.map(([dx, dy]) => {
      const le = e + dx * cos - dy * sin;
      const ln = n + dx * sin + dy * cos;
      return localToCarto(le, ln);
    });
  }

  function statusColor(status) {
    return Cesium.Color.fromCssColorString(STATUS[status] || STATUS.nominal);
  }
  const STATUS_LABEL = { nominal: 'Nominal', warn: 'Attention', crit: 'Critical' };

  // --- Boot -----------------------------------------------------------------
  async function boot() {
    // When embedded inside the Flutter app shell (an <iframe>), the app
    // provides its own brand + section menu chrome, so we tuck the map's own
    // overlays out of the way (see the `.embedded` rules in styles.css).
    if (window.self !== window.top) {
      document.body.classList.add('embedded');
    }
    if (!cfg.ionToken || cfg.ionToken.indexOf('REPLACE') !== -1) {
      showToast('<b>Missing Cesium ion token.</b><br/>Set NEXUS_CONFIG.ionToken in data.js.');
      hideLoading();
      return;
    }
    Cesium.Ion.defaultAccessToken = cfg.ionToken;

    setLoading('Loading world terrain\u2026');
    let viewer;
    try {
      viewer = new Cesium.Viewer('cesiumContainer', {
        terrain: Cesium.Terrain.fromWorldTerrain(),
        animation: false,
        timeline: false,
        baseLayerPicker: false,
        geocoder: false,
        homeButton: false,
        sceneModePicker: false,
        navigationHelpButton: false,
        fullscreenButton: false,
        selectionIndicator: false,
        infoBox: false,
      });
    } catch (e) {
      showToast('<b>Failed to start CesiumJS.</b><br/>' + (e && e.message));
      hideLoading();
      return;
    }

    const scene = viewer.scene;
    scene.globe.depthTestAgainstTerrain = true;
    scene.skyAtmosphere.show = true;
    scene.fog.enabled = true;
    scene.highDynamicRange = true;
    viewer.clock.shouldAnimate = true;
    // Hide Cesium's default double-click "track entity" behavior.
    viewer.screenSpaceEventHandler.removeInputAction(
      Cesium.ScreenSpaceEventType.LEFT_DOUBLE_CLICK
    );

    initFrame();
    // Exposed for quick debugging / automated smoke tests.
    window.__nexusViewer = viewer;

    // Photorealistic 3D Tiles (Google, via Cesium ion). Falls back gracefully.
    setLoading('Loading Photorealistic 3D Tiles\u2026');
    let photoreal = null;
    try {
      photoreal = await Cesium.createGooglePhotorealistic3DTileset();
      scene.primitives.add(photoreal);
      // Photoreal mesh includes terrain; hide the globe to avoid z-fighting.
      scene.globe.show = false;
    } catch (e) {
      console.warn('Photorealistic 3D Tiles unavailable, using terrain.', e);
      photoreal = null;
      scene.globe.show = true;
    }

    // OSM Buildings for the "terrain" base layer (created lazily on toggle).
    let osmBuildings = null;
    let usingPhotoreal = !!photoreal;

    setLoading('Placing compound\u2026');

    // Sample ground for every building corner + vehicle anchor at once.
    const buildingCornerMap = new Map();
    const allCartos = [];
    for (const b of window.NEXUS_BUILDINGS) {
      const corners = buildingCorners(b);
      buildingCornerMap.set(b.id, corners);
      allCartos.push(...corners);
    }
    const vehicleAnchors = [];
    for (const v of window.NEXUS_VEHICLES) {
      const pts = v.route ? v.route : [[v.mapX, v.mapY]];
      for (const [x, y] of pts) {
        const c = normToCarto(x, y);
        vehicleAnchors.push(c);
        allCartos.push(c);
      }
    }
    await sampleGround(viewer, allCartos);

    // Bounding sphere over the whole compound, used to frame the camera.
    compoundSphere = Cesium.BoundingSphere.fromPoints(
      allCartos.map((c) =>
        Cesium.Cartesian3.fromRadians(c.longitude, c.latitude, c.height || 0)
      )
    );

    // Build the colored compound buildings.
    buildBuildings(viewer, buildingCornerMap);

    // Build vehicles (models with box fallback).
    await buildVehicles(viewer);

    // Wire up interaction, controls, camera.
    wireInteraction(viewer);
    wireControls(viewer, {
      getPhotoreal: () => photoreal,
      getUsingPhotoreal: () => usingPhotoreal,
      setUsingPhotoreal: (v) => (usingPhotoreal = v),
      ensureOsm: async () => {
        if (!osmBuildings) {
          try {
            osmBuildings = await Cesium.createOsmBuildingsAsync();
            scene.primitives.add(osmBuildings);
          } catch (e) {
            console.warn('OSM Buildings unavailable', e);
          }
        }
        return osmBuildings;
      },
      scene,
    });

    flyToCompound(viewer);
    hideLoading();
    if (!photoreal) {
      showToast(
        '<b>Photorealistic 3D Tiles did not load.</b><br/>Falling back to Cesium World Terrain + OSM Buildings. Check the ion token / quota, then reload.'
      );
      setTimeout(() => els.toast && els.toast.classList.remove('show'), 6000);
    }
  }

  // --- Buildings ------------------------------------------------------------
  const buildingLabels = [];
  function buildBuildings(viewer, cornerMap) {
    for (const b of window.NEXUS_BUILDINGS) {
      const corners = cornerMap.get(b.id);
      const heights = corners.map((c) => c.height);
      // Anchor at the lowest corner with a small skirt so the building stays
      // grounded (no floating) on flat or gently sloped terrain, and extrude a
      // compact `height` upward so it never turns into a tower on a slope.
      const groundLow = Math.min(...heights);
      const bottom = groundLow - 2;
      const top = groundLow + b.height;
      const color = statusColor(b.status);

      const positions = corners.map((c) =>
        Cesium.Cartesian3.fromRadians(c.longitude, c.latitude, 0)
      );

      viewer.entities.add({
        name: b.name,
        polygon: {
          hierarchy: positions,
          perPositionHeight: false,
          height: bottom,
          extrudedHeight: top,
          material: color.withAlpha(0.92),
          outline: true,
          outlineColor: Cesium.Color.BLACK.withAlpha(0.35),
        },
        properties: { kind: 'building', data: b },
      });

      // Glowing roof cap so buildings read from a distance.
      viewer.entities.add({
        polygon: {
          hierarchy: positions,
          perPositionHeight: false,
          height: top,
          extrudedHeight: top + 0.4,
          material: color.brighten(0.5, new Cesium.Color()),
        },
        properties: { kind: 'building', data: b },
      });

      // Floating label above the building.
      const center = centerOfCorners(corners);
      const label = viewer.entities.add({
        position: Cesium.Cartesian3.fromRadians(
          center.longitude,
          center.latitude,
          top + 8
        ),
        label: {
          text: b.name,
          font: '600 14px -apple-system, Segoe UI, Roboto, sans-serif',
          fillColor: Cesium.Color.WHITE,
          outlineColor: Cesium.Color.fromCssColorString('#0b0f1e'),
          outlineWidth: 4,
          style: Cesium.LabelStyle.FILL_AND_OUTLINE,
          verticalOrigin: Cesium.VerticalOrigin.BOTTOM,
          pixelOffset: new Cesium.Cartesian2(0, -6),
          disableDepthTestDistance: Number.POSITIVE_INFINITY,
          scaleByDistance: new Cesium.NearFarScalar(200, 1.0, 2500, 0.5),
          translucencyByDistance: new Cesium.NearFarScalar(1500, 1.0, 4000, 0.0),
        },
        point: {
          pixelSize: 7,
          color: color,
          outlineColor: Cesium.Color.WHITE.withAlpha(0.85),
          outlineWidth: 1.5,
          disableDepthTestDistance: Number.POSITIVE_INFINITY,
          scaleByDistance: new Cesium.NearFarScalar(200, 1.0, 3000, 0.4),
        },
        properties: { kind: 'building', data: b },
      });
      buildingLabels.push(label);
    }
  }

  function centerOfCorners(corners) {
    let lon = 0,
      lat = 0,
      h = 0;
    for (const c of corners) {
      lon += c.longitude;
      lat += c.latitude;
      h += c.height;
    }
    const n = corners.length;
    return {
      longitude: lon / n,
      latitude: lat / n,
      height: h / n,
    };
  }

  // --- Vehicles -------------------------------------------------------------
  async function modelReachable(url) {
    // raw.githubusercontent.com rejects CORS HEAD requests, so probe with a
    // tiny ranged GET instead (200 or 206 both mean the asset is fetchable).
    try {
      const res = await fetch(url, {
        method: 'GET',
        mode: 'cors',
        headers: { Range: 'bytes=0-0' },
      });
      return res.ok || res.status === 206;
    } catch (e) {
      return false;
    }
  }

  async function buildVehicles(viewer) {
    // Preflight the glTF models; fall back to boxes if unreachable.
    const reach = {};
    await Promise.all(
      Object.entries(cfg.models).map(async ([k, url]) => {
        reach[k] = await modelReachable(url);
      })
    );

    for (const v of window.NEXUS_VEHICLES) {
      if (v.route) {
        addMovingVehicle(viewer, v, reach);
      } else {
        addParkedVehicle(viewer, v, reach);
      }
    }
  }

  function vehicleGraphics(v, reach) {
    const useModel = reach[v.type] && cfg.models[v.type];
    if (useModel) {
      return {
        model: {
          uri: cfg.models[v.type],
          minimumPixelSize: 64,
          maximumScale: 120,
          scale: 1.0, // CesiumMilkTruck is authored roughly life-size
        },
      };
    }
    // Stylized 3D box fallback (body).
    const col =
      v.type === 'truck'
        ? Cesium.Color.fromCssColorString('#3a4a6b')
        : Cesium.Color.fromCssColorString('#c9d3e8');
    const dim =
      v.type === 'truck'
        ? new Cesium.Cartesian3(6.0, 2.3, 2.4)
        : new Cesium.Cartesian3(4.7, 2.0, 1.6);
    return {
      box: {
        dimensions: dim,
        material: col,
        outline: true,
        outlineColor: Cesium.Color.BLACK.withAlpha(0.5),
      },
    };
  }

  function addParkedVehicle(viewer, v, reach) {
    const carto = normToCarto(v.mapX, v.mapY);
    // carto.height was filled by sampleGround (it is one of allCartos).
    const usingModel = reach[v.type];
    const z = carto.height + (usingModel ? 0 : 1.2);
    const position = Cesium.Cartesian3.fromRadians(
      carto.longitude,
      carto.latitude,
      z
    );
    const hpr = new Cesium.HeadingPitchRoll(
      Cesium.Math.toRadians((v.heading || 0) + cfg.heading),
      0,
      0
    );
    const orientation = Cesium.Transforms.headingPitchRollQuaternion(
      position,
      hpr
    );
    const g = vehicleGraphics(v, reach);
    viewer.entities.add(
      Object.assign(
        {
          name: v.name,
          position: position,
          orientation: orientation,
          properties: { kind: 'vehicle', data: v },
        },
        g
      )
    );
    addVehicleTag(viewer, v, position);
  }

  function addMovingVehicle(viewer, v, reach) {
    const start = Cesium.JulianDate.now();
    const loop = v.loopSeconds || 120;
    const stop = Cesium.JulianDate.addSeconds(
      start,
      loop,
      new Cesium.JulianDate()
    );

    const sampled = new Cesium.SampledPositionProperty();
    const usingModel = reach[v.type];
    const n = v.route.length;
    for (let i = 0; i < n; i++) {
      const [x, y] = v.route[i];
      const carto = normToCarto(x, y);
      // Re-sample not needed: route points were included in allCartos, but
      // build our own copy here to be safe about height.
      const t = Cesium.JulianDate.addSeconds(
        start,
        (loop * i) / (n - 1),
        new Cesium.JulianDate()
      );
      const pos = Cesium.Cartesian3.fromRadians(
        carto.longitude,
        carto.latitude,
        (carto.height || 0) + (usingModel ? 0.2 : 1.2)
      );
      sampled.addSample(t, pos);
    }
    sampled.setInterpolationOptions({
      interpolationDegree: 2,
      interpolationAlgorithm: Cesium.HermitePolynomialApproximation,
    });

    viewer.clock.startTime = start.clone();
    viewer.clock.currentTime = start.clone();
    viewer.clock.stopTime = stop.clone();
    viewer.clock.clockRange = Cesium.ClockRange.LOOP_STOP;
    viewer.clock.multiplier = 1;
    viewer.clock.shouldAnimate = true;

    const g = vehicleGraphics(v, reach);
    viewer.entities.add(
      Object.assign(
        {
          name: v.name,
          position: sampled,
          orientation: new Cesium.VelocityOrientationProperty(sampled),
          properties: { kind: 'vehicle', data: v },
        },
        g
      )
    );

    // Moving status tag rides along above the vehicle.
    viewer.entities.add({
      position: sampled,
      label: vehicleLabelGraphics(v.name + '  \u2192'),
      properties: { kind: 'vehicle', data: v },
    });
  }

  function vehicleLabelGraphics(text) {
    return {
      text: text,
      font: '600 12px -apple-system, Segoe UI, Roboto, sans-serif',
      fillColor: Cesium.Color.fromCssColorString('#6ee7f7'),
      outlineColor: Cesium.Color.fromCssColorString('#0b0f1e'),
      outlineWidth: 4,
      style: Cesium.LabelStyle.FILL_AND_OUTLINE,
      verticalOrigin: Cesium.VerticalOrigin.BOTTOM,
      pixelOffset: new Cesium.Cartesian2(0, -22),
      disableDepthTestDistance: Number.POSITIVE_INFINITY,
      scaleByDistance: new Cesium.NearFarScalar(200, 1.0, 3000, 0.5),
    };
  }

  function addVehicleTag(viewer, v, position) {
    viewer.entities.add({
      position: position,
      label: vehicleLabelGraphics(v.name),
      properties: { kind: 'vehicle', data: v },
    });
  }

  // --- Interaction ----------------------------------------------------------
  function wireInteraction(viewer) {
    const handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas);
    handler.setInputAction((movement) => {
      const picked = viewer.scene.pick(movement.position);
      if (Cesium.defined(picked) && picked.id && picked.id.properties) {
        const props = picked.id.properties;
        const kind = props.kind && props.kind.getValue();
        const data = props.data && props.data.getValue();
        if (kind === 'building') return showBuildingInfo(data);
        if (kind === 'vehicle') return showVehicleInfo(data);
      }
      hideInfo();
    }, Cesium.ScreenSpaceEventType.LEFT_CLICK);

    els.infoClose && els.infoClose.addEventListener('click', hideInfo);
  }

  function showBuildingInfo(b) {
    els.infoTitle.textContent = b.name;
    els.infoZone.textContent = 'Zone \u00b7 ' + b.zone;
    paintStatus(b.status);
    els.infoBody.textContent = b.summary || '';
    els.infoMeta.innerHTML = '';
    els.info.classList.add('show');
  }

  function showVehicleInfo(v) {
    els.infoTitle.textContent = v.name;
    els.infoZone.textContent = 'Vehicle';
    const moving = v.status === 'moving';
    paintStatus(moving ? 'warn' : 'nominal', moving ? 'Moving' : 'Parked');
    els.infoBody.textContent = v.location || '';
    els.infoMeta.innerHTML =
      '<div>Battery<b>' +
      v.battery +
      '%</b></div><div>State<b>' +
      (moving ? 'Moving' : 'Parked') +
      '</b></div>';
    els.info.classList.add('show');
  }

  function paintStatus(status, labelOverride) {
    const c = STATUS[status] || STATUS.nominal;
    els.infoStatus.textContent = labelOverride || STATUS_LABEL[status] || status;
    els.infoStatus.style.color = c;
    els.infoStatus.style.background = hexA(c, 0.14);
    els.infoStatus.style.border = '1px solid ' + hexA(c, 0.4);
    els.infoStatus.innerHTML =
      '<span class="nx-dot" style="background:' +
      c +
      ';animation:none;box-shadow:none"></span>' +
      (labelOverride || STATUS_LABEL[status] || status);
  }

  function hexA(hex, a) {
    const h = hex.replace('#', '');
    const r = parseInt(h.substring(0, 2), 16);
    const g = parseInt(h.substring(2, 4), 16);
    const b = parseInt(h.substring(4, 6), 16);
    return 'rgba(' + r + ',' + g + ',' + b + ',' + a + ')';
  }

  function hideInfo() {
    els.info && els.info.classList.remove('show');
  }

  // --- Controls -------------------------------------------------------------
  function wireControls(viewer, ctx) {
    els.btnReset &&
      els.btnReset.addEventListener('click', () => flyToCompound(viewer, 1.4));

    let labelsOn = true;
    els.btnLabels &&
      els.btnLabels.addEventListener('click', () => {
        labelsOn = !labelsOn;
        buildingLabels.forEach((e) => {
          if (e.label) e.label.show = labelsOn;
        });
        els.btnLabels.classList.toggle('active', labelsOn);
        els.btnLabels.textContent = labelsOn ? 'Labels: On' : 'Labels: Off';
      });
    els.btnLabels && els.btnLabels.classList.add('active');

    els.btnLayer &&
      els.btnLayer.addEventListener('click', async () => {
        const photoreal = ctx.getPhotoreal();
        if (!photoreal) return; // no photoreal available at all
        const nowPhotoreal = !ctx.getUsingPhotoreal();
        ctx.setUsingPhotoreal(nowPhotoreal);
        if (nowPhotoreal) {
          photoreal.show = true;
          ctx.scene.globe.show = false;
          const osm = await ctx.ensureOsm();
          if (osm) osm.show = false;
          els.btnLayer.textContent = 'Base: Photoreal 3D';
          els.btnLayer.classList.add('active');
        } else {
          photoreal.show = false;
          ctx.scene.globe.show = true;
          const osm = await ctx.ensureOsm();
          if (osm) osm.show = true;
          els.btnLayer.textContent = 'Base: Terrain + OSM';
          els.btnLayer.classList.remove('active');
        }
      });
    if (els.btnLayer) {
      const hasPhotoreal = !!ctx.getPhotoreal();
      els.btnLayer.textContent = hasPhotoreal
        ? 'Base: Photoreal 3D'
        : 'Base: Terrain + OSM';
      els.btnLayer.classList.toggle('active', hasPhotoreal);
      if (!hasPhotoreal) els.btnLayer.disabled = true;
    }
  }

  // --- Camera ---------------------------------------------------------------
  let compoundSphere = null;
  function flyToCompound(viewer, duration) {
    let sphere = compoundSphere;
    if (!sphere) {
      const c = Cesium.Cartographic.fromDegrees(cfg.center.lon, cfg.center.lat);
      sphere = new Cesium.BoundingSphere(
        Cesium.Cartesian3.fromRadians(c.longitude, c.latitude, 0),
        cfg.spanMeters * 0.6
      );
    }
    const range = Math.max(sphere.radius * 2.7, 340);
    viewer.camera.flyToBoundingSphere(sphere, {
      offset: new Cesium.HeadingPitchRange(
        Cesium.Math.toRadians(cfg.heading),
        Cesium.Math.toRadians(-42),
        range
      ),
      duration: duration || 2.6,
    });
  }

  // Kick off once the DOM is ready.
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
