import 'package:flutter/widgets.dart';

import '../ai/ai_provider.dart';
import '../ai/model_catalog.dart';
import '../ai/provider_registry.dart';
import '../ai/providers/mac_studio_provider.dart';
import '../ai/runtime/ai_runtime.dart';

/// Where local AI has got to, as one value the UI can switch on.
enum LocalAiStage {
  /// Haven't looked yet.
  unknown,

  /// This platform can't host a model (web, phone).
  unsupported,

  /// Nothing installed. One button away from being set up.
  notInstalled,

  /// Fetching the engine.
  installingEngine,

  /// Engine present, starting it.
  starting,

  /// Engine up, no model yet.
  noModel,

  /// Pulling a model.
  downloadingModel,

  /// Ready to answer.
  ready,

  failed,
}

/// One-button local AI.
///
/// Everything about running a model on this machine - is an engine here, does
/// it need fetching, is it running, which models are on disk - collapses into
/// a stage and a progress fraction. The word "Ollama" appears nowhere in the
/// UI this drives: which engine does the inference is an implementation
/// detail, and asking someone to install one, start it and paste its URL was
/// the whole problem.
class LocalAiController extends ChangeNotifier {
  LocalAiController({required this.registry});

  final ProviderRegistry registry;

  LocalAiStage _stage = LocalAiStage.unknown;
  double? _progress;
  String _detail = '';
  String? _error;
  List<String> _installedModels = const [];
  double? _ramGb;
  String? _engineUrl;

  LocalAiStage get stage => _stage;

  /// 0..1 during a download, null when the step has no measurable size.
  double? get progress => _progress;

  /// A short line under the progress bar - which phase, not a log.
  String get detail => _detail;
  String? get error => _error;
  List<String> get installedModels => _installedModels;
  double? get machineRam => _ramGb;
  String? get engineUrl => _engineUrl;

  bool get supported => aiRuntimeSupported;
  bool get busy =>
      _stage == LocalAiStage.installingEngine ||
      _stage == LocalAiStage.starting ||
      _stage == LocalAiStage.downloadingModel;

  /// The model to suggest, given how much memory this machine has.
  LocalModel get recommended => recommendedModel(_ramGb);

  void _set(LocalAiStage stage, {double? progress, String detail = '', String? error}) {
    _stage = stage;
    _progress = progress;
    _detail = detail;
    _error = error;
    notifyListeners();
  }

  /// Works out where things stand, without changing anything.
  ///
  /// Runs on open rather than at launch: probing sockets and stat-ing paths is
  /// cheap but pointless for someone who never opens AI settings.
  Future<void> refresh() async {
    if (!aiRuntimeSupported) {
      _set(LocalAiStage.unsupported);
      return;
    }
    _ramGb ??= await machineRamGb();

    final running = await findRunningEngine();
    if (running != null) {
      _engineUrl = running;
      await _afterEngineUp();
      return;
    }
    final binary = await findExistingBinary();
    _set(binary == null ? LocalAiStage.notInstalled : LocalAiStage.starting);
    if (binary != null) {
      // Already installed but not running - just start it, no download, no
      // question. There's nothing to decide here.
      await _startEngine();
    }
  }

  /// The single button: install if needed, start, and be ready for a model.
  Future<void> setUp() async {
    if (!aiRuntimeSupported) return;
    _ramGb ??= await machineRamGb();
    try {
      if (await findExistingBinary() == null) {
        _set(LocalAiStage.installingEngine, detail: 'Downloading the AI engine');
        await installRuntime(onProgress: (fraction) {
          _progress = fraction;
          notifyListeners();
        });
      }
      await _startEngine();
    } on AiRuntimeException catch (e) {
      _set(LocalAiStage.failed, error: e.message);
    } catch (e) {
      _set(LocalAiStage.failed, error: '$e');
    }
  }

  Future<void> _startEngine() async {
    _set(LocalAiStage.starting, detail: 'Starting the AI engine');
    try {
      _engineUrl = await startRuntime();
      await _afterEngineUp();
    } on AiRuntimeException catch (e) {
      _set(LocalAiStage.failed, error: e.message);
    }
  }

  /// Engine is up: see what's on disk and point the chat at it.
  Future<void> _afterEngineUp() async {
    final url = _engineUrl;
    if (url == null) return;
    _installedModels = await MacStudioProvider.listModels(url);
    if (_installedModels.isEmpty) {
      _set(LocalAiStage.noModel);
      return;
    }
    await _useModel(_installedModels.first);
    _set(LocalAiStage.ready);
  }

  /// Downloads a model and switches the assistant to it.
  Future<void> downloadModel(LocalModel model) async {
    final url = _engineUrl;
    if (url == null) {
      _set(LocalAiStage.failed, error: 'The AI engine is not running.');
      return;
    }
    _set(LocalAiStage.downloadingModel, detail: 'Downloading ${model.name}');
    try {
      await for (final progress in MacStudioProvider.pullModel(url, model.id)) {
        _progress = progress.fraction;
        // Ollama's own phase names ("pulling manifest", "verifying sha256
        // digest") are jargon; the fraction is the part worth showing.
        _detail = progress.fraction == null
            ? 'Preparing ${model.name}'
            : 'Downloading ${model.name}';
        notifyListeners();
      }
      _installedModels = await MacStudioProvider.listModels(url);
      await _useModel(model.id);
      _set(LocalAiStage.ready);
    } on Exception catch (e) {
      _set(LocalAiStage.failed, error: '$e');
    }
  }

  /// Points the assistant at a model that's already on disk.
  Future<void> selectModel(String modelId) async {
    await _useModel(modelId);
    _set(LocalAiStage.ready);
  }

  /// Writes the engine's address and model into the provider config, so the
  /// existing chat path picks it up with no further wiring.
  Future<void> _useModel(String modelId) async {
    await registry.update(registry.config.copyWith(
      kind: AiProviderKind.macStudio,
      model: modelId,
      macStudioUrl: _engineUrl,
    ));
  }

  @override
  void dispose() {
    // Leave a user-installed engine alone; only stop one we started.
    stopRuntime();
    super.dispose();
  }
}

class LocalAiScope extends InheritedNotifier<LocalAiController> {
  const LocalAiScope({
    super.key,
    required LocalAiController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocalAiController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocalAiScope>();
    assert(scope != null, 'No LocalAiScope found in context');
    return scope!.notifier!;
  }
}
