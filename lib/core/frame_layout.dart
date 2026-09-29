import 'dart:math' as math;

import '../models/caption_settings.dart';
import '../models/frame_settings.dart';

/// Line box height reserved for a caption, as a multiple of the font size.
/// Must match the `height` used when the caption text is laid out.
const double kCaptionLineHeight = 1.25;

/// Axis-aligned rectangle in output pixels.
class PixelRect {
  const PixelRect(this.left, this.top, this.width, this.height);

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width;
  int get bottom => top + height;

  @override
  bool operator ==(Object other) =>
      other is PixelRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'PixelRect($left, $top, ${width}x$height)';
}

/// Geometry of one framed photo at the photo's native resolution.
///
/// Both the on-screen preview (scaled down) and the exporter (1:1) are driven
/// by this single result, so they cannot drift apart.
class FrameLayout {
  const FrameLayout({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.photo,
    required this.captionBox,
    required this.fontSize,
  });

  final int canvasWidth;
  final int canvasHeight;

  /// Where the photo is drawn; always the photo's own pixel size.
  final PixelRect photo;

  /// The band below the photo in which the caption is vertically centred.
  /// Horizontally it is aligned with the photo edges.
  final PixelRect captionBox;

  /// Caption font size in output pixels; 0 when captions are disabled.
  final double fontSize;
}

FrameLayout computeFrameLayout({
  required int photoWidth,
  required int photoHeight,
  required FrameSettings frame,
  required CaptionSettings caption,
}) {
  if (photoWidth <= 0 || photoHeight <= 0) {
    throw ArgumentError(
      'Photo size must be positive: ${photoWidth}x$photoHeight',
    );
  }
  final shortSide = math.min(photoWidth, photoHeight);
  final margin = (frame.marginRatio * shortSide).round();
  final fontSize = caption.enabled ? caption.sizeRatio * shortSide : 0.0;

  var bottom = switch (frame.style) {
    FrameStyle.captionBand => (frame.bottomRatio * shortSide).round(),
    FrameStyle.uniform || FrameStyle.aspect => margin,
  };
  if (caption.enabled) {
    // The caption area depends only on settings, never on the text, so
    // photos with and without EXIF still get identical frames.
    final padding = math.max(margin * 0.5, fontSize * 0.4);
    final needed = (fontSize * kCaptionLineHeight + padding * 2).round();
    bottom = math.max(bottom, needed);
  }

  final contentWidth = photoWidth + margin * 2;
  final contentHeight = margin + photoHeight + bottom;

  var canvasWidth = contentWidth;
  var canvasHeight = contentHeight;
  if (frame.style == FrameStyle.aspect) {
    final target = frame.aspect.ratio;
    if (contentWidth / contentHeight > target) {
      canvasHeight = math.max(contentHeight, (contentWidth / target).round());
    } else {
      canvasWidth = math.max(contentWidth, (contentHeight * target).round());
    }
  }

  final offsetX = (canvasWidth - contentWidth) ~/ 2;
  final offsetY = (canvasHeight - contentHeight) ~/ 2;

  return FrameLayout(
    canvasWidth: canvasWidth,
    canvasHeight: canvasHeight,
    photo: PixelRect(
      offsetX + margin,
      offsetY + margin,
      photoWidth,
      photoHeight,
    ),
    captionBox: PixelRect(
      offsetX + margin,
      offsetY + margin + photoHeight,
      photoWidth,
      bottom,
    ),
    fontSize: fontSize,
  );
}

/// Where a laid-out caption line of [textWidth] x [textHeight] goes inside
/// [box]. Text wider than the box is scaled down uniformly to fit.
class CaptionPlacement {
  const CaptionPlacement({
    required this.left,
    required this.top,
    required this.scale,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double scale;

  /// Size after scaling.
  final double width;
  final double height;
}

CaptionPlacement placeCaption({
  required PixelRect box,
  required double textWidth,
  required double textHeight,
  required CaptionAlign align,
}) {
  final scale = textWidth > box.width && textWidth > 0
      ? box.width / textWidth
      : 1.0;
  final width = textWidth * scale;
  final height = textHeight * scale;
  final left = switch (align) {
    CaptionAlign.left => box.left.toDouble(),
    CaptionAlign.center => box.left + (box.width - width) / 2,
    CaptionAlign.right => box.right - width,
  };
  return CaptionPlacement(
    left: left,
    top: box.top + (box.height - height) / 2,
    scale: scale,
    width: width,
    height: height,
  );
}
