/// Web implementation: the compound JSON lives in `localStorage`.
library;

import 'dart:convert';

import 'package:nexus_shared/nexus_shared.dart';
import 'package:web/web.dart' as web;

const String _key = 'nexus.compound';

Future<Compound?> loadCompound() async {
  try {
    final raw = web.window.localStorage.getItem(_key);
    if (raw == null || raw.isEmpty) return null;
    return Compound.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    // Corrupt payload, or localStorage unavailable (private mode / sandboxed
    // frame). Either way: behave as if nothing was saved.
    return null;
  }
}

Future<void> saveCompound(Compound compound) async {
  try {
    web.window.localStorage.setItem(_key, jsonEncode(compound.toJson()));
  } catch (_) {
    // localStorage throws when full or blocked. The in-memory compound is
    // still correct for this session, so don't take the app down over it.
  }
}

Future<void> clearCompound() async {
  try {
    web.window.localStorage.removeItem(_key);
  } catch (_) {
    // Same reasoning as saveCompound.
  }
}
