import 'subtitle_cue.dart';
import 'subtitle_source.dart';

/// Immutable request passed into format-specific subtitle parsers.
///
/// Parsers receive already-decoded text; byte decoding and provider caching are
/// handled outside this boundary so format parsing stays deterministic.
final class SubtitleParseRequest {
  const SubtitleParseRequest({
    required this.source,
    required this.content,
    this.encodingHint,
  });

  final SubtitleSource source;
  final String content;
  final String? encodingHint;
}

final class SubtitleParseResult {
  const SubtitleParseResult._({required this.track, required this.warnings});

  const SubtitleParseResult.success(SubtitleTrack track,
      {List<String> warnings = const <String>[]})
      : this._(track: track, warnings: warnings);

  factory SubtitleParseResult.empty(
      {required SubtitleSource source, String? warning}) {
    return SubtitleParseResult._(
      track: SubtitleTrack(source: source, cues: const <SubtitleCue>[]),
      warnings: <String>[if (warning != null) warning],
    );
  }

  final SubtitleTrack track;
  final List<String> warnings;
}

abstract interface class SubtitleParser {
  SubtitleFormat get format;

  Future<SubtitleParseResult> parse(SubtitleParseRequest request);
}

abstract interface class SubtitleParserRegistry {
  SubtitleParser? parserFor(SubtitleFormat format);
}

final class BasicSubtitleParserRegistry implements SubtitleParserRegistry {
  const BasicSubtitleParserRegistry(
      {required Map<SubtitleFormat, SubtitleParser> parsers})
      : _parsers = parsers;

  factory BasicSubtitleParserRegistry.defaults() {
    return BasicSubtitleParserRegistry(
      parsers: <SubtitleFormat, SubtitleParser>{
        SubtitleFormat.srt: const SrtSubtitleParser(),
        SubtitleFormat.vtt: const WebVttSubtitleParser(),
        SubtitleFormat.ass: const BasicAssSubtitleParser(),
      },
    );
  }

  final Map<SubtitleFormat, SubtitleParser> _parsers;

  @override
  SubtitleParser? parserFor(SubtitleFormat format) => _parsers[format];
}

/// Minimal SRT parser that preserves malformed-file warnings instead of
/// throwing away the entire track after one bad cue.
final class SrtSubtitleParser implements SubtitleParser {
  const SrtSubtitleParser();

  @override
  SubtitleFormat get format => SubtitleFormat.srt;

  @override
  Future<SubtitleParseResult> parse(SubtitleParseRequest request) async {
    final List<String> lines = _normalizedLines(request.content);
    final List<SubtitleCue> cues = <SubtitleCue>[];
    final List<String> warnings = <String>[];
    for (int index = 0; index < lines.length; index += 1) {
      final _CueTimingLine? timing =
          _parseTimingLine(lines[index], format: _SubtitleTimestampFormat.srt);
      if (timing == null) continue;
      final List<String> textLines = <String>[];
      int cursor = index + 1;
      while (cursor < lines.length && !_isBlank(lines[cursor])) {
        if (_parseTimingLine(lines[cursor],
                format: _SubtitleTimestampFormat.srt) !=
            null) {
          break;
        }
        textLines.add(lines[cursor]);
        cursor += 1;
      }
      if (timing.end < timing.start) {
        warnings
            .add('Ignored SRT cue with end before start at line ${index + 1}.');
      } else {
        cues.add(SubtitleCue(
          start: timing.start,
          end: timing.end,
          text: textLines.join('\n').trim(),
          id: _srtCueId(lines, index),
        ));
      }
      index = cursor;
    }
    return _resultForParsedCues(
        request: request,
        cues: cues,
        warnings: warnings,
        emptyWarning: 'No SRT cues were parsed.');
  }
}

final class WebVttSubtitleParser implements SubtitleParser {
  const WebVttSubtitleParser();

  @override
  SubtitleFormat get format => SubtitleFormat.vtt;

