import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/caption_settings.dart';
import '../models/photo_item.dart';
import 'caption_template.dart';
import 'compositor.dart';
import 'frame_layout.dart';

/// Tiles stay well under the smallest GPU texture limit we expect (4096).
const int _maxTileSize = 2048;

/// The caption text for [photo]; empty when captions are disabled.
String captionTextFor(PhotoItem photo, CaptionSettings settings) {
  if (!settings.enabled) return '';
  final template = photo.captionOverride ?? settings.template;
  return renderCaptionTemplate(template, captionValues(photo.exif));
}

/// A caption laid out at output resolution. Used by the preview (drawn on a
/// scaled canvas) and by the exporter (rasterised 1:1), so text metrics and
/// position are identical in both.
class PreparedCaption {
  PreparedCaption._(this._painter, this.placement, this._overhang);

  static PreparedCaption? create({
    required FrameLayout layout,
    required String text,
    required CaptionSettings settings,
  }) {
    final line = text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    if (!settings.enabled || line.isEmpty || layout.fontSize <= 0) return null;
    final painter = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          fontFamily: settings.font.family,
          fontWeight: settings.font.weight,
          fontSize: layout.fontSize,
          height: kCaptionLineHeight,
          leadingDistribution: TextLeadingDistribution.even,
          color: settings.color,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    final placement = placeCaption(
      box: layout.captionBox,
      textWidth: painter.width,
      textHeight: painter.height,
      align: settings.align,
    );
    return PreparedCaption._(painter, placement, layout.fontSize * 0.3);
  }

  final TextPainter _painter;
  final CaptionPlacement placement;
  final double _overhang;

  /// Paints in output-pixel coordinates.
  void paint(Canvas canvas) {
    canvas
      ..save()
      ..translate(placement.left, placement.top)
      ..scale(placement.scale);
    _painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  /// Output-pixel bounds including room for glyph overhang.
  Rect get bounds => Rect.fromLTWH(
    placement.left,
    placement.top,
    placement.width,
    placement.height,
  ).inflate(_overhang * placement.scale);

  void dispose() => _painter.dispose();
}

/// Rasterises [caption] at output resolution into straight-alpha RGBA tiles
/// covering only the text, for compositing in the export isolate.
Future<List<TextTile>> rasterizeCaption(
  PreparedCaption caption,
  FrameLayout layout,
) async {
  final bounds = caption.bounds;
  final left = math.max(0, bounds.left.floor());
  final top = math.max(0, bounds.top.floor());
  final right = math.min(layout.canvasWidth, bounds.right.ceil());
  final bottom = math.min(layout.canvasHeight, bounds.bottom.ceil());

  final tiles = <TextTile>[];
  for (var ty = top; ty < bottom; ty += _maxTileSize) {
    for (var tx = left; tx < right; tx += _maxTileSize) {
      final width = math.min(_maxTileSize, right - tx);
      final height = math.min(_maxTileSize, bottom - ty);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..translate(-tx.toDouble(), -ty.toDouble());
      caption.paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      image.dispose();
      picture.dispose();
      if (data == null) throw StateError('Failed to read caption pixels');
      tiles.add(
        TextTile(
          left: tx,
          top: ty,
          width: width,
          height: height,
          rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      );
    }
  }
  return tiles;
}
