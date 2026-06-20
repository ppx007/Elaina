import '../../playback/subtitle/subtitle_parser.dart';
import '../../playback/subtitle/subtitle_source.dart';
import '../../provider/subtitle/subtitle_provider.dart';

SubtitleFormat subtitleFormatFromProvider(ProviderSubtitleFormat format) {
  return switch (format) {
    ProviderSubtitleFormat.srt => SubtitleFormat.srt,
    ProviderSubtitleFormat.vtt => SubtitleFormat.vtt,
    ProviderSubtitleFormat.ass => SubtitleFormat.ass,
  };
}

ExternalSubtitleSource subtitleSourceFromProviderCandidate(
    SubtitleProviderCandidate candidate, Uri uri) {
  return ExternalSubtitleSource(
    id: candidate.id,
    format: subtitleFormatFromProvider(candidate.format),
    languageCode: candidate.languageCode,
    uri: uri,
    title: candidate.title,
  );
}

SubtitleParseRequest subtitleParseRequestFromProviderFile(
    RetrievedSubtitleFile file, Uri uri) {
  return SubtitleParseRequest(
    source: subtitleSourceFromProviderCandidate(file.candidate, uri),
    content: file.content,
    encodingHint: file.encodingHint,
  );
}
