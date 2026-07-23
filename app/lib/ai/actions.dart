import '../state/nexus_data_source.dart';

/// Client-side `<action .../>` tag handling, mirroring what the server's
/// Ollama bridge does so the assistant stays able to control devices
/// regardless of which provider answered. Tags look like
/// `<action name="setLocked" id="lk_front" value="false" />`.
/// Actions are executed against the active [NexusDataSource]; the tags are
/// stripped from the text the user sees.
final RegExp _actionPattern = RegExp(r'<action\b([^>]*?)/?>', caseSensitive: false);
final RegExp _attrPattern = RegExp(r'(\w+)\s*=\s*"([^"]*)"');

/// Removes any `<action .../>` tags from [text] for display.
String stripActionTags(String text) => text.replaceAll(_actionPattern, '').trim();

/// Parses and executes every `<action .../>` tag in [text] against [store].
/// Unknown action names / missing args are ignored (best-effort), matching
/// the server's forgiving behavior.
void executeActionTags(String text, NexusDataSource store) {
  for (final match in _actionPattern.allMatches(text)) {
    final attrs = <String, String>{};
    for (final attr in _attrPattern.allMatches(match.group(1) ?? '')) {
      attrs[attr.group(1)!.toLowerCase()] = attr.group(2)!;
    }
    _dispatch(attrs, store);
  }
}

void _dispatch(Map<String, String> attrs, NexusDataSource store) {
  final name = attrs['name'];
  final id = attrs['id'];
  final value = attrs['value'];
  final boolValue = value == 'true' ? true : (value == 'false' ? false : null);
  final numValue = value == null ? null : double.tryParse(value);

  switch (name) {
    case 'turnOffAllLights':
      store.turnOffAllLights();
    case 'toggleLight' when id != null:
      store.toggleLight(id);
    case 'setBrightness' when id != null && numValue != null:
      store.setBrightness(id, numValue);
    case 'setLocked' when id != null && boolValue != null:
      store.setLocked(id, boolValue);
    case 'setMediaOn' when id != null && boolValue != null:
      store.setMediaOn(id, boolValue);
    case 'setGrillOn' when id != null && boolValue != null:
      store.setGrillOn(id, boolValue);
  }
}
