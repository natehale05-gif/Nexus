// The canonical seed compound now lives in `nexus_shared` so the server
// can boot from the exact same starting state (Section 9, build order
// step 9: "get real device state flowing into the app" from the same
// shape). Re-exported here so existing imports within `app/` keep working
// unchanged.
export 'package:nexus_shared/nexus_shared.dart' show buildDemoCompound;
