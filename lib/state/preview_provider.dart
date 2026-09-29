import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Longest side of the downscaled image used for on-screen previews.
const int kPreviewMaxSide = 1600;

/// Downscaled, upright preview image for the photo at a path.
///
/// The engine decodes off the UI thread, applies the EXIF orientation and
/// scales during decode, so full-resolution pixels never reach Dart. Auto
/// dispose keeps only the pages currently built by the pager in memory.
final previewImageProvider = FutureProvider.autoDispose
    .family<ui.Image, String>((ref, path) async {
      final buffer = await ui.ImmutableBuffer.fromFilePath(path);
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          final scale = kPreviewMaxSide / math.max(width, height);
          if (scale >= 1) return ui.TargetImageSize(width: width);
          return ui.TargetImageSize(
            width: math.max(1, (width * scale).round()),
            height: math.max(1, (height * scale).round()),
          );
        },
      );
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        ref.onDispose(image.dispose);
        return image;
      } finally {
        codec.dispose();
      }
    });
