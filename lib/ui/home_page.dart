import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/export_provider.dart';
import '../state/photos_provider.dart';
import 'control_sheet.dart';
import 'export_dialog.dart';
import 'preview_pager.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(photosProvider);
    final hasPhotos = selection.photos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instarize'),
        bottom: selection.importing && hasPhotos
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
        actions: [
          if (hasPhotos)
            IconButton(
              tooltip: '写真を追加',
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: selection.isFull || selection.importing
                  ? null
                  : () => pickPhotos(context, ref),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: FilledButton.icon(
              onPressed: hasPhotos && !selection.importing
                  ? () => _export(context, ref)
                  : null,
              icon: const Icon(Icons.save_alt, size: 18),
              label: const Text('保存'),
            ),
          ),
        ],
      ),
      body: hasPhotos
          ? const Column(
              children: [
                Expanded(child: PreviewPager()),
                ControlSheet(),
              ],
            )
          : _EmptyState(importing: selection.importing),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<ExportState>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ExportDialog(),
    );
    if (result == null || !context.mounted) return;
    final message = switch (result.status) {
      ExportStatus.finished when result.failed == 0 =>
        '${result.saved}枚を Pictures/$kAlbumName に保存しました',
      ExportStatus.finished => '${result.saved}枚を保存しました（${result.failed}枚は失敗）',
      ExportStatus.cancelled => 'キャンセルしました（${result.saved}枚は保存済み）',
      ExportStatus.failed => result.message ?? '保存に失敗しました',
      ExportStatus.idle || ExportStatus.running => null,
    };
    if (message != null) _showSnack(context, message);
  }
}

/// Opens the Photo Picker and reports anything that could not be added.
Future<void> pickPhotos(BuildContext context, WidgetRef ref) async {
  final ImportResult result;
  try {
    result = await ref.read(photosProvider.notifier).pickAndAdd();
  } on PlatformException catch (e) {
    if (context.mounted) _showSnack(context, '写真を開けませんでした（${e.code}）');
    return;
  }
  if (!context.mounted) return;
  final notes = [
    if (result.unsupported > 0) '${result.unsupported}枚は非対応の形式のため追加しませんでした',
    if (result.overLimit > 0)
      '上限の$kMaxPhotos枚を超えた${result.overLimit}枚は追加しませんでした',
  ];
  if (notes.isNotEmpty) _showSnack(context, notes.join('\n'));
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.importing});

  final bool importing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 56, color: muted),
            const SizedBox(height: 16),
            Text(
              '写真を選んで、フレームとキャプションを\nまとめて適用します',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 24),
            if (importing)
              const SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              FilledButton.icon(
                onPressed: () => pickPhotos(context, ref),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('写真を選ぶ'),
              ),
            const SizedBox(height: 12),
            Text(
              '最大$kMaxPhotos枚',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
