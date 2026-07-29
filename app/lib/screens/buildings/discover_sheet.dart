import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';

import '../../state/nexus_data_source.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';

/// Result of picking a discovered device: what to add, and as what type.
typedef DiscoveryPick = (DiscoveredDevice device, DeviceType type);

/// Scans the network through the paired server and lets you add what it
/// found. Returns the chosen device, or null if dismissed.
///
/// Everything here is a proposal, never an automatic import: discovery tells
/// you a Chromecast exists, not which room it's in or what you call it, and
/// silently filling the compound with guessed entries would be worse than
/// making you confirm four of them.
Future<DiscoveryPick?> showDiscoverySheet(BuildContext context, NexusDataSource source) {
  return showDialog<DiscoveryPick>(
    context: context,
    builder: (context) => _DiscoveryDialog(source: source),
  );
}

class _DiscoveryDialog extends StatefulWidget {
  const _DiscoveryDialog({required this.source});

  final NexusDataSource source;

  @override
  State<_DiscoveryDialog> createState() => _DiscoveryDialogState();
}

class _DiscoveryDialogState extends State<_DiscoveryDialog> {
  List<DiscoveredDevice>? _found;
  String? _error;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final devices = await widget.source.discoverDevices();
      if (mounted) setState(() => _found = devices);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  DeviceType _typeFor(DiscoveredDevice device) {
    for (final type in DeviceType.values) {
      if (type.name == device.suggestedType) return type;
    }
    return DeviceType.media;
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.source.connectionStatus == ConnectionStatus.connected;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NexusColors.surface,
              borderRadius: BorderRadius.circular(NexusRadii.card),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Devices on your network', style: NexusText.headline),
                const SizedBox(height: 6),
                Text(
                  connected
                      ? 'Found by your server over mDNS and SSDP. Pick one to add.'
                      : 'Scanning needs a paired server - it’s the machine actually '
                          'on your network. Connect one in Settings first.',
                  style: NexusText.subhead.copyWith(color: NexusColors.textMuted),
                ),
                const SizedBox(height: 16),
                Flexible(child: _body(connected)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PressScale(
                        onTap: () => Navigator.of(context).pop(),
                        child: _pill('Close', NexusColors.secondarySurface, NexusColors.textPrimary),
                      ),
                    ),
                    if (connected) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: PressScale(
                          onTap: _scanning ? () {} : _scan,
                          child: _pill(
                            _scanning ? 'Scanning…' : 'Scan again',
                            NexusColors.blue.withValues(alpha: 0.12),
                            NexusColors.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color background, Color foreground) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        child: Center(child: Text(label, style: NexusText.bodyMedium.copyWith(color: foreground))),
      );

  Widget _body(bool connected) {
    if (!connected) return const SizedBox.shrink();
    if (_error != null) {
      return Text(
        'Scan failed: $_error',
        style: NexusText.subhead.copyWith(color: NexusColors.red),
      );
    }
    if (_scanning && _found == null) {
      return Text('Listening for announcements…', style: NexusText.subhead);
    }
    final devices = _found ?? const <DiscoveredDevice>[];
    if (devices.isEmpty) {
      return Text(
        'Nothing new found. Devices only answer when they’re powered on and on '
        'the same network as the server - and anything already in your compound '
        'is filtered out.',
        style: NexusText.subhead.copyWith(color: NexusColors.textMuted),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: devices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = devices[index];
        final type = _typeFor(device);
        return PressScale(
          onTap: () => Navigator.of(context).pop((device, type)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: NexusColors.secondarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(device.name, style: NexusText.bodyMedium)),
                    Text(
                      // An unrecognized device still gets listed; it just
                      // doesn't claim to know what it is.
                      device.suggestedType == null ? 'Unknown type' : type.name,
                      style: NexusText.footnote.copyWith(
                        color: device.suggestedType == null
                            ? NexusColors.textMuted
                            : NexusColors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.address}${device.port == null ? '' : ':${device.port}'}'
                  ' · ${device.source.name.toUpperCase()}',
                  style: NexusText.footnote,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
