import 'dart:ui' show Color;

enum FrameStyle {
  /// Same margin on every side.
  uniform('均一'),

  /// Side/top margins plus a thicker bottom band for the caption.
  captionBand('キャプション帯'),

  /// Pads (never crops) the photo out to a fixed aspect ratio.
  aspect('比率');

  const FrameStyle(this.label);
  final String label;
}

enum AspectPreset {
  square('1:1', 1, 1),
  portrait('4:5', 4, 5),
  story('9:16', 9, 16);

  const AspectPreset(this.label, this.width, this.height);
  final String label;
  final int width;
  final int height;

  double get ratio => width / height;
}

/// Frame settings shared by every selected photo.
///
/// Sizes are fractions of the photo's short side so that photos with
/// different resolutions end up with visually identical proportions.
class FrameSettings {
  const FrameSettings({
    this.style = FrameStyle.uniform,
    this.aspect = AspectPreset.portrait,
    this.marginRatio = 0.04,
    this.bottomRatio = 0.16,
    this.color = const Color(0xFFFFFFFF),
  });

  static const double minMarginRatio = 0;
  static const double maxMarginRatio = 0.2;
  static const double minBottomRatio = 0.05;
  static const double maxBottomRatio = 0.4;

  final FrameStyle style;
  final AspectPreset aspect;

  /// Margin on each side (and at the bottom for [FrameStyle.uniform] and
  /// [FrameStyle.aspect]), relative to the short side.
  final double marginRatio;

  /// Bottom band height for [FrameStyle.captionBand], relative to the short side.
  final double bottomRatio;

  final Color color;

  FrameSettings copyWith({
    FrameStyle? style,
    AspectPreset? aspect,
    double? marginRatio,
    double? bottomRatio,
    Color? color,
  }) {
    return FrameSettings(
      style: style ?? this.style,
      aspect: aspect ?? this.aspect,
      marginRatio: marginRatio ?? this.marginRatio,
      bottomRatio: bottomRatio ?? this.bottomRatio,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FrameSettings &&
      other.style == style &&
      other.aspect == aspect &&
      other.marginRatio == marginRatio &&
      other.bottomRatio == bottomRatio &&
      other.color == color;

  @override
  int get hashCode =>
      Object.hash(style, aspect, marginRatio, bottomRatio, color);
}
