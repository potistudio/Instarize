import '../models/photo_exif.dart';

/// Variables available in caption templates, with a short UI label.
const Map<String, String> kCaptionVariables = {
  'camera': 'カメラ',
  'make': 'メーカー',
  'model': '機種',
  'lens': 'レンズ',
  'focal': '焦点距離',
  'focal35': '35mm換算',
  'aperture': 'F値',
  'shutter': 'SS',
  'iso': 'ISO',
  'date': '日付',
  'time': '時刻',
};

/// Maps every key of [kCaptionVariables] to its formatted value, or `null`
/// when the photo does not carry that information.
Map<String, String?> captionValues(PhotoExif exif) {
  final make = _cleanMake(exif.make);
  final model = _clean(exif.model);
  final date = exif.dateTimeOriginal;
  return {
    'camera': _camera(make, model),
    'make': make,
    'model': model,
    'lens': _clean(exif.lensModel),
    'focal': _positive(exif.focalLength, _formatNumber),
    'focal35': exif.focalLength35mm != null && exif.focalLength35mm! > 0
        ? '${exif.focalLength35mm}'
        : null,
    'aperture': _positive(exif.fNumber, _formatNumber),
    'shutter': _positive(exif.exposureTime, formatShutter),
    'iso': exif.iso != null && exif.iso! > 0 ? '${exif.iso}' : null,
    'date': date == null
        ? null
        : '${date.year}.${_two(date.month)}.${_two(date.day)}',
    'time': date == null ? null : '${_two(date.hour)}:${_two(date.minute)}',
  };
}

/// Expands `{name}` variables in [template] using [values].
///
/// Missing variables must not leave dangling decoration behind, so:
/// * a whitespace-separated word whose variables are all missing is dropped
///   together with its attached units (`{focal}mm`, `f/{aperture}`, `ISO{iso}`);
/// * separator words (no letters or digits, e.g. `·`, `|`, `/`) that end up
///   at the start or end because of a dropped word are removed, and
///   separators that would end up doubled are collapsed to the first one;
/// * inside a single word (`{make}/{model}`) the same rules apply to the
///   literal pieces around a missing variable.
///
/// Braces that do not name a known key in [values] are kept verbatim.
String renderCaptionTemplate(String template, Map<String, String?> values) {
  final tokens = <_Token>[];
  for (final match in _wordPattern.allMatches(template)) {
    final space = match.group(1)!;
    final word = match.group(2)!;
    tokens.add(_resolveWord(word, space, values));
  }
  return _join(_dropDangling(tokens));
}

/// Formats an exposure time in seconds the way cameras display it.
String formatShutter(double seconds) {
  if (seconds >= 1) return _formatNumber(seconds);
  final denominator = 1 / seconds;
  final rounded = denominator.round();
  if (denominator >= 3 || (denominator - rounded).abs() < 0.05) {
    return '1/$rounded';
  }
  return _formatNumber(seconds);
}

final _wordPattern = RegExp(r'(\s*)(\S+)');
final _variablePattern = RegExp(r'\{([A-Za-z0-9_]+)\}');
final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

enum _Kind { text, separator, gap }

class _Token {
  const _Token(this.kind, this.text, this.space);

  final _Kind kind;
  final String text;

  /// Whitespace that preceded the token in the template.
  final String space;
}

_Kind _literalKind(String text) =>
    _letterOrDigit.hasMatch(text) ? _Kind.text : _Kind.separator;

_Token _resolveWord(String word, String space, Map<String, String?> values) {
  final pieces = <_Token>[];
  var resolved = 0;
  var missing = 0;
  var cursor = 0;
  for (final match in _variablePattern.allMatches(word)) {
    final key = match.group(1)!;
    if (!values.containsKey(key)) continue;
    if (match.start > cursor) {
      final literal = word.substring(cursor, match.start);
      pieces.add(_Token(_literalKind(literal), literal, ''));
    }
    final value = values[key]?.trim() ?? '';
    if (value.isEmpty) {
      missing++;
      pieces.add(const _Token(_Kind.gap, '', ''));
    } else {
      resolved++;
      pieces.add(_Token(_Kind.text, value, ''));
    }
    cursor = match.end;
  }
  if (resolved == 0 && missing == 0) {
    return _Token(_literalKind(word), word, space);
  }
  // Every variable in the word is missing: drop the word with its units.
  if (resolved == 0) return _Token(_Kind.gap, '', space);

  if (cursor < word.length) {
    final literal = word.substring(cursor);
    pieces.add(_Token(_literalKind(literal), literal, ''));
  }
  final text = missing == 0
      ? pieces.map((p) => p.text).join()
      : _join(_dropDangling(pieces));
  return _Token(_Kind.text, text, space);
}

/// Removes separators left dangling by dropped (gap) tokens, and the gaps.
List<_Token> _dropDangling(List<_Token> tokens) {
  final result = <_Token>[];
  var index = 0;
  while (index < tokens.length) {
    if (tokens[index].kind == _Kind.text) {
      result.add(tokens[index]);
      index++;
      continue;
    }
    // A run of separators and gaps between two text tokens (or an edge).
    final start = index;
    while (index < tokens.length && tokens[index].kind != _Kind.text) {
      index++;
    }
    result.addAll(
      _keptSeparators(
        tokens.sublist(start, index),
        leading: start == 0,
        trailing: index == tokens.length,
      ),
    );
  }
  return result;
}

List<_Token> _keptSeparators(
  List<_Token> run, {
  required bool leading,
  required bool trailing,
}) {
  if (!run.any((t) => t.kind == _Kind.gap)) return run;

  // Separator groups divided by gaps.
  final groups = <List<_Token>>[[]];
  for (final token in run) {
    if (token.kind == _Kind.gap) {
      groups.add([]);
    } else {
      groups.last.add(token);
    }
  }

  if (leading && trailing) return const [];
  // At an edge only the decoration that faced the surviving text stays.
  if (leading) return groups.first;
  if (trailing) return groups.last;

  // In the middle the text on both sides still needs separating, but only
  // once: keep the first group, drop the ones that would now be doubled.
  return groups.firstWhere((g) => g.isNotEmpty, orElse: () => const []);
}

String _join(List<_Token> tokens) {
  final buffer = StringBuffer();
  for (final token in tokens) {
    if (buffer.isNotEmpty) buffer.write(token.space);
    buffer.write(token.text);
  }
  return buffer.toString();
}

String? _clean(String? value) {
  final trimmed = value?.replaceAll('\u0000', '').trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

final _corporateSuffix = RegExp(
  r'[\s,]+(imaging\s+corp\.?|corporation|corp\.?|co\.,?\s*ltd\.?|inc\.?|ltd\.?)$',
  caseSensitive: false,
);

String? _cleanMake(String? make) {
  var value = _clean(make);
  if (value == null) return null;
  while (_corporateSuffix.hasMatch(value!)) {
    value = value.replaceFirst(_corporateSuffix, '');
  }
  return value.isEmpty ? null : value;
}

String? _camera(String? make, String? model) {
  if (model == null) return make;
  if (make == null) return model;
  if (model.toLowerCase().startsWith(make.toLowerCase())) return model;
  return '$make $model';
}

String? _positive(double? value, String Function(double) format) =>
    value != null && value > 0 && value.isFinite ? format(value) : null;

/// One decimal place at most, without a trailing `.0`.
String _formatNumber(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

String _two(int value) => value.toString().padLeft(2, '0');
