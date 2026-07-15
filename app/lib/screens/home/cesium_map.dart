import 'package:flutter/widgets.dart';

import 'cesium_map_stub.dart'
    if (dart.library.js_interop) 'cesium_map_web.dart' as impl;

/// Whether the interactive CesiumJS 3D compound map is available on this
/// platform. It is only wired up for Flutter web (the map ships as a static
/// `web/cesium/` bundle that this view embeds); every other platform falls
/// back to the painted tactical map.
bool get cesiumMapSupported => impl.cesiumMapSupported;

/// Builds the embedded CesiumJS 3D compound map. Only meaningful when
/// [cesiumMapSupported] is `true`; otherwise it returns an empty box.
Widget buildCesiumMap() => impl.buildCesiumMap();
