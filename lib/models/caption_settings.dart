import 'dart:ui' show Color, FontWeight;

enum CaptionAlign {
  left('左'),
  center('中央'),
  right('右');

  const CaptionAlign(this.label);
  final String label;
}

/// Fonts are resolved from the Android system font configuration so the app
/// stays offline and Japanese text falls back to the system CJK font.
enum CaptionFont {
  sans('Sans', 'sans-serif', FontWeight.w400),
  sansLight('Light', 'sans-serif', FontWeight.w300),
  sansMedium('Medium', 'sans-serif', FontWeight.w500),
  condensed('Condensed', 'sans-serif-condensed', FontWeight.w400),
  serif('Serif', 'serif', FontWeight.w400),
  mono('Mono', 'monospace', FontWeight.w400);

  const CaptionFont(this.label, this.family, this.weight);
  final String label;
  final String family;
  final FontWeight weight;
}

class CaptionSettings {
  const CaptionSettings({
    this.enabled = true,
    this.template = defaultTemplate,
    this.font = CaptionFont.sans,
    this.sizeRatio = 0.025,
    this.color = const Color(0xFF3A3A3A),
    this.align = CaptionAlign.center,
  });

  static const String defaultTemplate =
      '{camera} · {focal}mm f/{aperture} {shutter}s ISO{iso}';
  static const double minSizeRatio = 0.01;
  static const double maxSizeRatio = 0.08;

  final bool enabled;
  final String template;
  final CaptionFont font;

  /// Font size relative to the photo's short side.
  final double sizeRatio;
  final Color color;
  final CaptionAlign align;

  CaptionSettings copyWith({
    bool? enabled,
    String? template,
    CaptionFont? font,
    double? sizeRatio,
    Color? color,
    CaptionAlign? align,
  }) {
    return CaptionSettings(
      enabled: enabled ?? this.enabled,
      template: template ?? this.template,
      font: font ?? this.font,
      sizeRatio: sizeRatio ?? this.sizeRatio,
      color: color ?? this.color,
      align: align ?? this.align,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CaptionSettings &&
      other.enabled == enabled &&
      other.template == template &&
      other.font == font &&
      other.sizeRatio == sizeRatio &&
      other.color == color &&
      other.align == align;

  @override
  int get hashCode =>
      Object.hash(enabled, template, font, sizeRatio, color, align);
}
