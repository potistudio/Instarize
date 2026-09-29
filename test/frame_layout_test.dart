import 'package:flutter_test/flutter_test.dart';
import 'package:instarize/core/frame_layout.dart';
import 'package:instarize/models/caption_settings.dart';
import 'package:instarize/models/frame_settings.dart';

void main() {
  const noCaption = CaptionSettings(enabled: false);

  group('computeFrameLayout', () {
    test('uniform margin is a ratio of the short side on every side', () {
      final layout = computeFrameLayout(
        photoWidth: 4000,
        photoHeight: 3000,
        frame: const FrameSettings(marginRatio: 0.05),
        caption: noCaption,
      );
      expect(layout.canvasWidth, 4300);
      expect(layout.canvasHeight, 3300);
      expect(layout.photo, const PixelRect(150, 150, 4000, 3000));
      expect(layout.captionBox, const PixelRect(150, 3150, 4000, 150));
      expect(layout.fontSize, 0);
    });

    test('same settings give the same proportions at any resolution', () {
      const frame = FrameSettings(
        style: FrameStyle.captionBand,
        marginRatio: 0.04,
        bottomRatio: 0.2,
      );
      const caption = CaptionSettings(sizeRatio: 0.03);
      final large = computeFrameLayout(
        photoWidth: 6000,
        photoHeight: 4000,
        frame: frame,
        caption: caption,
      );
      final small = computeFrameLayout(
        photoWidth: 1500,
        photoHeight: 1000,
        frame: frame,
        caption: caption,
      );
      expect(large.canvasWidth / small.canvasWidth, closeTo(4, 1e-9));
      expect(large.canvasHeight / small.canvasHeight, closeTo(4, 1e-9));
      expect(large.photo.left / small.photo.left, closeTo(4, 1e-9));
      expect(large.captionBox.height / small.captionBox.height, 4);
      expect(large.fontSize / small.fontSize, closeTo(4, 1e-9));
    });

    test('portrait photos use the short side (width) as the base', () {
      final layout = computeFrameLayout(
        photoWidth: 3000,
        photoHeight: 4000,
        frame: const FrameSettings(marginRatio: 0.1),
        caption: noCaption,
      );
      expect(layout.photo.left, 300);
      expect(layout.canvasWidth, 3600);
      expect(layout.canvasHeight, 4600);
    });

    test('caption band sets the bottom height', () {
      final layout = computeFrameLayout(
        photoWidth: 1000,
        photoHeight: 1000,
        frame: const FrameSettings(
          style: FrameStyle.captionBand,
          marginRatio: 0.03,
          bottomRatio: 0.2,
        ),
        caption: const CaptionSettings(sizeRatio: 0.03),
      );
      expect(layout.photo, const PixelRect(30, 30, 1000, 1000));
      expect(layout.captionBox, const PixelRect(30, 1030, 1000, 200));
      expect(layout.canvasHeight, 30 + 1000 + 200);
      expect(layout.fontSize, closeTo(30, 1e-9));
    });

    test('a thin bottom grows to fit the caption line', () {
      final layout = computeFrameLayout(
        photoWidth: 2000,
        photoHeight: 1000,
        frame: const FrameSettings(marginRatio: 0.02),
        caption: const CaptionSettings(sizeRatio: 0.05),
      );
      // font 50px, line 62.5px, padding max(10, 20) on each side.
      expect(layout.captionBox.height, 103);
      expect(layout.captionBox.top, 20 + 1000);
      expect(layout.canvasHeight, 20 + 1000 + 103);
      // Sides and top keep the plain margin.
      expect(layout.photo.left, 20);
      expect(layout.canvasWidth, 2040);
    });

    test('caption area does not depend on caption text', () {
      // Layout takes no text at all, so photos with and without EXIF match.
      final a = computeFrameLayout(
        photoWidth: 800,
        photoHeight: 600,
        frame: const FrameSettings(),
        caption: const CaptionSettings(),
      );
      final b = computeFrameLayout(
        photoWidth: 800,
        photoHeight: 600,
        frame: const FrameSettings(),
        caption: const CaptionSettings(template: ''),
      );
      expect(a.captionBox, b.captionBox);
    });

    for (final (aspect, width, height) in [
      (AspectPreset.square, 4000, 3000),
      (AspectPreset.square, 3000, 4000),
      (AspectPreset.portrait, 4000, 3000),
      (AspectPreset.portrait, 3000, 4000),
      (AspectPreset.story, 4000, 3000),
      (AspectPreset.story, 1080, 2400),
    ]) {
      test('aspect ${aspect.label} pads ${width}x$height without cropping', () {
        final layout = computeFrameLayout(
          photoWidth: width,
          photoHeight: height,
          frame: FrameSettings(
            style: FrameStyle.aspect,
            aspect: aspect,
            marginRatio: 0.03,
          ),
          caption: const CaptionSettings(sizeRatio: 0.02),
        );
        final ratio = layout.canvasWidth / layout.canvasHeight;
        expect(ratio, closeTo(aspect.ratio, 1 / layout.canvasHeight + 1e-3));
        // Photo is fully inside with at least the margin on every side.
        final margin = (0.03 * (width < height ? width : height)).round();
        expect(layout.photo.width, width);
        expect(layout.photo.height, height);
        expect(layout.photo.left, greaterThanOrEqualTo(margin));
        expect(layout.photo.top, greaterThanOrEqualTo(margin));
        expect(
          layout.canvasWidth - layout.photo.right,
          greaterThanOrEqualTo(margin),
        );
        expect(layout.captionBox.top, layout.photo.bottom);
        expect(
          layout.captionBox.bottom,
          lessThanOrEqualTo(layout.canvasHeight),
        );
        // Content block is centred.
        final leftGap = layout.photo.left;
        final rightGap = layout.canvasWidth - layout.photo.right;
        expect((leftGap - rightGap).abs(), lessThanOrEqualTo(1));
      });
    }

    test('square photo in a square frame needs no extra padding', () {
      final layout = computeFrameLayout(
        photoWidth: 1000,
        photoHeight: 1000,
        frame: const FrameSettings(
          style: FrameStyle.aspect,
          aspect: AspectPreset.square,
          marginRatio: 0.05,
        ),
        caption: noCaption,
      );
      expect(layout.canvasWidth, 1100);
      expect(layout.canvasHeight, 1100);
      expect(layout.photo, const PixelRect(50, 50, 1000, 1000));
    });

    test('rejects empty photos', () {
      expect(
        () => computeFrameLayout(
          photoWidth: 0,
          photoHeight: 10,
          frame: const FrameSettings(),
          caption: noCaption,
        ),
        throwsArgumentError,
      );
    });
  });

  group('placeCaption', () {
    const box = PixelRect(100, 1000, 800, 60);

    test('aligns horizontally and centres vertically', () {
      final left = placeCaption(
        box: box,
        textWidth: 200,
        textHeight: 20,
        align: CaptionAlign.left,
      );
      expect(left.left, 100);
      expect(left.top, 1020);
      expect(left.scale, 1);

      final center = placeCaption(
        box: box,
        textWidth: 200,
        textHeight: 20,
        align: CaptionAlign.center,
      );
      expect(center.left, 400);

      final right = placeCaption(
        box: box,
        textWidth: 200,
        textHeight: 20,
        align: CaptionAlign.right,
      );
      expect(right.left + right.width, 900);
    });

    test('scales overly wide text down to the box width', () {
      final placement = placeCaption(
        box: box,
        textWidth: 1600,
        textHeight: 40,
        align: CaptionAlign.center,
      );
      expect(placement.scale, 0.5);
      expect(placement.width, 800);
      expect(placement.height, 20);
      expect(placement.left, 100);
      expect(placement.top, 1020);
    });
  });
}
