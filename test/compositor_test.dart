import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:instarize/core/cancellable_isolate.dart';
import 'package:instarize/core/compositor.dart';
import 'package:instarize/core/frame_layout.dart';
import 'package:instarize/core/photo_metadata.dart';
import 'package:instarize/models/caption_settings.dart';
import 'package:instarize/models/frame_settings.dart';

const _noCaption = CaptionSettings(enabled: false);

/// 40x20 photo: left half red, right half blue, shot on "TestCam".
Uint8List _rotatedJpeg({required int orientation}) {
  final src = img.Image(width: 40, height: 20);
  for (var y = 0; y < 20; y++) {
    for (var x = 0; x < 40; x++) {
      src.setPixelRgb(x, y, x < 20 ? 255 : 0, 0, x < 20 ? 0 : 255);
    }
  }
  src.exif.imageIfd
    ..orientation = orientation
    ..['Make'] = 'FUJIFILM'
    ..['Model'] = 'TestCam';
  src.exif.exifIfd
    ..['ExposureTime'] = [1, 250]
    ..['FNumber'] = [14, 10]
    ..[0x920A] = img.IfdValueRational(35, 1)
    ..[0x8827] = img.IfdValueShort(400)
    ..['DateTimeOriginal'] = '2024:05:03 14:05:09';
  src.exif.gpsIfd[0x0001] = img.IfdValueAscii('N');
  return img.encodeJpg(src, quality: 100);
}

bool _near(img.Pixel p, int r, int g, int b, {int tolerance = 40}) =>
    (p.r - r).abs() <= tolerance &&
    (p.g - g).abs() <= tolerance &&
    (p.b - b).abs() <= tolerance;

void _spinForever(int _) {
  while (true) {}
}

void _fail(int _) => throw StateError('boom');

void _noop(int _) {}

