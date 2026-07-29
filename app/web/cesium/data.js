// NEXUS compound dataset + map configuration for the CesiumJS 3D view.
//
// This is a self-contained mirror of the app's demo compound (see
// shared/lib/src/demo_seed.dart) enriched with the geometry the 3D map needs:
// footprint sizes, heights, and a status color per building. The normalized
// mapX/mapY (0..1, y-down, matching the Flutter map) is projected onto real
// ground using the anchor below, so the 3D layout matches the 2D app.
//
// To relocate the whole compound, edit `center` (or pass ?lat=..&lon=.. in the
// URL). `spanMeters` controls how large the 0..1 layout is on the ground and
// `heading` rotates the entire compound.

(function () {
  const params = new URLSearchParams(location.search);

  // Ship no token by default. A Cesium ion token is tied to an ion account,
  // and Photorealistic 3D Tiles have to be enabled on that account - so there
  // is no token that can be committed here and work for everyone. Paste your
  // own from https://ion.cesium.com/tokens (it needs the `assets:read` scope)
  // via the app's Settings, the ?ionToken= URL parameter, or right here.
  const DEFAULT_ION_TOKEN = '';
  const num = (key, fallback) => {
    const v = parseFloat(params.get(key));
    return Number.isFinite(v) ? v : fallback;
  };

  // Cesium ion access token. Photorealistic 3D Tiles are served through ion,
  // so without a token that carries the `assets:read` scope every tile
  // request 401s and the globe never renders.
  //
  // Resolution order, so you can point this at your own ion account without
  // rebuilding: ?ionToken=... in the URL > a token saved in localStorage (the
  // app's Settings writes this) > the baked-in default below.
  const storedToken = (() => {
    try {
      return window.localStorage.getItem('nexus.ionToken') || '';
    } catch (e) {
      return ''; // localStorage can throw in private mode / sandboxed frames.
    }
  })();
  const ionToken = (params.get('ionToken') || storedToken || DEFAULT_ION_TOKEN).trim();

  window.NEXUS_CONFIG = {
    ionToken: ionToken,
    ionTokenSource: params.get('ionToken')
      ? 'url'
      : storedToken
        ? 'saved'
        : 'default',

    // Compound geographic anchor (center of the 0..1 layout). Default sits on
    // flat Willamette Valley farmland just east of Corvallis, OR - matching
    // the "50+ acre compound near Corvallis" the app is built around, with
    // forested hills on the horizon and full Photorealistic 3D Tiles coverage.
    // Change this (or pass ?lat=..&lon=..) to drop it on your own coordinates.
    center: { lat: num('lat', 44.592), lon: num('lon', -123.245) },

    // How many meters the normalized 0..1 layout spans on the ground.
    spanMeters: num('span', 380),

    // Rotate the whole compound layout clockwise (degrees).
    heading: num('heading', 16),

    // glTF vehicle model(s), loaded from the Khronos sample set (CORS-enabled
    // and roughly life-size). Vehicle types without an entry here - or whose
    // model fails to load - fall back to a stylized 3D box.
    models: {
      truck:
        'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb',
    },
  };

  // Status palette for the colored compound buildings.
  // nominal = teal/green, warn = amber, crit = red.
  window.NEXUS_STATUS = {
    nominal: '#34c759',
    warn: '#ff9f0a',
    crit: '#ff3b30',
  };

  // Buildings. `footprint` is width (east) x depth (north) in meters, `height`
  // is the extruded height in meters, `rotate` rotates the footprint locally.
  window.NEXUS_BUILDINGS = [
    {
      id: 'main',
      name: 'Main House',
      zone: 'Main House',
      mapX: 0.5,
      mapY: 0.52,
      footprint: [26, 18],
      height: 9,
      rotate: 0,
      status: 'nominal',
      summary: '8 devices · Mesh 92% · Front door locked',
    },
    {
      id: 'barn',
      name: 'Barn',
      zone: 'Barn',
      mapX: 0.27,
      mapY: 0.3,
      footprint: [22, 14],
      height: 11,
      rotate: 12,
      status: 'warn',
      summary: 'Mesh node battery 24% · Motion 6m ago',
    },
    {
      id: 'shop',
      name: 'Shop',
      zone: 'Shop',
      mapX: 0.74,
      mapY: 0.28,
      footprint: [20, 16],
      height: 8,
      rotate: -8,
      status: 'crit',
      summary: 'Mesh node OFFLINE 18m · Roller door OPEN',
    },
    {
      id: 'cabin',
      name: 'Cabin',
      zone: 'Cabin',
      mapX: 0.2,
      mapY: 0.72,
      footprint: [12, 10],
      height: 6,
      rotate: 20,
      status: 'nominal',
      summary: 'Mesh 81% · Door locked · 61°F',
    },
    {
      id: 'gn',
      name: 'North Gate',
      zone: 'Gates',
      mapX: 0.55,
      mapY: 0.85,
      footprint: [6, 4],
      height: 3.5,
      rotate: 0,
      status: 'nominal',
      summary: 'Gate locked',
    },
    {
      id: 'ge',
      name: 'East Gate',
      zone: 'Gates',
      mapX: 0.64,
      mapY: 0.88,
      footprint: [6, 4],
      height: 3.5,
      rotate: 30,
      status: 'nominal',
      summary: 'Gate locked',
    },
  ];

  // Vehicles. `route` (optional, normalized waypoints) makes a vehicle patrol.
  window.NEXUS_VEHICLES = [
    {
      id: 'veh_f250',
      name: 'F-250',
      type: 'truck',
      status: 'moving',
      battery: 100,
      location: 'On patrol · Perimeter road',
      // Patrols a loop: shop -> gates -> cabin -> barn -> shop.
      route: [
        [0.72, 0.34],
        [0.6, 0.6],
        [0.58, 0.85],
        [0.35, 0.8],
        [0.2, 0.72],
        [0.24, 0.45],
        [0.27, 0.3],
        [0.5, 0.3],
        [0.72, 0.34],
      ],
      loopSeconds: 90,
    },
    {
      id: 'veh_modely',
      name: 'Model Y',
      type: 'car',
      status: 'parked',
      battery: 78,
      location: 'Parked · Main house driveway',
      mapX: 0.44,
      mapY: 0.62,
      heading: 90,
    },
  ];
})();
