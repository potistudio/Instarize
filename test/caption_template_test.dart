import 'package:flutter_test/flutter_test.dart';
import 'package:instarize/core/caption_template.dart';
import 'package:instarize/models/caption_settings.dart';
import 'package:instarize/models/photo_exif.dart';

void main() {
  const template = CaptionSettings.defaultTemplate;
  const full = {
    'camera': 'X-T5',
    'focal': '35',
    'aperture': '1.4',
    'shutter': '1/250',
    'iso': '160',
  };

  Map<String, String?> without(List<String> keys) => {
    for (final e in full.entries) e.key: keys.contains(e.key) ? null : e.value,
  };

  group('renderCaptionTemplate', () {
    test('fills every variable', () {
      expect(
        renderCaptionTemplate(template, full),
        'X-T5 · 35mm f/1.4 1/250s ISO160',
      );
    });

    test('drops a missing leading variable with its separator', () {
      expect(
        renderCaptionTemplate(template, without(['camera'])),
        '35mm f/1.4 1/250s ISO160',
      );
    });

    test('drops attached units of missing variables', () {
      expect(
        renderCaptionTemplate(template, without(['focal', 'iso'])),
        'X-T5 · f/1.4 1/250s',
      );
    });

    test('drops a separator left trailing', () {
      expect(
        renderCaptionTemplate(
          template,
          without(['focal', 'aperture', 'shutter', 'iso']),
        ),
        'X-T5',
      );
    });

    test('everything missing gives an empty string', () {
      expect(renderCaptionTemplate(template, without(full.keys.toList())), '');
    });

    test('collapses doubled separators in the middle', () {
      const t = '{camera} · {lens} · {iso}';
      expect(
        renderCaptionTemplate(t, {'camera': 'A', 'lens': null, 'iso': '100'}),
        'A · 100',
      );
      expect(
        renderCaptionTemplate('{camera} | {lens} | {focal} | {iso}', {
          'camera': 'A',
          'lens': null,
          'focal': '',
          'iso': '100',
        }),
        'A | 100',
      );
    });

    test('keeps a separator that still divides remaining text', () {
      expect(
        renderCaptionTemplate('{camera} {lens} / {iso}', {
          'camera': 'A',
          'lens': null,
          'iso': '100',
        }),
        'A / 100',
      );
      expect(
        renderCaptionTemplate('{camera} / {lens} {iso}', {
          'camera': 'A',
          'lens': null,
          'iso': '100',
        }),
        'A / 100',
      );
    });

    test('keeps free text and decoration that is not dangling', () {
      expect(
        renderCaptionTemplate('Tokyo, 2024 — {camera}', {'camera': 'A'}),
        'Tokyo, 2024 — A',
      );
      expect(
        renderCaptionTemplate('Tokyo, 2024 — {camera}', {'camera': null}),
        'Tokyo, 2024',
      );
      expect(renderCaptionTemplate('📷 {camera}', {'camera': 'A'}), '📷 A');
      expect(renderCaptionTemplate('📷 {camera}', {'camera': null}), '');
    });

    test('handles separators inside a single word', () {
      const t = '{make}/{model},';
      expect(
        renderCaptionTemplate(t, {'make': 'Nikon', 'model': 'Z f'}),
        'Nikon/Z f,',
      );
      expect(renderCaptionTemplate(t, {'make': null, 'model': 'Zf'}), 'Zf,');
      expect(
        renderCaptionTemplate(t, {'make': 'Nikon', 'model': null}),
        'Nikon,',
      );
    });

    test('preserves original spacing and unknown braces', () {
      expect(
        renderCaptionTemplate('{camera}   {unknown}  写真', {'camera': 'A'}),
        'A   {unknown}  写真',
      );
      expect(renderCaptionTemplate('  {camera}  ', {'camera': 'A'}), 'A');
    });

    test('treats whitespace-only values as missing', () {
      expect(
        renderCaptionTemplate('{camera} · {iso}', {'camera': '  ', 'iso': '1'}),
        '1',
      );
    });
  });

  group('captionValues', () {
    test('formats EXIF values like a camera display', () {
      final values = captionValues(
        PhotoExif(
          make: 'NIKON CORPORATION',
          model: 'NIKON Z 6_2',
          lensModel: 'NIKKOR Z 35mm f/1.8 S',
          focalLength: 35,
          focalLength35mm: 35,
          fNumber: 1.8,
          exposureTime: 1 / 250,
          iso: 400,
          dateTimeOriginal: DateTime(2024, 5, 3, 14, 5, 9),
        ),
      );
      expect(values, {
        'camera': 'NIKON Z 6_2',
        'make': 'NIKON',
        'model': 'NIKON Z 6_2',
        'lens': 'NIKKOR Z 35mm f/1.8 S',
        'focal': '35',
        'focal35': '35',
        'aperture': '1.8',
        'shutter': '1/250',
        'iso': '400',
        'date': '2024.05.03',
        'time': '14:05',
      });
    });

    test('joins make and model when the model does not repeat it', () {
      final values = captionValues(
        const PhotoExif(make: 'SONY', model: 'ILCE-7M4', fNumber: 2.0),
      );
      expect(values['camera'], 'SONY ILCE-7M4');
      expect(values['aperture'], '2');
    });

    test('missing and zero values become null', () {
      final values = captionValues(
        const PhotoExif(focalLength: 0, fNumber: 0, iso: 0, model: ' '),
      );
      expect(values.values.every((v) => v == null), isTrue);
      expect(values.keys.toSet(), kCaptionVariables.keys.toSet());
    });
  });

  test('formatShutter', () {
    expect(formatShutter(1 / 8000), '1/8000');
    expect(formatShutter(0.0010002), '1/1000');
    expect(formatShutter(1 / 3), '1/3');
    expect(formatShutter(0.5), '1/2');
    expect(formatShutter(0.4), '0.4');
    expect(formatShutter(0.8), '0.8');
    expect(formatShutter(1), '1');
    expect(formatShutter(2.5), '2.5');
    expect(formatShutter(30), '30');
  });
}
