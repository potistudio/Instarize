import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'frame_layout.dart';
import 'photo_metadata.dart';

const int kExportJpegQuality = 95;

/// A rasterised piece of the caption, positioned in output pixels.
/// Pixels are straight (non-premultiplied) RGBA.
class TextTile {
  const TextTile({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int left;
  final int top;
  final int width;
  final int height;
  final Uint8List rgba;
}

/// Everything the background isolate needs to produce one output file.
class ComposeJob {
  ComposeJob({
    required this.sourcePath,
    required this.outputPath,
    required this.layout,
    required this.frameColor,
    required List<TextTile> tiles,
    this.quality = kExportJpegQuality,
  }) : _tiles = [
         for (final tile in tiles)
           (
             tile.left,
             tile.top,
             tile.width,
             tile.height,
             TransferableTypedData.fromList([tile.rgba]),
           ),
       ];

  final String sourcePath;
  final String outputPath;
  final FrameLayout layout;

  /// 0xAARRGGBB; alpha is ignored because JPEG has none.
  final int frameColor;
  final int quality;
  final List<(int, int, int, int, TransferableTypedData)> _tiles;

  /// Can be called only once, inside the receiving isolate.
  List<TextTile> takeTiles() => [
    for (final (left, top, width, height, data) in _tiles)
      TextTile(
        left: left,
        top: top,
        width: width,
        height: height,
        rgba: data.materialize().asUint8List(),
      ),
  ];
}

/// Decodes, frames and encodes one photo at full resolution.
/// Runs in a background isolate; peak memory is roughly source + output.
void runComposeJob(ComposeJob job) {
  final bytes = File(job.sourcePath).readAsBytesSync();
  var photo = decodeOriented(bytes);
  final expected = job.layout.photo;
  if (photo.width != expected.width || photo.height != expected.height) {
    throw StateError(
      'Decoded size ${photo.width}x${photo.height} does not match '
      'the layout ${expected.width}x${expected.height}',
    );
  }

  final canvas = composeFrame(
    photo: photo,
    layout: job.layout,
    frameColor: job.frameColor,
    tiles: job.takeTiles(),
  );
  canvas.exif = preservedExif(photo.exif);
  canvas.iccProfile = photo.iccProfile;
  photo = img.Image.empty(); // release the source pixels before encoding

  final jpeg = img.encodeJpg(
    canvas,
    quality: job.quality,
    chroma: img.JpegChroma.yuv444,
  );
  File(job.outputPath).writeAsBytesSync(jpeg, flush: true);
}

/// Decodes [bytes] and applies the EXIF orientation so the pixels are
/// upright. The JPEG decoder bakes the orientation in while decoding (and
/// clears the tag); other formats are rotated afterwards.
img.Image decodeOriented(Uint8List bytes) {
  final isJpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  final image = isJpeg ? img.decodeJpg(bytes) : img.decodeImage(bytes);
  if (image == null) throw const UnsupportedPhotoException('<bytes>');
  final orientation = image.exif.imageIfd.orientation ?? 1;
  return orientation == 1 ? image : img.bakeOrientation(image);
}

img.Image composeFrame({
  required img.Image photo,
  required FrameLayout layout,
  required int frameColor,
  required List<TextTile> tiles,
}) {
  final width = layout.canvasWidth;
  final height = layout.canvasHeight;
  final canvas = img.Image(width: width, height: height, numChannels: 3);
  final out = canvas.data!.toUint8List();
  final fr = (frameColor >> 16) & 0xFF;
  final fg = (frameColor >> 8) & 0xFF;
  final fb = frameColor & 0xFF;

  final row = Uint8List(width * 3);
  for (var x = 0; x < row.length; x += 3) {
    row[x] = fr;
    row[x + 1] = fg;
    row[x + 2] = fb;
  }
  for (var y = 0; y < height; y++) {
    out.setRange(y * row.length, (y + 1) * row.length, row);
  }

  _drawPhoto(out, width, photo, layout.photo, fr, fg, fb);
  for (final tile in tiles) {
    _blendTile(out, width, height, tile);
  }
  return canvas;
}

void _drawPhoto(
  Uint8List out,
  int canvasWidth,
  img.Image photo,
  PixelRect rect,
  int fr,
  int fg,
  int fb,
) {
  final stride = canvasWidth * 3;
  final isPlainRgb =
      photo.format == img.Format.uint8 &&
      !photo.hasPalette &&
      photo.numChannels == 3;
  if (isPlainRgb) {
    final src = photo.data!.toUint8List();
    final rowBytes = rect.width * 3;
    for (var y = 0; y < rect.height; y++) {
      final dst = (rect.top + y) * stride + rect.left * 3;
      out.setRange(dst, dst + rowBytes, src, y * rowBytes);
    }
    return;
  }

  // Grey, palette, 16-bit or alpha images: normalise and blend over the frame.
  // (Passing `alpha:` here would overwrite existing transparency.)
  final rgba = photo
      .convert(format: img.Format.uint8, numChannels: 4)
      .data!
      .toUint8List();
  for (var y = 0; y < rect.height; y++) {
    var s = y * rect.width * 4;
    var d = (rect.top + y) * stride + rect.left * 3;
    for (var x = 0; x < rect.width; x++, s += 4, d += 3) {
      final a = rgba[s + 3];
      final ia = 255 - a;
      out[d] = (rgba[s] * a + fr * ia + 127) ~/ 255;
      out[d + 1] = (rgba[s + 1] * a + fg * ia + 127) ~/ 255;
      out[d + 2] = (rgba[s + 2] * a + fb * ia + 127) ~/ 255;
    }
  }
}

void _blendTile(Uint8List out, int canvasWidth, int canvasHeight, TextTile t) {
  final stride = canvasWidth * 3;
  for (var y = 0; y < t.height; y++) {
    final cy = t.top + y;
    if (cy < 0 || cy >= canvasHeight) continue;
    for (var x = 0; x < t.width; x++) {
      final cx = t.left + x;
      if (cx < 0 || cx >= canvasWidth) continue;
      final s = (y * t.width + x) * 4;
      final a = t.rgba[s + 3];
      if (a == 0) continue;
      final d = cy * stride + cx * 3;
      final ia = 255 - a;
      out[d] = (t.rgba[s] * a + out[d] * ia + 127) ~/ 255;
      out[d + 1] = (t.rgba[s + 1] * a + out[d + 1] * ia + 127) ~/ 255;
      out[d + 2] = (t.rgba[s + 2] * a + out[d + 2] * ia + 127) ~/ 255;
    }
  }
}

/// Copies the shooting information the caption is based on. Orientation is
/// not copied: the pixels are already upright.
img.ExifData preservedExif(img.ExifData source) {
  final result = img.ExifData();
  for (final tag in kPreservedImageTags) {
    final value = source.imageIfd[tag];
    if (value != null) result.imageIfd[tag] = value.clone();
  }
  final sourceExif = source.imageIfd.sub.containsKey('exif')
      ? source.exifIfd
      : null;
  if (sourceExif != null) {
    for (final tag in kPreservedExifTags) {
      final value = sourceExif[tag];
      if (value != null) result.exifIfd[tag] = value.clone();
    }
  }
  return result;
}
