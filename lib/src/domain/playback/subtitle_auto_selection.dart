import 'playback_controller.dart';
import 'playback_state.dart';

const String subtitleAutoSelectEnabledValue = 'true';
const String subtitleAutoSelectDisabledValue = 'false';
const String subtitleAutoSelectionDefaultBuiltInRule =
    'Simplified Chinese subtitle preference';

final class SubtitleAutoSelectPreferences {
  const SubtitleAutoSelectPreferences({
    this.enabled = true,
    this.customPattern,
    this.invalidPatternReason,
  });

  final bool enabled;
  final String? customPattern;
  final String? invalidPatternReason;

  bool get hasValidCustomPattern =>
      customPattern != null && customPattern!.trim().isNotEmpty;
}

abstract final class SubtitleAutoSelectSettings {
  static bool parseEnabled(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return true;
    return switch (normalized) {
      subtitleAutoSelectEnabledValue => true,
      subtitleAutoSelectDisabledValue => false,
      _ => throw FormatException('Invalid subtitle auto-select value: $value'),
    };
  }

  static String serializeEnabled(bool enabled) {
    return enabled
        ? subtitleAutoSelectEnabledValue
        : subtitleAutoSelectDisabledValue;
  }

  static String? parsePattern(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    validateRegex(normalized);
    return normalized;
  }

  static String serializePattern(String? pattern) {
    return pattern?.trim() ?? '';
  }

  static void validateRegex(String pattern) {
    RegExp(pattern, caseSensitive: false);
  }
}

enum SubtitleAutoSelectionStatus {
  idle,
  disabled,
  selected,
  noMatch,
  manualOverride,
  failed,
}

enum SubtitleAutoSelectionRule {
  customRegex,
  simplifiedChinese,
}

final class SubtitleAutoSelectionSnapshot {
  const SubtitleAutoSelectionSnapshot._({
    required this.status,
    this.selectedTrackId,
    this.rule,
    this.message,
  });

  const SubtitleAutoSelectionSnapshot.idle()
      : this._(status: SubtitleAutoSelectionStatus.idle);

  const SubtitleAutoSelectionSnapshot.disabled()
      : this._(
          status: SubtitleAutoSelectionStatus.disabled,
          message: 'Subtitle auto-selection is disabled.',
        );

  const SubtitleAutoSelectionSnapshot.selected({
    required DomainMediaTrackId selectedTrackId,
    required SubtitleAutoSelectionRule rule,
    required String message,
  }) : this._(
          status: SubtitleAutoSelectionStatus.selected,
          selectedTrackId: selectedTrackId,
          rule: rule,
          message: message,
        );

  const SubtitleAutoSelectionSnapshot.noMatch(String message)
      : this._(
          status: SubtitleAutoSelectionStatus.noMatch,
          message: message,
        );

  const SubtitleAutoSelectionSnapshot.manualOverride({
    required DomainMediaTrackId selectedTrackId,
  }) : this._(
          status: SubtitleAutoSelectionStatus.manualOverride,
          selectedTrackId: selectedTrackId,
          message: 'User selected subtitle track manually for this source.',
        );

  const SubtitleAutoSelectionSnapshot.failed(String message)
      : this._(
          status: SubtitleAutoSelectionStatus.failed,
          message: message,
        );

  final SubtitleAutoSelectionStatus status;
  final DomainMediaTrackId? selectedTrackId;
  final SubtitleAutoSelectionRule? rule;
  final String? message;
}

final class SubtitleTrackAutoSelectionResult {
  const SubtitleTrackAutoSelectionResult._({
    this.track,
    this.rule,
    this.message,
    this.failure,
  });

  const SubtitleTrackAutoSelectionResult.selected({
    required DomainMediaTrackDescriptor track,
    required SubtitleAutoSelectionRule rule,
    required String message,
  }) : this._(track: track, rule: rule, message: message);

  const SubtitleTrackAutoSelectionResult.noMatch(String message)
      : this._(message: message);

  const SubtitleTrackAutoSelectionResult.disabled()
      : this._(message: 'Subtitle auto-selection is disabled.');

  const SubtitleTrackAutoSelectionResult.failed(String failure)
      : this._(failure: failure);

