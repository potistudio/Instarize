/// Shooting information read from a photo's EXIF block. Every field is
/// optional because phones, scanners and editors drop tags freely.
class PhotoExif {
  const PhotoExif({
    this.make,
    this.model,
    this.lensModel,
    this.focalLength,
    this.focalLength35mm,
    this.fNumber,
    this.exposureTime,
    this.iso,
    this.dateTimeOriginal,
  });

  static const empty = PhotoExif();

  final String? make;
  final String? model;
  final String? lensModel;

  /// Millimetres.
  final double? focalLength;
  final int? focalLength35mm;
  final double? fNumber;

  /// Seconds.
  final double? exposureTime;
  final int? iso;

  /// Wall-clock time as recorded by the camera (no time zone).
  final DateTime? dateTimeOriginal;
}
