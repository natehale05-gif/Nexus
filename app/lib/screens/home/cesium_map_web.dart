import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web implementation: embeds the static CesiumJS 3D compound map that ships
/// in `web/cesium/` as an `<iframe>` platform view. The iframe `src` is
/// resolved against the document's `<base href>`, so it works both locally
/// and under the GitHub Pages sub-path (`/<repo>/cesium/`).
const bool cesiumMapSupported = true;

const String _viewType = 'nexus-cesium-map';
bool _registered = false;

void _ensureRegistered() {
  if (_registered) return;
  _registered = true;
  ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = 'cesium/index.html'
      ..title = 'NEXUS compound 3D map'
      ..allow = 'fullscreen; xr-spatial-tracking'
      ..loading = 'eager';
    iframe.style
      ..border = '0'
      ..width = '100%'
      ..height = '100%'
      ..backgroundColor = '#12172a';
    return iframe;
  });
}

Widget buildCesiumMap() {
  _ensureRegistered();
  return const HtmlElementView(viewType: _viewType);
}
