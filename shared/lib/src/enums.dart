/// Discriminator for the sealed [Device] hierarchy.
enum DeviceType { light, climate, grill, lock, media }

enum ClimateMode { off, heat, cool, auto }

enum FanMode { auto, on }

/// Severity used by both [Alert] (Security tab) and [Insight] (proactive
/// insights engine, Section 6 of the spec).
enum Level { info, warn, crit }

/// Wire/protocol a discovered accessory speaks - purely descriptive, used by
/// the Add Accessory scan step and device metadata.
enum AccessoryProtocol { wifi, zigbee, zwave, mesh, cloud }

enum VehicleStatus { parked, moving }