  @override
  Future<SubtitleParseResult> parse(SubtitleParseRequest request) async {
    final List<String> lines = _normalizedLines(request.content);
    final List<SubtitleCue> cues = <SubtitleCue>[];
    final List<String> warnings = <String>[];
    if (lines.isEmpty || !lines.first.trimLeft().startsWith('WEBVTT')) {
      warnings.add('WebVTT content does not start with WEBVTT.');
    }

    for (int index =
            lines.isNotEmpty && lines.first.trimLeft().startsWith('WEBVTT')
                ? 1
                : 0;
        index < lines.length;
        index += 1) {
      final String line = lines[index].trim();
      if (_isBlank(line)) continue;
      if (line == 'NOTE' || line.startsWith('NOTE ')) {
        while (index + 1 < lines.length && !_isBlank(lines[index + 1])) {
          index += 1;
        }
        continue;
      }
      if (line == 'STYLE' || line == 'REGION') {
        while (index + 1 < lines.length && !_isBlank(lines[index + 1])) {
          index += 1;
        }
        continue;
      }

      String? cueId;
      _CueTimingLine? timing =
          _parseTimingLine(line, format: _SubtitleTimestampFormat.webVtt);
      if (timing == null && index + 1 < lines.length) {
        cueId = line;
        index += 1;
        timing = _parseTimingLine(lines[index],
            format: _SubtitleTimestampFormat.webVtt);
      }
      if (timing == null) continue;

      final List<String> textLines = <String>[];
      int cursor = index + 1;
      while (cursor < lines.length && !_isBlank(lines[cursor])) {
        textLines.add(lines[cursor]);
        cursor += 1;
      }
      if (timing.end < timing.start) {
        warnings.add(
            'Ignored WebVTT cue with end before start at line ${index + 1}.');
      } else {
        cues.add(SubtitleCue(
          start: timing.start,
          end: timing.end,
          text: textLines.join('\n').trim(),
          id: cueId,
          settings: timing.settings,
        ));
      }
      index = cursor;
    }
    return _resultForParsedCues(
        request: request,
        cues: cues,
        warnings: warnings,
        emptyWarning: 'No WebVTT cues were parsed.');
  }
}

/// Basic ASS parser for timing and plain text extraction.
///
/// Advanced ASS layout and styling belong to the advanced caption renderer; the
/// core subtitle runtime only needs stable cues for playback synchronization.
final class BasicAssSubtitleParser implements SubtitleParser {
  const BasicAssSubtitleParser();

  @override
  SubtitleFormat get format => SubtitleFormat.ass;

  @override
  Future<SubtitleParseResult> parse(SubtitleParseRequest request) async {
    final List<String> lines = _normalizedLines(request.content);
    final List<SubtitleCue> cues = <SubtitleCue>[];
    final List<String> warnings = <String>[];
    bool inEvents = false;
    List<String> fields = <String>[
      'Layer',
      'Start',
      'End',
      'Style',
      'Name',
      'MarginL',
      'MarginR',
      'MarginV',
      'Effect',
      'Text',
    ];
    for (int index = 0; index < lines.length; index += 1) {
      final String line = lines[index].trim();
      if (line == '[Events]') {
        inEvents = true;
        continue;
      }
      if (line.startsWith('[') && line.endsWith(']') && line != '[Events]') {
        inEvents = false;
        continue;
      }
      if (!inEvents || line.startsWith(';')) continue;
      if (line.startsWith('Format:')) {
        fields = line
            .substring('Format:'.length)
            .split(',')
            .map((String field) => field.trim())
            .toList(growable: false);
        continue;
      }
      if (!line.startsWith('Dialogue:')) continue;
      final Map<String, String>? values = _splitAssDialogue(
        line.substring('Dialogue:'.length).trimLeft(),
        fields,
      );
      if (values == null) {
        warnings.add('Ignored malformed ASS dialogue at line ${index + 1}.');
        continue;
      }
      final Duration? start = _parseSubtitleTimestamp(
          values['Start'] ?? '', _SubtitleTimestampFormat.ass);
      final Duration? end = _parseSubtitleTimestamp(
          values['End'] ?? '', _SubtitleTimestampFormat.ass);
      if (start == null || end == null || end < start) {
        warnings.add(
            'Ignored ASS dialogue with invalid timing at line ${index + 1}.');
        continue;
      }
      cues.add(SubtitleCue(
        start: start,
        end: end,
        text: _normalizeAssText(values['Text'] ?? ''),
        settings: <String, String>{
          if ((values['Style'] ?? '').isNotEmpty) 'style': values['Style']!,
          if ((values['Layer'] ?? '').isNotEmpty) 'layer': values['Layer']!,
        },
      ));
    }
    return _resultForParsedCues(
        request: request,
        cues: cues,
        warnings: warnings,
        emptyWarning: 'No ASS dialogue cues were parsed.');
  }
}

enum _SubtitleTimestampFormat { srt, webVtt, ass }

final class _CueTimingLine {
  const _CueTimingLine(
      {required this.start,
      required this.end,
      this.settings = const <String, String>{}});

