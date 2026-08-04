/// A short, opinionated list of local models, sized to the machine.
///
/// The Hugging Face browser is still there for people who want it, but it is
/// the wrong first experience: it answers "which of forty thousand GGUF repos
/// do you want" when the actual question is "will something good run on this
/// computer". This list answers that one instead - four choices, each with the
/// memory it needs, and a recommendation based on how much this machine has.
library;

/// One installable model.
class LocalModel {
  const LocalModel({
    required this.id,
    required this.name,
    required this.blurb,
    required this.downloadGb,
    required this.needsRamGb,
  });

  /// The tag the runtime pulls. These are registry names rather than Hugging
  /// Face repos on purpose: one identifier, no quantisation to choose, and no
  /// filename to get subtly wrong.
  final String id;

  /// What it's called in the UI - the tag is an implementation detail.
  final String name;
  final String blurb;

  /// Rough download size, so nobody starts a 40 GB pull by accident.
  final double downloadGb;

  /// Memory it wants to be usable, not the bare minimum to load.
  final double needsRamGb;

  /// True if this machine can be expected to run it at a sensible speed.
  bool fitsIn(double? machineRamGb) =>
      machineRamGb == null || machineRamGb >= needsRamGb;
}

const localModelCatalog = <LocalModel>[
  LocalModel(
    id: 'qwen2.5:3b',
    name: 'Fast',
    blurb: 'Quick and light. Good for controlling the compound and answering '
        'questions about it.',
    downloadGb: 1.9,
    needsRamGb: 6,
  ),
  LocalModel(
    id: 'llama3.1:8b',
    name: 'Balanced',
    blurb: 'The one most people should pick. Noticeably better at longer '
        'questions, still comfortable on a normal machine.',
    downloadGb: 4.7,
    needsRamGb: 10,
  ),
  LocalModel(
    id: 'qwen2.5:14b',
    name: 'Sharper',
    blurb: 'Slower to answer, better at reasoning through something involved.',
    downloadGb: 9.0,
    needsRamGb: 20,
  ),
  LocalModel(
    id: 'llama3.3:70b',
    name: 'Best',
    blurb: 'Serious hardware only - a workstation or a Mac with a lot of '
        'unified memory.',
    downloadGb: 42.0,
    needsRamGb: 48,
  ),
];

/// The model to suggest on a machine with [machineRamGb] of memory.
///
/// Picks the largest that comfortably fits rather than the largest that
/// technically loads: a model that swaps produces an assistant that takes a
/// minute to answer, which reads as broken rather than slow.
LocalModel recommendedModel(double? machineRamGb) {
  if (machineRamGb == null) {
    // Unknown memory - the middle option is the safe guess.
    return localModelCatalog[1];
  }
  LocalModel best = localModelCatalog.first;
  for (final model in localModelCatalog) {
    if (model.fitsIn(machineRamGb)) best = model;
  }
  return best;
}

/// Formats a size for a button someone is about to commit to.
String formatGb(double gb) =>
    gb >= 10 ? '${gb.round()} GB' : '${gb.toStringAsFixed(1)} GB';
