import 'package:flutter/material.dart';
import '../../domain/detail/video_detail.dart';
import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_source_handoff.dart';
import '../theme/elaina_theme.dart';
import 'video_detail_page_contract.dart';

class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({
    super.key,
    required this.id,
    required this.videoDetailPageContract,
    required this.playbackController,
    required this.onPlaybackStarted,
    required this.onClose,
  });

  final VideoDetailId id;
  final VideoDetailPageContract videoDetailPageContract;
  final PlaybackControllerContract playbackController;
  final VoidCallback onPlaybackStarted;
  final VoidCallback onClose;

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  Future<void> _continuePlayback(VideoDetailViewData data) async {
    final VideoDetailActionResult result =
        await widget.videoDetailPageContract.continuePlayback(widget.id);
    if (result.isSuccess && data.continueWatching != null && mounted) {
      // Find matching episode
      final VideoDetailEpisode? episode = data.episodes.where((ep) {
        return ep.localMediaId?.value == data.continueWatching!.mediaId.value;
      }).firstOrNull;

      if (episode != null && episode.localMedia != null) {
        await _playEpisode(episode);
      }
    }
  }

  Future<void> _selectEpisode(VideoDetailEpisode episode) async {
    final VideoDetailActionResult result = await widget.videoDetailPageContract
        .selectEpisode(widget.id, episode.id);
    if (result.isSuccess && episode.localMedia != null && mounted) {
      await _playEpisode(episode);
    }
  }

  Future<void> _playEpisode(VideoDetailEpisode episode) async {
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
    final prepared = handoff.prepare(
      PlaybackSourceHandoffInput.localMediaIdentity(episode.localMedia!),
    );
    if (prepared.isSuccess) {
      final DomainPlaybackCommandResult openResult =
          await widget.playbackController.open(prepared.source!);
      if (openResult.isSuccess) {
        await widget.playbackController.play();
        widget.onPlaybackStarted();
      }
    }
  }

  Future<void> _toggleFollow(VideoDetailViewData data) async {
    if (data.followState == VideoFollowState.followed) {
      await widget.videoDetailPageContract.unfollow(widget.id);
    } else {
      await widget.videoDetailPageContract.follow(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);

    return StreamBuilder<VideoDetailViewData>(
      stream: widget.videoDetailPageContract.watch(widget.id),
      builder:
          (BuildContext context, AsyncSnapshot<VideoDetailViewData> snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('加载详情失败: ${snapshot.error}',
                style: TextStyle(color: theme.onSurface)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final VideoDetailViewData data = snapshot.data!;
        final bool isFollowed = data.followState == VideoFollowState.followed;
        final bool hasContinueWatching = data.continueWatching != null;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            margin: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: theme.border, width: 1.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Column(
                children: <Widget>[
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: theme.onSurface,
                          onPressed: widget.onClose,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data.title,
                            style: TextStyle(
                              color: theme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),

                  // Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Left column (Poster / Action)
                          SizedBox(
                            width: 200,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                // Cover image
                                AspectRatio(
                                  aspectRatio: 0.7,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: theme.border),
                                      image: data.coverUri != null
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                data.coverUri!.toString(),
                                              ),
                                              fit: BoxFit.cover,
                                              onError:
                                                  (exception, stackTrace) {},
                                            )
                                          : null,
                                    ),
                                    child: data.coverUri == null
                                        ? Center(
                                            child: Icon(
                                              Icons.movie_filter_outlined,
                                              color: theme.primary
                                                  .withValues(alpha: 0.5),
                                              size: 48,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Follow Action
                                ElevatedButton.icon(
                                  onPressed: () => _toggleFollow(data),
                                  icon: Icon(
                                    isFollowed
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 16,
                                  ),
                                  label: Text(isFollowed ? '已在追番' : '加入追番'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowed
                                        ? theme.secondary
                                        : theme.primary,
                                    foregroundColor: theme.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right column (Metadata / Description / Episodes)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Title and continue play button
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        data.title,
                                        style: TextStyle(
                                          color: theme.onSurface,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (hasContinueWatching)
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _continuePlayback(data),
                                        icon: const Icon(Icons.play_circle_fill,
                                            size: 18),
                                        label: const Text('继续观看'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.primary,
                                          foregroundColor: theme.background,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Summary
                                Text(
                                  data.summary ?? '暂无内容介绍。',
                                  style: TextStyle(
                                    color: theme.onBackground
                                        .withValues(alpha: 0.8),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Episodes Grid
                                Text(
                                  '选集播放',
                                  style: TextStyle(
                                    color: theme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 180,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 2.2,
                                  ),
                                  itemCount: data.episodes.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final VideoDetailEpisode episode =
                                        data.episodes[index];
                                    final bool hasLocalMedia =
                                        episode.localMedia != null;

                                    return InkWell(
                                      mouseCursor: hasLocalMedia
                                          ? SystemMouseCursors.click
                                          : SystemMouseCursors.basic,
                                      onTap: hasLocalMedia
                                          ? () => _selectEpisode(episode)
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: hasLocalMedia
                                              ? theme.surface
                                              : theme.surface
                                                  .withValues(alpha: 0.3),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          border: Border.all(
                                            color: hasLocalMedia
                                                ? theme.border
                                                : theme.border
                                                    .withValues(alpha: 0.3),
                                            width: 1.0,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: <Widget>[
                                            Text(
                                              '第 ${episode.index} 话',
                                              style: TextStyle(
                                                color: hasLocalMedia
                                                    ? theme.primary
                                                    : theme.onBackground
                                                        .withValues(alpha: 0.4),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              episode.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: hasLocalMedia
                                                    ? theme.onSurface
                                                    : theme.onSurface
                                                        .withValues(alpha: 0.4),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
