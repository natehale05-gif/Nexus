import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';

import '../../state/connection_scope.dart';
import '../../state/connection_settings.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/nexus_button.dart';
import '../../widgets/nexus_sheet.dart';

/// Joining a server, in one place.
///
/// Reached from first launch and from Settings, because it is the same job
/// either time and having two versions of it is how they drift apart.
Future<bool?> showConnectSheet(BuildContext context) {
  return showNexusSheet<bool>(
    context: context,
    builder: (context) => const NexusSheet(child: _ConnectSheetContent()),
  );
}

class _ConnectSheetContent extends StatefulWidget {
  const _ConnectSheetContent();

  @override
  State<_ConnectSheetContent> createState() => _ConnectSheetContentState();
}

class _ConnectSheetContentState extends State<_ConnectSheetContent> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryClipboard();
  }

  /// If a pairing code is already on the clipboard, fill it in.
  ///
  /// Copying it on one machine and pasting on another is the whole flow, so
  /// arriving here with it already in the field removes the last step. It is
  /// only ever pre-filled, never submitted - joining a server shouldn't happen
  /// without someone pressing the button.
  Future<void> _tryClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || !mounted) return;
      if (PairingPayload.decode(text) != null) {
        setState(() => _controller.text = text.trim());
      }
    } catch (_) {
      // No clipboard access on this platform; the field just starts empty.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final payload = PairingPayload.decode(_controller.text);
    if (payload == null) {
      setState(() => _error =
          "That doesn't look like a pairing code. On the computer running "
          'NEXUS, open Settings > Server and tap Copy code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final scope = ConnectionScope.of(context);
    try {
      await scope.onConnect(StoredConnection.fromPayload(payload));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save that pairing: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Connect to a server', style: NexusText.title),
        const SizedBox(height: 8),
        Text(
          'Point this device\'s camera at the QR code on the computer running '
          'NEXUS - it opens the app already connected. Or copy the pairing code '
          'there and paste it below.',
          style: NexusText.subhead.copyWith(color: NexusColors.textMuted),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: NexusColors.secondarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Stack(
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? IgnorePointer(
                        child: Text(
                          'nexus://pair?…',
                          style: NexusText.body.copyWith(color: NexusColors.textFaint),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              EditableText(
                controller: _controller,
                focusNode: _focus,
                style: NexusText.body,
                cursorColor: NexusColors.blue,
                backgroundCursorColor: NexusColors.textFaint,
                maxLines: 3,
                minLines: 1,
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: NexusText.footnote.copyWith(color: NexusColors.red)),
        ],
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => NexusButton(
            label: _busy ? 'Connecting…' : 'Connect',
            onTap: _busy || value.text.trim().isEmpty ? null : _pair,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
