import 'photo_exif.dart';

class PhotoItem {
  const PhotoItem({
    required this.id,
    required this.path,
    required this.width,
    required this.height,
    required this.exif,
    this.captionOverride,
  });

  final String id;
  final String path;

  /// Pixel size after the EXIF orientation has been applied.
  final int width;
  final int height;

  final PhotoExif exif;

  /// Replaces the shared caption template for this photo only. It may itself
  /// contain template variables.
  final String? captionOverride;

  PhotoItem withCaptionOverride(String? value) => PhotoItem(
    id: id,
    path: path,
    width: width,
    height: height,
    exif: exif,
    captionOverride: value,
  );
}
