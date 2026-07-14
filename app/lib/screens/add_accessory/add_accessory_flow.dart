import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../state/compound_scope.dart';
import '../../state/compound_store.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import 'assign_step.dart';
import 'discovered_accessory.dart';
import 'manual_step.dart';
import 'results_step.dart';
import 'scan_step.dart';

enum _FlowStep { scan, results, manual, assign, done }

/// Entry point for the Add Accessory flow (Section 7) - reachable from
/// Home without opening another tab first.
void showAddAccessoryFlow(BuildContext context, {String? defaultBuildingId}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: NexusDurations.sheet,
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(parent: animation, curve: NexusCurves.sheetUp);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondary) => AddAccessoryFlow(defaultBuildingId: defaultBuildingId),
    ),
  );
}

class AddAccessoryFlow extends StatefulWidget {
  const AddAccessoryFlow({super.key, this.defaultBuildingId});

  final String? defaultBuildingId;

  @override
  State<AddAccessoryFlow> createState() => _AddAccessoryFlowState();
}

class _AddAccessoryFlowState extends State<AddAccessoryFlow> {
  _FlowStep _step = _FlowStep.scan;
  String? _pendingName;
  DeviceType? _pendingType;

  void _selectDiscovered(DiscoveredAccessory accessory) {
    setState(() {
      _pendingName = accessory.name;
      _pendingType = accessory.type;
      _step = _FlowStep.assign;
    });
  }

  void _confirmManual(String name, DeviceType type) {
    setState(() {
      _pendingName = name;
      _pendingType = type;
      _step = _FlowStep.assign;
    });
  }

  void _confirmAssign(String buildingId, String? roomId) {
    final store = CompoundScope.of(context);
    final id = '${_pendingType!.name}_${DateTime.now().microsecondsSinceEpoch}';
    final Device device;
    switch (_pendingType!) {
      case DeviceType.light:
        device = LightDevice(id: id, name: _pendingName!, buildingId: buildingId, roomId: roomId, on: false, brightness: 100);
      case DeviceType.climate:
        device = ClimateDevice(id: id, name: _pendingName!, buildingId: buildingId, roomId: roomId);
      case DeviceType.grill:
        device = GrillDevice(id: id, name: _pendingName!, buildingId: buildingId, roomId: roomId);
      case DeviceType.lock:
        device = LockDevice(id: id, name: _pendingName!, buildingId: buildingId);
      case DeviceType.media:
        device = MediaDevice(id: id, name: _pendingName!, buildingId: buildingId, roomId: roomId, on: false);
    }
    store.addDevice(device);
    setState(() => _step = _FlowStep.done);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = CompoundScope.of(context);
    return Container(
      color: NexusColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Accessory', style: NexusText.headline),
                  if (_step != _FlowStep.done)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(color: NexusColors.secondarySurface, shape: BoxShape.circle),
                        child: const Center(child: NexusIcon(NexusGlyph.close, size: 12, color: NexusColors.textSecondary)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(child: _content(store)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(CompoundStore store) {
    switch (_step) {
      case _FlowStep.scan:
        return ScanStep(onDone: () => setState(() => _step = _FlowStep.results));
      case _FlowStep.results:
        return ResultsStep(
          onSelect: _selectDiscovered,
          onManualEntry: () => setState(() => _step = _FlowStep.manual),
        );
      case _FlowStep.manual:
        return ManualStep(onContinue: _confirmManual);
      case _FlowStep.assign:
        return AssignStep(
          compound: store.compound,
          deviceType: _pendingType!,
          initialBuildingId: widget.defaultBuildingId,
          onConfirm: _confirmAssign,
        );
      case _FlowStep.done:
        return _DoneStep(name: _pendingName ?? 'Accessory');
    }
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(scale: value, child: child),
            child: Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(color: NexusColors.green, shape: BoxShape.circle),
              child: const Center(child: NexusIcon(NexusGlyph.check, size: 32, color: Color(0xFFFFFFFF))),
            ),
          ),
          const SizedBox(height: 20),
          Text('$name added', style: NexusText.title, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
