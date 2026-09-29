import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/photo_exif.dart';

class PhotoMetadata {
  const PhotoMetadata({
    required this.width,
    required this.height,
    required this.exif,
  });

  /// Size after applying the EXIF orientation.
  final int width;
  final int height;
  final PhotoExif exif;
}

class UnsupportedPhotoException implements Exception {
  const UnsupportedPhotoException(this.path);
  final String path;

  @override
  String toString() => 'Unsupported image format: $path';
}

// EXIF tag ids (TIFF / Exif 2.3).
const _tagMake = 0x010F;
const _tagModel = 0x0110;
const _tagOrientation = 0x0112;
const _tagExposureTime = 0x829A;
const _tagFNumber = 0x829D;
const _tagIso = 0x8827;
const _tagDateTimeOriginal = 0x9003;
const _tagShutterSpeedValue = 0x9201;
const _tagApertureValue = 0x9202;
const _tagFocalLength = 0x920A;
const _tagFocalLength35mm = 0xA405;
const _tagLensModel = 0xA434;

/// Tags copied into exported files. Maker notes, GPS and thumbnails are left
/// out: their offsets break when re-encoded and they are not needed on SNS.
const kPreservedImageTags = [_tagMake, _tagModel];
const kPreservedExifTags = [
  _tagExposureTime,
  _tagFNumber,
  _tagIso,
  _tagDateTimeOriginal,
  0x9011, // OffsetTimeOriginal
  _tagShutterSpeedValue,
  _tagApertureValue,
  _tagFocalLength,
  _tagFocalLength35mm,
  0xA433, // LensMake
  _tagLensModel,
];

/// Reads size and shooting information without decoding pixel data.
/// Runs in a background isolate.
PhotoMetadata readPhotoMetadata(String path) =>
    readPhotoMetadataFromBytes(File(path).readAsBytesSync(), path);

PhotoMetadata readPhotoMetadataFromBytes(Uint8List bytes, String path) {
  final isJpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  final decoder = isJpeg ? img.JpegDecoder() : img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) {
    throw UnsupportedPhotoException(path);
  }

  final exifData = isJpeg ? img.decodeJpgExif(bytes) : null;
  final orientation = exifData?.imageIfd[_tagOrientation]?.toInt() ?? 1;
  final swap = orientation >= 5 && orientation <= 8;
  return PhotoMetadata(
    width: swap ? info.height : info.width,
    height: swap ? info.width : info.height,
    exif: exifData == null ? PhotoExif.empty : photoExifFrom(exifData),
  );
}

PhotoExif photoExifFrom(img.ExifData data) {
  final ifd0 = data.imageIfd;
  final exif = data.exifIfd;

  String? text(img.IfdDirectory dir, int tag) {
    final value = dir[tag];
    return value is img.IfdValueAscii ? value.value : null;
  }

  double? number(img.IfdDirectory dir, int tag) {
    final value = dir[tag];
    if (value == null) return null;
    return switch (value) {
      img.IfdValueRational() || img.IfdValueSRational() =>
        value.toRational().denominator == 0
            ? null
            : value.toRational().numerator / value.toRational().denominator,
      img.IfdValueSingle() || img.IfdValueDouble() => value.toDouble(),
      img.IfdByteValue() ||
      img.IfdValueShort() ||
      img.IfdValueLong() ||
      img.IfdValueSShort() ||
      img.IfdValueSLong() => value.toInt().toDouble(),
      _ => null,
    };
  }

  var exposure = number(exif, _tagExposureTime);
  if (exposure == null) {
    final apex = number(exif, _tagShutterSpeedValue);
    if (apex != null) exposure = math.pow(2, -apex).toDouble();
  }
  var aperture = number(exif, _tagFNumber);
  if (aperture == null) {
    final apex = number(exif, _tagApertureValue);
    if (apex != null) aperture = math.pow(math.sqrt2, apex).toDouble();
  }
  final iso = number(exif, _tagIso);
  final focal35 = number(exif, _tagFocalLength35mm);

  return PhotoExif(
    make: text(ifd0, _tagMake),
    model: text(ifd0, _tagModel),
    lensModel: text(exif, _tagLensModel),
    focalLength: number(exif, _tagFocalLength),
    focalLength35mm: focal35?.round(),
    fNumber: aperture,
    exposureTime: exposure,
    iso: iso?.round(),
    dateTimeOriginal: parseExifDateTime(text(exif, _tagDateTimeOriginal)),
  );
}

/// Parses the EXIF `YYYY:MM:DD HH:MM:SS` format.
DateTime? parseExifDateTime(String? value) {
  final match = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(value?.trim() ?? '');
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i) ?? '0')];
  if (parts[0] == 0 || parts[1] == 0 || parts[2] == 0) return null;
  return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
}
