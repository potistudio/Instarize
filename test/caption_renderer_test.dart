import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instarize/core/caption_renderer.dart';
import 'package:instarize/core/frame_layout.dart';
import 'package:instarize/models/caption_settings.dart';
import 'package:instarize/models/frame_settings.dart';
import 'package:instarize/models/photo_exif.dart';
import 'package:instarize/models/photo_item.dart';

void main() {
  const caption = CaptionSettings(
    sizeRatio: 0.05,
    color: Color(0xFF000000),
    align: CaptionAlign.left,
  );

  PhotoItem photo({String? override}) => PhotoItem(
    id: 'a',
    path: 'a.jpg',
    width: 3000,
    height: 2000,
    exif: const PhotoExif(model: 'X100V', fNumber: 2),
    captionOverride: override,
  );

  test('captionTextFor uses the template, the override or nothing', () {
    expect(captionTextFor(photo(), caption), 'X100V · f/2');
    expect(
      captionTextFor(photo(override: '{camera} in Kyoto'), caption),
      'X100V in Kyoto',
    );
    expect(captionTextFor(photo(override: ''), caption), '');
    expect(captionTextFor(photo(), caption.copyWith(enabled: false)), isEmpty);
  });

  testWidgets('rasterises the caption in tiles at the preview position', (
    tester,
  ) async {
    final layout = computeFrameLayout(
      photoWidth: 3000,
      photoHeight: 2000,
      frame: const FrameSettings(style: FrameStyle.captionBand),
      caption: caption,
    );
    final prepared = PreparedCaption.create(
      layout: layout,
      text: 'WIDE CAPTION ' * 8,
      settings: caption,
    )!;
    addTearDown(prepared.dispose);

    // Wider than one tile, and scaled down to the photo width.
    expect(prepared.placement.scale, lessThan(1));
    expect(prepared.placement.width, closeTo(layout.captionBox.width, 1e-6));
    expect(prepared.placement.left, layout.captionBox.left);

    final tiles = await tester.runAsync(
      () => rasterizeCaption(prepared, layout),
    );
    expect(tiles!.length, greaterThan(1));
    for (final tile in tiles) {
      expect(tile.width, lessThanOrEqualTo(2048));
      expect(tile.rgba.length, tile.width * tile.height * 4);
      expect(tile.left, greaterThanOrEqualTo(0));
      expect(tile.left + tile.width, lessThanOrEqualTo(layout.canvasWidth));
      expect(tile.top, greaterThanOrEqualTo(layout.photo.bottom));
      expect(tile.top + tile.height, lessThanOrEqualTo(layout.canvasHeight));
    }
    var inked = 0;
    for (final tile in tiles) {
      for (var i = 3; i < tile.rgba.length; i += 4) {
        if (tile.rgba[i] > 0) inked++;
      }
    }
    expect(inked, greaterThan(0));
  });

  test('empty text or disabled captions produce nothing to draw', () {
    final layout = computeFrameLayout(
      photoWidth: 100,
      photoHeight: 100,
      frame: const FrameSettings(),
      caption: caption,
    );
    expect(
      PreparedCaption.create(layout: layout, text: '  ', settings: caption),
      isNull,
    );
  });
}
