import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/frame_settings.dart';
import '../../state/settings_providers.dart';
import 'panel_widgets.dart';

const _framePresets = [Color(0xFFFFFFFF), Color(0xFF000000)];

class FramePanel extends ConsumerWidget {
  const FramePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frame = ref.watch(frameSettingsProvider);
    final notifier = ref.read(frameSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const PanelLabel('スタイル'),
        SegmentedButton<FrameStyle>(
          showSelectedIcon: false,
          segments: [
            for (final style in FrameStyle.values)
              ButtonSegment(value: style, label: Text(style.label)),
          ],
          selected: {frame.style},
          onSelectionChanged: (s) =>
              notifier.update((f) => f.copyWith(style: s.single)),
        ),
        if (frame.style == FrameStyle.aspect) ...[
          const PanelLabel('比率（余白で埋め、切り抜きはしません）'),
          SegmentedButton<AspectPreset>(
            showSelectedIcon: false,
            segments: [
              for (final aspect in AspectPreset.values)
                ButtonSegment(value: aspect, label: Text(aspect.label)),
            ],
            selected: {frame.aspect},
            onSelectionChanged: (s) =>
                notifier.update((f) => f.copyWith(aspect: s.single)),
          ),
        ],
        RatioSlider(
          label: '余白（短辺比）',
          value: frame.marginRatio,
          min: FrameSettings.minMarginRatio,
          max: FrameSettings.maxMarginRatio,
          step: 0.005,
          onChanged: (v) => notifier.update((f) => f.copyWith(marginRatio: v)),
        ),
        if (frame.style == FrameStyle.captionBand)
          RatioSlider(
            label: '下部の余白（短辺比）',
            value: frame.bottomRatio,
            min: FrameSettings.minBottomRatio,
            max: FrameSettings.maxBottomRatio,
            step: 0.01,
            onChanged: (v) =>
                notifier.update((f) => f.copyWith(bottomRatio: v)),
          ),
        const PanelLabel('余白の色'),
        ColorChoices(
          presets: _framePresets,
          value: frame.color,
          onChanged: (c) => notifier.update((f) => f.copyWith(color: c)),
        ),
      ],
    );
  }
}