  final Duration start;
  final Duration end;
  final Map<String, String> settings;
}

List<String> _normalizedLines(String content) {
  final String normalized = content
      .replaceFirst('\uFEFF', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  return normalized.split('\n');
}

bool _isBlank(String line) => line.trim().isEmpty;

SubtitleParseResult _resultForParsedCues({
  required SubtitleParseRequest request,
  required List<SubtitleCue> cues,
  required List<String> warnings,
  required String emptyWarning,
}) {
  final List<SubtitleCue> sortedCues = List<SubtitleCue>.of(cues)
    ..sort((SubtitleCue left, SubtitleCue right) =>
        left.start.compareTo(right.start));
  if (sortedCues.isEmpty) {
    return SubtitleParseResult.empty(
        source: request.source, warning: emptyWarning);
  }
  return SubtitleParseResult.success(
    SubtitleTrack(source: request.source, cues: sortedCues),
    warnings: warnings,
  );
}

_CueTimingLine? _parseTimingLine(String line,
    {required _SubtitleTimestampFormat format}) {
  final int arrow = line.indexOf('-->');
  if (arrow < 0) return null;
  final String startText = line.substring(0, arrow).trim();
  final String tail = line.substring(arrow + 3).trim();
  final List<String> endAndSettings = tail.split(RegExp(r'\s+'));
  if (endAndSettings.isEmpty) return null;
  final Duration? start = _parseSubtitleTimestamp(startText, format);
  final Duration? end = _parseSubtitleTimestamp(endAndSettings.first, format);
  if (start == null || end == null) return null;
  final Map<String, String> settings = <String, String>{};
  for (final String token in endAndSettings.skip(1)) {
    final int separator = token.indexOf(':');
    if (separator > 0 && separator < token.length - 1) {
      settings[token.substring(0, separator)] = token.substring(separator + 1);
    }
  }
  return _CueTimingLine(start: start, end: end, settings: settings);
}

Duration? _parseSubtitleTimestamp(
    String value, _SubtitleTimestampFormat format) {
  final String text = value.trim().replaceAll(',', '.');
  final List<String> parts = text.split(':');
  if (format == _SubtitleTimestampFormat.ass) {
    if (parts.length != 3) return null;
    final int? hours = int.tryParse(parts[0]);
    final int? minutes = int.tryParse(parts[1]);
    final List<String> secondsParts = parts[2].split('.');
    if (secondsParts.length != 2) return null;
    final int? seconds = int.tryParse(secondsParts[0]);
    final int? centiseconds =
        int.tryParse(secondsParts[1].padRight(2, '0').substring(0, 2));
    if (hours == null ||
        minutes == null ||
        seconds == null ||
        centiseconds == null) return null;
    return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: centiseconds * 10);
  }
  if (parts.length != 2 && parts.length != 3) return null;
  final int hours = parts.length == 3 ? int.tryParse(parts[0]) ?? -1 : 0;
  final int? minutes = int.tryParse(parts.length == 3 ? parts[1] : parts[0]);
  final List<String> secondsParts =
      (parts.length == 3 ? parts[2] : parts[1]).split('.');
  if (secondsParts.length != 2) return null;
  final int? seconds = int.tryParse(secondsParts[0]);
  final String fraction = secondsParts[1].padRight(3, '0').substring(0, 3);
  final int? milliseconds = int.tryParse(fraction);
  if (hours < 0 || minutes == null || seconds == null || milliseconds == null)
    return null;
  return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds);
}

String? _srtCueId(List<String> lines, int timingIndex) {
  if (timingIndex == 0) return null;
  final String candidate = lines[timingIndex - 1].trim();
  if (candidate.isEmpty || candidate.contains('-->')) return null;
  return candidate;
}

Map<String, String>? _splitAssDialogue(String text, List<String> fields) {
  if (fields.isEmpty) return null;
  final List<String> values = <String>[];
  int start = 0;
  for (int fieldIndex = 0; fieldIndex < fields.length - 1; fieldIndex += 1) {
    final int comma = text.indexOf(',', start);
    if (comma < 0) return null;
    values.add(text.substring(start, comma).trim());
    start = comma + 1;
  }
  values.add(text.substring(start).trim());
  return <String, String>{
    for (int index = 0; index < fields.length; index += 1)
      fields[index]: values[index],
  };
}

String _normalizeAssText(String text) {
  return text
      .replaceAll(RegExp(r'\{[^}]*\}'), '')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\n', '\n')
      .trim();
}
