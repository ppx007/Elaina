import 'dart:async';

// Shared widget-test host centralizes theme/app scaffolding. Page tests should
// use this instead of rebuilding slightly different MaterialApp wrappers.
import 'package:elaina/elaina.dart';
import 'package:elaina/src/ui/theme/elaina_theme.dart';
import 'package:flutter/material.dart';

Widget elainaTestHost({required Widget child}) {
  return MaterialApp(
    home: ElainaTheme(
      data: ElainaThemeData.dark,
      mode: ElainaThemeMode.dark,
      onModeChanged: (_) {},
      child: child,
    ),
  );
}

MockPlaybackController mockPlaybackController({
  Map<PlaybackCapability, CapabilityStatus> capabilities =
      const <PlaybackCapability, CapabilityStatus>{
    PlaybackCapability.playPause: CapabilityStatus.supported(),
    PlaybackCapability.localFilePlayback: CapabilityStatus.supported(),
  },
}) {
  return MockPlaybackController(
    matrix: PlaybackCapabilityMatrix(capabilities: capabilities),
  );
}

final class FakeVideoDetailRepository implements VideoDetailRepository {
  FakeVideoDetailRepository({required this.initialData}) {
    _controller = StreamController<VideoDetailViewData>.broadcast();
  }

  VideoDetailViewData initialData;
  late final StreamController<VideoDetailViewData> _controller;

  void update(VideoDetailViewData data) {
    initialData = data;
    _controller.add(data);
  }

  @override
  Future<VideoDetailViewData> load(VideoDetailId id) async {
    return initialData;
  }

  @override
  Stream<VideoDetailViewData> watch(VideoDetailId id) async* {
    yield initialData;
    yield* _controller.stream;
  }
}

final class MappedVideoDetailRepository implements VideoDetailRepository {
  const MappedVideoDetailRepository(this._dataById);

  final Map<String, VideoDetailViewData> _dataById;

  @override
  Future<VideoDetailViewData> load(VideoDetailId id) async => _dataFor(id);

  @override
  Stream<VideoDetailViewData> watch(VideoDetailId id) async* {
    yield _dataFor(id);
  }

  VideoDetailViewData _dataFor(VideoDetailId id) {
    final VideoDetailViewData? data = _dataById[id.value];
    if (data == null) {
      throw StateError('Missing detail fixture for ${id.value}.');
    }
    return data;
  }
}

final class FakeVideoDetailActionHandler implements VideoDetailActionHandler {
  final List<String> calls = <String>[];

  @override
  Future<VideoDetailActionResult> continuePlayback(VideoDetailId id) async {
    calls.add('continuePlayback');
    return const VideoDetailActionResult.success();
  }

  @override
  Future<VideoDetailActionResult> selectEpisode(
    VideoDetailId id,
    VideoEpisodeId episodeId,
  ) async {
    calls.add('selectEpisode:${episodeId.value}');
    return const VideoDetailActionResult.success();
  }

  @override
  Future<VideoDetailActionResult> follow(VideoDetailId id) async {
    calls.add('follow');
    return const VideoDetailActionResult.success();
  }

  @override
  Future<VideoDetailActionResult> setTrackingStatus(
    VideoDetailId id,
    VideoTrackingStatus status,
  ) async {
    calls.add('setTrackingStatus:${status.name}');
    return const VideoDetailActionResult.success();
  }

  @override
  Future<VideoDetailActionResult> resolveTrackingConflict(
    VideoDetailId id,
    VideoTrackingConflictResolution resolution,
  ) async {
    calls.add('resolveTrackingConflict:${resolution.name}');
    return const VideoDetailActionResult.success();
  }

  @override
  Future<VideoDetailActionResult> perform(
    VideoDetailId id,
    VideoDetailAction action,
  ) async {
    calls.add('perform:${action.kind}');
    return const VideoDetailActionResult.success();
  }
}

final class RecordingBangumiLoginController implements BangumiLoginController {
  RecordingBangumiLoginController({this.onSignIn});

  final void Function(String token)? onSignIn;
  int startLoginCalls = 0;
  Uri? openedUri;
  String? submittedToken;

  @override
  Future<BangumiLoginStartResult> startLogin() async {
    startLoginCalls++;
    openedUri = defaultBangumiOAuthAuthorizationPageUri;
    return BangumiLoginStartResult.opened(openedUri!);
  }

  @override
  Future<BangumiTokenSignInResult> signInWithAccessToken(
    String accessToken,
  ) async {
    submittedToken = accessToken;
    onSignIn?.call(submittedToken!);
    return const BangumiTokenSignInResult.signedIn(
      UserProfileSnapshot(displayName: 'Alice'),
    );
  }
}

final class FakeRssEngine implements RssEngineContract {
  final StreamController<FeedItem> _updates =
      StreamController<FeedItem>.broadcast(sync: true);
  final List<FeedSource> registered = <FeedSource>[];

  @override
  Stream<FeedItem> get updates => _updates.stream;

  void emit(FeedItem item) {
    _updates.add(item);
  }

  @override
  Future<void> registerSource(FeedSource source) async {
    registered.add(source);
  }

  @override
  Future<RssRefreshOutcome> refreshSource(RssRefreshRequest request) async {
    return RssRefreshOutcome.success(
      sourceId: request.sourceId,
      newItems: const <FeedItem>[],
    );
  }

  Future<void> close() => _updates.close();
}

final class FakeFeedScheduler implements FeedScheduler {
  @override
  Stream<FeedScheduleDecision> dueSources(Iterable<FeedSource> sources) {
    return const Stream<FeedScheduleDecision>.empty();
  }
}

FakeSettingsRuntime fakeSettingsRuntime() => FakeSettingsRuntime();