void main() {
  group('metadata', () {
    test('reports upright size and shooting info without decoding', () {
      final meta = readPhotoMetadataFromBytes(
        _rotatedJpeg(orientation: 6),
        'x.jpg',
      );
      expect(meta.width, 20);
      expect(meta.height, 40);
      expect(meta.exif.make, 'FUJIFILM');
      expect(meta.exif.model, 'TestCam');
      expect(meta.exif.exposureTime, closeTo(1 / 250, 1e-9));
      expect(meta.exif.fNumber, closeTo(1.4, 1e-9));
      expect(meta.exif.focalLength, 35);
      expect(meta.exif.iso, 400);
      expect(meta.exif.dateTimeOriginal, DateTime(2024, 5, 3, 14, 5, 9));
    });

    test('non-JPEG images have no EXIF but a size', () {
      final png = img.encodePng(img.Image(width: 7, height: 3));
      final meta = readPhotoMetadataFromBytes(png, 'x.png');
      expect((meta.width, meta.height), (7, 3));
      expect(meta.exif.model, isNull);
    });

    test('rejects unknown formats', () {
      expect(
        () => readPhotoMetadataFromBytes(
          Uint8List.fromList(List.filled(64, 7)),
          'x.heic',
        ),
        throwsA(isA<UnsupportedPhotoException>()),
      );
    });

    test('parses EXIF date strings', () {
      expect(
        parseExifDateTime('2023:12:31 23:59:58'),
        DateTime(2023, 12, 31, 23, 59, 58),
      );
      expect(parseExifDateTime('0000:00:00 00:00:00'), isNull);
      expect(parseExifDateTime(null), isNull);
    });
  });

  group('composeFrame', () {
    test('fills the frame and copies the photo 1:1 at the layout offset', () {
      final photo = img.Image(width: 4, height: 2);
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 4; x++) {
          photo.setPixelRgb(x, y, x * 60, y * 100, 7);
        }
      }
      final layout = computeFrameLayout(
        photoWidth: 4,
        photoHeight: 2,
        frame: const FrameSettings(marginRatio: 0.5),
        caption: _noCaption,
      );
      final out = composeFrame(
        photo: photo,
        layout: layout,
        frameColor: 0xFF102030,
        tiles: const [],
      );
      expect((out.width, out.height), (6, 4));
      final frame = out.getPixel(0, 0);
      expect([frame.r, frame.g, frame.b], [0x10, 0x20, 0x30]);
      final corner = out.getPixel(5, 3);
      expect([corner.r, corner.g, corner.b], [0x10, 0x20, 0x30]);
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 4; x++) {
          final p = out.getPixel(1 + x, 1 + y);
          expect([p.r, p.g, p.b], [x * 60, y * 100, 7]);
        }
      }
    });

    test('blends straight-alpha caption tiles over the frame', () {
      final layout = computeFrameLayout(
        photoWidth: 2,
        photoHeight: 2,
        frame: const FrameSettings(marginRatio: 1),
        caption: _noCaption,
      );
      final out = composeFrame(
        photo: img.Image(width: 2, height: 2),
        layout: layout,
        frameColor: 0xFFFFFFFF,
        tiles: [
          TextTile(
            left: 0,
            top: 0,
            width: 2,
            height: 1,
            rgba: Uint8List.fromList([255, 0, 0, 255, 0, 0, 0, 128]),
          ),
        ],
      );
      final opaque = out.getPixel(0, 0);
      expect([opaque.r, opaque.g, opaque.b], [255, 0, 0]);
      final half = out.getPixel(1, 0);
      expect([half.r, half.g, half.b], [127, 127, 127]);
      final untouched = out.getPixel(0, 1);
      expect([untouched.r, untouched.g, untouched.b], [255, 255, 255]);
    });

    test('transparent PNG pixels show the frame colour', () {
      final photo = img.Image(width: 1, height: 1, numChannels: 4)
        ..setPixelRgba(0, 0, 0, 0, 0, 0);
      final layout = computeFrameLayout(
        photoWidth: 1,
        photoHeight: 1,
        frame: const FrameSettings(marginRatio: 1),
        caption: _noCaption,
      );
      final out = composeFrame(
        photo: photo,
        layout: layout,
        frameColor: 0xFF00FF00,
        tiles: const [],
      );
      final p = out.getPixel(1, 1);
      expect([p.r, p.g, p.b], [0, 255, 0]);
    });
  });

  group('runComposeJob', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('instarize_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    for (final orientation in [1, 3, 6, 8]) {
      test('applies EXIF orientation $orientation before framing', () {
        final source = File('${dir.path}/in.jpg')
          ..writeAsBytesSync(_rotatedJpeg(orientation: orientation));
        final meta = readPhotoMetadata(source.path);
        final layout = computeFrameLayout(
          photoWidth: meta.width,
          photoHeight: meta.height,
          frame: const FrameSettings(marginRatio: 0.25),
          caption: _noCaption,
        );
        final output = '${dir.path}/out.jpg';
        runComposeJob(
          ComposeJob(
            sourcePath: source.path,
            outputPath: output,
            layout: layout,
            frameColor: 0xFFFFFFFF,
            tiles: const [],
          ),
        );

        final bytes = File(output).readAsBytesSync();
        final result = img.decodeJpg(bytes)!;
        expect(
          (result.width, result.height),
          (layout.canvasWidth, layout.canvasHeight),
        );

        // Where the red (originally left) half must end up once upright.
        final photo = layout.photo;
        final (redX, redY) = switch (orientation) {
          6 => (photo.left + photo.width ~/ 2, photo.top + 3),
          8 => (photo.left + photo.width ~/ 2, photo.bottom - 4),
          3 => (photo.right - 4, photo.top + photo.height ~/ 2),
          _ => (photo.left + 3, photo.top + photo.height ~/ 2),
        };
        expect(_near(result.getPixel(redX, redY), 255, 0, 0), isTrue);
        expect(_near(result.getPixel(0, 0), 255, 255, 255), isTrue);

        final exif = img.decodeJpgExif(bytes)!;
        expect(exif.imageIfd.hasOrientation, isFalse);
        expect(exif.imageIfd['Model']?.toString(), 'TestCam');
        expect(exif.exifIfd['FNumber']?.toRational().numerator, 14);
        expect(exif.gpsIfd.isEmpty, isTrue);
      });
    }
  });

  group('runCancellable', () {
    test('completes when the task finishes', () async {
      await runCancellable(_noop, 0, CancelToken());
    });

    test('forwards task errors', () async {
      await expectLater(
        runCancellable(_fail, 0, CancelToken()),
        throwsA(isA<RemoteError>()),
      );
    });

    test('kills a running task on cancel', () async {
      final token = CancelToken();
      final future = runCancellable(_spinForever, 0, token);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      token.cancel();
      await expectLater(
        future.timeout(const Duration(seconds: 5)),
        throwsA(isA<CancelledException>()),
      );
    });
  });
}
