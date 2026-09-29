import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/caption_renderer.dart';
import '../../core/caption_template.dart';
import '../../models/caption_settings.dart';
import '../../models/photo_item.dart';
import '../../state/photos_provider.dart';
import '../../state/settings_providers.dart';
import 'panel_widgets.dart';

const _textPresets = [
  Color(0xFF3A3A3A),
  Color(0xFF8A8A8A),
  Color(0xFFFFFFFF),
  Color(0xFF000000),
];

class CaptionPanel extends ConsumerWidget {
  const CaptionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caption = ref.watch(captionSettingsProvider);
    final notifier = ref.read(captionSettingsProvider.notifier);
    final photos = ref.watch(photosProvider.select((s) => s.photos));
    final index = ref.watch(currentIndexProvider);
    final current = photos.isEmpty
        ? null
        : photos[index.clamp(0, photos.length - 1)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('キャプションを表示'),
          value: caption.enabled,
          onChanged: (v) => notifier.update((c) => c.copyWith(enabled: v)),
        ),
        if (caption.enabled) ...[
          _TemplateEditor(
            template: caption.template,
            onChanged: (v) => notifier.update((c) => c.copyWith(template: v)),
          ),
          if (current != null)
            _PhotoCaptionEditor(
              key: ValueKey(current.id),
              photo: current,
              settings: caption,
            ),
          const PanelLabel('フォント'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final font in CaptionFont.values)
                ChoiceChip(
                  label: Text(
                    font.label,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontWeight: font.weight,
                    ),
                  ),
                  selected: caption.font == font,
                  showCheckmark: false,
                  onSelected: (_) =>
                      notifier.update((c) => c.copyWith(font: font)),
                ),
            ],
          ),
          RatioSlider(
            label: '文字サイズ（短辺比）',
            value: caption.sizeRatio,
            min: CaptionSettings.minSizeRatio,
            max: CaptionSettings.maxSizeRatio,
            step: 0.001,
            onChanged: (v) => notifier.update((c) => c.copyWith(sizeRatio: v)),
          ),
          const PanelLabel('文字色'),
          ColorChoices(
            presets: _textPresets,
            value: caption.color,
            onChanged: (v) => notifier.update((c) => c.copyWith(color: v)),
          ),
          const PanelLabel('配置'),
          SegmentedButton<CaptionAlign>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: CaptionAlign.left,
                icon: Icon(Icons.format_align_left),
                tooltip: '左',
              ),
              ButtonSegment(
                value: CaptionAlign.center,
                icon: Icon(Icons.format_align_center),
                tooltip: '中央',
              ),
              ButtonSegment(
                value: CaptionAlign.right,
                icon: Icon(Icons.format_align_right),
                tooltip: '右',
              ),
            ],
            selected: {caption.align},
            onSelectionChanged: (s) =>
                notifier.update((c) => c.copyWith(align: s.single)),
          ),
        ],
      ],
    );
  }
}

/// Shared template with buttons that insert variables at the cursor.
class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({required this.template, required this.onChanged});

  final String template;
  final ValueChanged<String> onChanged;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final _controller = TextEditingController(text: widget.template);

  @override
  void didUpdateWidget(_TemplateEditor old) {
    super.didUpdateWidget(old);
    if (widget.template != _controller.text) {
      _controller.text = widget.template;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insert(String variable) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final token = '{$variable}';
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    widget.onChanged(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelLabel(
          'テンプレート（全写真共通・自由入力も可）',
          trailing: IconButton(
            tooltip: '初期値に戻す',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.restart_alt, size: 20),
            onPressed: () => widget.onChanged(CaptionSettings.defaultTemplate),
          ),
        ),
        TextField(controller: _controller, onChanged: widget.onChanged),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in kCaptionVariables.entries)
              ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(entry.value),
                tooltip: '{${entry.key}}',
                onPressed: () => _insert(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// Resolved caption of the previewed photo, with an optional override.
class _PhotoCaptionEditor extends ConsumerStatefulWidget {
  const _PhotoCaptionEditor({
    super.key,
    required this.photo,
    required this.settings,
  });

  final PhotoItem photo;
  final CaptionSettings settings;

  @override
  ConsumerState<_PhotoCaptionEditor> createState() =>
      _PhotoCaptionEditorState();
}

class _PhotoCaptionEditorState extends ConsumerState<_PhotoCaptionEditor> {
  late final _controller = TextEditingController(
    text: widget.photo.captionOverride ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setOverride(bool enabled) {
    final notifier = ref.read(photosProvider.notifier);
    if (enabled) {
      // Start from what the photo currently shows.
      _controller.text = captionTextFor(widget.photo, widget.settings);
      notifier.setCaptionOverride(widget.photo.id, _controller.text);
    } else {
      notifier.setCaptionOverride(widget.photo.id, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overridden = widget.photo.captionOverride != null;
    final resolved = captionTextFor(widget.photo, widget.settings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanelLabel('表示中の写真'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('この写真だけキャプションを上書き'),
          value: overridden,
          onChanged: _setOverride,
        ),
        if (overridden)
          TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: '空欄でこの写真はキャプションなし'),
            onChanged: (v) => ref
                .read(photosProvider.notifier)
                .setCaptionOverride(widget.photo.id, v),
          )
        else
          Text(
            resolved.isEmpty ? '（撮影情報がないため空欄になります）' : resolved,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
