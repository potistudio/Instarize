import 'package:flutter/material.dart';

import '../color_picker_dialog.dart';

/// Section heading inside a panel.
class PanelLabel extends StatelessWidget {
  const PanelLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Slider for a ratio of the short side, shown as a percentage.
class RatioSlider extends StatelessWidget {
  const RatioSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = value * 100;
    final text = step * 100 < 1
        ? percent.toStringAsFixed(1)
        : percent.toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelLabel(
          label,
          trailing: Text(
            '$text%',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        SliderTheme(
          data: const SliderThemeData(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / step).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Preset swatches plus a custom colour button.
class ColorChoices extends StatelessWidget {
  const ColorChoices({
    super.key,
    required this.presets,
    required this.value,
    required this.onChanged,
  });

  final List<Color> presets;
  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final isCustom = !presets.contains(value);
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final color in presets)
          _Swatch(
            color: color,
            selected: color == value,
            onTap: () => onChanged(color),
          ),
        _Swatch(
          color: isCustom ? value : null,
          selected: isCustom,
          tooltip: '任意の色',
          onTap: () async {
            final picked = await showColorPickerDialog(context, value);
            if (picked != null) onChanged(picked);
          },
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  /// `null` renders the "custom colour" button.
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final swatch = Semantics(
      button: true,
      selected: selected,
      label: tooltip ?? '#${_hex(color!)}',
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 32,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? scheme.surfaceContainerHighest,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: color == null
                ? Icon(
                    Icons.palette_outlined,
                    size: 16,
                    color: scheme.onSurface,
                  )
                : null,
          ),
        ),
      ),
    );
    return tooltip == null ? swatch : Tooltip(message: tooltip, child: swatch);
  }
}

String _hex(Color color) => (color.toARGB32() & 0xFFFFFF)
    .toRadixString(16)
    .padLeft(6, '0')
    .toUpperCase();
