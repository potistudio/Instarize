import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/photo_item.dart';
import '../../state/photos_provider.dart';
import '../home_page.dart';
import 'panel_widgets.dart';

const double _thumbSize = 76;

class PhotosPanel extends ConsumerWidget {
  const PhotosPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(photosProvider);
    final current = ref.watch(currentIndexProvider);
    final notifier = ref.read(photosProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        PanelLabel(
          '${selection.photos.length}枚（最大$kMaxPhotos枚）',
          trailing: TextButton.icon(
            onPressed: selection.isFull || selection.importing
                ? null
                : () => pickPhotos(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('追加'),
          ),
        ),
        SizedBox(
          height: _thumbSize + 8,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: selection.photos.length,
            onReorderItem: notifier.reorder,
            proxyDecorator: (child, _, _) =>
                Material(color: Colors.transparent, child: child),
            itemBuilder: (context, i) {
              final photo = selection.photos[i];
              return _Thumbnail(
                key: ValueKey(photo.id),
                photo: photo,
                selected: i == current,
                onTap: () => ref.read(currentIndexProvider.notifier).select(i),
                onRemove: () => notifier.remove(photo.id),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '長押しでドラッグして並べ替え・タップでプレビュー',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    super.key,
    required this.photo,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  final PhotoItem photo;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: SizedBox.square(
        dimension: _thumbSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(photo.path),
                    fit: BoxFit.cover,
                    cacheWidth: (_thumbSize * dpr).round(),
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                      semanticLabel: '削除',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
