import 'package:flutter/widgets.dart';
import 'package:nexus_shared/nexus_shared.dart';
import '../../icons/nexus_icons.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/press_scale.dart';

const _typeOptions = <DeviceType, (String, NexusGlyph)>{
  DeviceType.light: ('Light', NexusGlyph.bulb),
  DeviceType.lock: ('Lock/Gate', NexusGlyph.lock),
  DeviceType.climate: ('Thermostat', NexusGlyph.thermostat),
  DeviceType.grill: ('Grill/Smoker', NexusGlyph.flame),
  DeviceType.media: ('Media', NexusGlyph.tv),
};

/// Add Accessory step 3 (Section 7): manual entry - name + a 5-type
/// picker grid, grill is a first-class type here.
class ManualStep extends StatefulWidget {
  const ManualStep({super.key, required this.onContinue});

  final void Function(String name, DeviceType type) onContinue;

  @override
  State<ManualStep> createState() => _ManualStepState();
}

class _ManualStepState extends State<ManualStep> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  DeviceType? _selectedType;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  bool get _canContinue => _nameController.text.trim().isNotEmpty && _selectedType != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add manually', style: NexusText.title),
        const SizedBox(height: 16),
        Text('Name', style: NexusText.footnote),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: NexusColors.surface, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: EditableText(
            controller: _nameController,
            focusNode: _nameFocusNode,
            style: NexusText.body,
            cursorColor: NexusColors.blue,
            backgroundCursorColor: NexusColors.textFaint,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 20),
        Text('Type', style: NexusText.footnote),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final entry in _typeOptions.entries)
              PressScale(
                onTap: () => setState(() => _selectedType = entry.key),
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedType == entry.key ? NexusColors.blue.withValues(alpha: 0.12) : NexusColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedType == entry.key ? NexusColors.blue : const Color(0x00000000),
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      NexusIcon(entry.value.$2, size: 16, color: _selectedType == entry.key ? NexusColors.blue : NexusColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        entry.value.$1,
                        style: NexusText.bodyMedium.copyWith(
                          color: _selectedType == entry.key ? NexusColors.blue : NexusColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const Spacer(),
        PressScale(
          onTap: _canContinue ? () => widget.onContinue(_nameController.text.trim(), _selectedType!) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: _canContinue ? NexusColors.blue : NexusColors.secondarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'Continue',
                style: NexusText.headline.copyWith(color: _canContinue ? const Color(0xFFFFFFFF) : NexusColors.textFaint),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
