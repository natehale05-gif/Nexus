import 'package:flutter/widgets.dart';

/// Non-web fallback: the CesiumJS map is a browser-only web bundle, so on
/// mobile/desktop the Home tab keeps using the painted tactical map instead.
const bool cesiumMapSupported = false;

Widget buildCesiumMap() => const SizedBox.shrink();
