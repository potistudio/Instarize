import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/caption_renderer.dart';
import '../core/frame_layout.dart';
import '../models/caption_settings.dart';
import '../models/photo_item.dart';
import '../state/photos_provider.dart';
import '../state/preview_provider.dart';
import '../state/settings_providers.dart';

/// Horizontally swipeable preview of every selected photo with the current
/// settings applied.
class PreviewPager extends ConsumerStatefulWidget {
  const PreviewPager({super.key});

  @override
  ConsumerState<PreviewPager> createState() => _PreviewPagerState();
}

class _PreviewPagerState extends ConsumerState<PreviewPager> {
  late final PageController _controller = PageController(
    initialPage: ref.read(currentIndexProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(photosProvider.select((s) => s.photos));
    final index = ref.watch(currentIndexProvider).clamp(0, photos.length - 1);

    // Follow selections made elsewhere (thumbnail taps, reorder, removal).
    ref.listen(currentIndexProvider, (_, next) {
      if (!_controller.hasClients) return;
      final page = _controller.page?.round();
      if (page == next) return;
      if (page != null && (page - next).abs() == 1) {
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _controller.jumpToPage(next);
      }
    });

    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: photos.length,
          onPageChanged: ref.read(currentIndexProvider.notifier).select,
          findChildIndexCallback: (key) {
            final i = photos.indexWhere((p) => ValueKey(p.id) == key);
            return i < 0 ? null : i;
          },
          itemBuilder: (context, i) =>
              FramedPhotoView(key: ValueKey(photos[i].id), photo: photos[i]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 4,
          child: Center(
            child: Text(
              '${index + 1} / ${photos.length}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FramedPhotoView extends ConsumerWidget {
  const FramedPhotoView({super.key, required this.photo});

  final PhotoItem photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frame = ref.watch(frameSettingsProvider);
    final caption = ref.watch(captionSettingsProvider);
    final image = ref.watch(previewImageProvider(photo.path));
    final layout = computeFrameLayout(
      photoWidth: photo.width,
      photoHeight: photo.height,
      frame: frame,
      caption: caption,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Center(
        child: AspectRatio(
          aspectRatio: layout.canvasWidth / layout.canvasHeight,
          child: switch (image) {
            AsyncData(:final value) => CustomPaint(
              painter: FramePainter(
                image: value,
                layout: layout,
                frameColor: frame.color,
                caption: caption,
                captionText: captionTextFor(photo, caption),
              ),
            ),
            AsyncError() => ColoredBox(
              color: frame.color,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
            _ => ColoredBox(
              color: frame.color,
              child: const Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// Paints the framed photo using the full-resolution [layout] on a scaled
/// canvas, i.e. exactly the geometry the exporter produces.
class FramePainter extends CustomPainter {
  FramePainter({
    required this.image,
    required this.layout,
    required this.frameColor,
    required this.caption,
    required this.captionText,
  });

  final ui.Image image;
  final FrameLayout layout;
  final Color frameColor;
  final CaptionSettings caption;
  final String captionText;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / layout.canvasWidth;
    canvas
      ..save()
      ..scale(scale)
      ..drawRect(
        Rect.fromLTWH(
          0,
          0,
          layout.canvasWidth.toDouble(),
          layout.canvasHeight.toDouble(),
        ),
        Paint()..color = frameColor,
      );

    final photo = layout.photo;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        photo.left.toDouble(),
        photo.top.toDouble(),
        photo.width.toDouble(),
        photo.height.toDouble(),
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );

    final prepared = PreparedCaption.create(
      layout: layout,
      text: captionText,
      settings: caption,
    );
    prepared?.paint(canvas);
    prepared?.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(FramePainter old) =>
      old.image != image ||
      old.frameColor != frameColor ||
      old.caption != caption ||
      old.captionText != captionText ||
      old.layout.canvasWidth != layout.canvasWidth ||
      old.layout.canvasHeight != layout.canvasHeight ||
      old.layout.photo != layout.photo ||
      old.layout.captionBox != layout.captionBox;
}
