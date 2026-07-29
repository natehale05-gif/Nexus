import 'compound.dart';
import 'media.dart';

/// A compound with nothing in it - the starting point when someone sets up
/// NEXUS for their own property rather than opening the demo.
///
/// Deliberately empty rather than "the demo with the names changed": leaving
/// seed buildings in place means every screen shows plausible-looking rooms
/// and devices that don't exist, and there's no way to tell what you've
/// actually added from what shipped in the box. An empty compound makes the
/// app's real state obvious, and every screen already has an empty state
/// because rooms can legitimately have no devices.
Compound buildEmptyCompound() => Compound(
      zones: [],
      buildings: [],
      rooms: [],
      devices: [],
      vehicles: [],
      meshNodes: [],
      alerts: [],
      mediaStats: MediaLibraryStats(movieCount: 0, showCount: 0, episodeCount: 0),
    );
