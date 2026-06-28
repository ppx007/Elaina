final class SubtitleStyleProfile {
  const SubtitleStyleProfile({
    this.fontFamily = defaultFontFamily,
    this.fontSize = defaultFontSize,
    this.fontWeight = SubtitleStyleFontWeight.bold,
    this.textColorArgb = defaultTextColorArgb,
    this.textOpacity = defaultTextOpacity,
    this.outlineStrength = defaultOutlineStrength,
    this.backgroundEnabled = defaultBackgroundEnabled,
    this.backgroundOpacity = defaultBackgroundOpacity,
    this.lineHeight = defaultLineHeight,
    this.bottomInset = defaultBottomInset,
    this.forceOverrideEmbeddedStyle = defaultForceOverrideEmbeddedStyle,
  });

  static const String defaultFontFamily = '';
  static const double defaultFontSize = 35;
  static const int defaultTextColorArgb = 0xFFFFFFFF;
  static const double defaultTextOpacity = 1;
  static const double defaultOutlineStrength = 1;
  static const bool defaultBackgroundEnabled = false;
  static const double defaultBackgroundOpacity = 0.46;
  static const double defaultLineHeight = 1.2;
  static const double defaultBottomInset = 10;
  static const bool defaultForceOverrideEmbeddedStyle = false;

  static const SubtitleStyleProfile defaults = SubtitleStyleProfile();

  final String fontFamily;
  final double fontSize;
  final SubtitleStyleFontWeight fontWeight;
  final int textColorArgb;
  final double textOpacity;
  final double outlineStrength;
  final bool backgroundEnabled;
  final double backgroundOpacity;
  final double lineHeight;
  final double bottomInset;
  final bool forceOverrideEmbeddedStyle;

  SubtitleStyleProfile copyWith({
    String? fontFamily,
    double? fontSize,
    SubtitleStyleFontWeight? fontWeight,
    int? textColorArgb,
    double? textOpacity,
    double? outlineStrength,
    bool? backgroundEnabled,
    double? backgroundOpacity,
    double? lineHeight,
    double? bottomInset,
    bool? forceOverrideEmbeddedStyle,
  }) {
    return SubtitleStyleProfile(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      textColorArgb: textColorArgb ?? this.textColorArgb,
      textOpacity: textOpacity ?? this.textOpacity,
      outlineStrength: outlineStrength ?? this.outlineStrength,
      backgroundEnabled: backgroundEnabled ?? this.backgroundEnabled,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      lineHeight: lineHeight ?? this.lineHeight,
      bottomInset: bottomInset ?? this.bottomInset,
      forceOverrideEmbeddedStyle:
          forceOverrideEmbeddedStyle ?? this.forceOverrideEmbeddedStyle,
    );
  }
}

enum SubtitleStyleFontWeight {
  normal,
  medium,
  bold,
}

enum DomainSubtitleStyleSource {
  userDefault,
  embedded,
  forcedUserOverride,
}
