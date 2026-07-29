/// Native stub - the CesiumJS map is web-only, so there's nothing to store.
library;

/// Whether this platform has a 3D map whose token can be configured.
const bool mapTokenConfigurable = false;

String? loadIonToken() => null;

void saveIonToken(String token) {}