  final DomainMediaTrackDescriptor? track;
  final SubtitleAutoSelectionRule? rule;
  final String? message;
  final String? failure;

  bool get isSelected => track != null && rule != null;
  bool get isFailure => failure != null;
}

final class SubtitleTrackAutoSelectionPolicy {
  const SubtitleTrackAutoSelectionPolicy({
    this.preferences = const SubtitleAutoSelectPreferences(),
  });

  static const List<String> simplifiedChineseTokens = <String>[
    'zh-hans',
    'zh_cn',
    'zh-cn',
    'zh_sg',
    'zh-sg',
    'chs',
    'sc',
    'gb',
    '简',
    '简体',
    '简中',
    '简体中文',
    'simplified',
  ];

  final SubtitleAutoSelectPreferences preferences;

  SubtitleTrackAutoSelectionResult select(
    Iterable<DomainMediaTrackDescriptor> tracks,
  ) {
    if (!preferences.enabled) {
      return const SubtitleTrackAutoSelectionResult.disabled();
    }
    if (preferences.invalidPatternReason != null) {
      final SubtitleTrackAutoSelectionResult fallback =
          _selectBuiltInSimplifiedChinese(tracks);
      if (fallback.isSelected) {
        return SubtitleTrackAutoSelectionResult.selected(
          track: fallback.track!,
          rule: fallback.rule!,
          message:
              '${preferences.invalidPatternReason} Used Simplified Chinese default.',
        );
      }
      return SubtitleTrackAutoSelectionResult.failed(
        preferences.invalidPatternReason!,
      );
    }

    if (preferences.hasValidCustomPattern) {
      final RegExp customRegex = RegExp(
        preferences.customPattern!,
        caseSensitive: false,
      );
      final DomainMediaTrackDescriptor? customTrack =
          _firstMatchingTrack(tracks, customRegex.hasMatch);
      if (customTrack != null) {
        return SubtitleTrackAutoSelectionResult.selected(
          track: customTrack,
          rule: SubtitleAutoSelectionRule.customRegex,
          message: 'Matched custom subtitle auto-select regex.',
        );
      }
    }

    return _selectBuiltInSimplifiedChinese(tracks);
  }

  SubtitleTrackAutoSelectionResult _selectBuiltInSimplifiedChinese(
    Iterable<DomainMediaTrackDescriptor> tracks,
  ) {
    DomainMediaTrackDescriptor? bestTrack;
    int bestScore = 0;
    for (final DomainMediaTrackDescriptor track in tracks) {
      if (track.type != DomainMediaTrackType.subtitle) continue;
      final int score = _simplifiedChineseScore(track);
      if (score > bestScore) {
        bestScore = score;
        bestTrack = track;
      }
    }
    if (bestTrack == null) {
      return const SubtitleTrackAutoSelectionResult.noMatch(
        'No Simplified Chinese subtitle track matched.',
      );
    }
    return SubtitleTrackAutoSelectionResult.selected(
      track: bestTrack,
      rule: SubtitleAutoSelectionRule.simplifiedChinese,
      message: subtitleAutoSelectionDefaultBuiltInRule,
    );
  }

  DomainMediaTrackDescriptor? _firstMatchingTrack(
    Iterable<DomainMediaTrackDescriptor> tracks,
    bool Function(String value) matches,
  ) {
    for (final DomainMediaTrackDescriptor track in tracks) {
      if (track.type != DomainMediaTrackType.subtitle) continue;
      if (matches(_trackMatchText(track))) return track;
    }
    return null;
  }

  int _simplifiedChineseScore(DomainMediaTrackDescriptor track) {
    final String text = _trackMatchText(track).toLowerCase();
    int score = 0;
    for (final String token in simplifiedChineseTokens) {
      if (text.contains(token.toLowerCase())) {
        score += token.length;
      }
    }
    final String? languageCode = track.languageCode?.toLowerCase();
    if (languageCode == 'zh' ||
        languageCode == 'chi' ||
        languageCode == 'zho') {
      score += 1;
    }
    return score;
  }

  String _trackMatchText(DomainMediaTrackDescriptor track) {
    return <String>[
      track.id.value,
      track.label,
      if (track.languageCode != null) track.languageCode!,
    ].join(' ');
  }
}
