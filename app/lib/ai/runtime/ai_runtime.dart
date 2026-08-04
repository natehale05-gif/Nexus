/// The inference engine NEXUS runs for you.
///
/// "Install Ollama, start it, find its URL, paste that into settings, then
/// pull a model from a terminal" is four steps too many. This owns all of it:
/// find an engine if one is already here, fetch one if not, keep it running,
/// and hand back a plain HTTP address the existing chat code already knows how
/// to talk to. Nothing above this layer needs to know an engine exists.
///
/// Native only - a browser can't spawn a process, so on web this reports
/// unsupported and the AI settings offer the server-hosted route instead.
library;

export 'ai_runtime_io.dart' if (dart.library.js_interop) 'ai_runtime_web.dart';
