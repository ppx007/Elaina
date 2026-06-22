import 'package:flutter/material.dart';

import '../../domain/detail/video_detail.dart';
import '../../domain/media/media_library.dart';
import '../../domain/playback/playback_controller.dart';
import '../../domain/playback/playback_source_handoff.dart';
import '../testing/ui_element_ids.dart';
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
  static const double _pagePadding = 24;
  static const double _contentMaxWidth = 1180;
  static const double _desktopBreakpoint = 820;
  static const double _posterWidth = 250;
  static const double _posterAspectRatio = 2 / 3;
  static const double _sectionGap = 26;
  static const double _episodeTileMaxWidth = 190;
  static const double _episodeTileAspectRatio = 2.35;
  static const double _sectionRadius = 8;
  static const double _staffCategorySpacing = 8;
  static const double _staffCategoryListGap = 14;
  static const double _trackingMenuBorderRadius = 8;
  static const List<VideoTrackingStatus> _trackedStatusOptions =
      <VideoTrackingStatus>[
    VideoTrackingStatus.planned,
    VideoTrackingStatus.watching,
    VideoTrackingStatus.completed,
    VideoTrackingStatus.onHold,
    VideoTrackingStatus.dropped,
  ];

  late Stream<VideoDetailViewData> _detailStream;
  String? _lastPromptedConflictKey;
  String? _selectedStaffRole;
  bool _trackingConflictDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _detailStream = _watchDetail();
  }

  @override
  void didUpdateWidget(VideoDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id.value != widget.id.value ||
        oldWidget.videoDetailPageContract != widget.videoDetailPageContract) {
      _detailStream = _watchDetail();
      _lastPromptedConflictKey = null;
      _selectedStaffRole = null;
      _trackingConflictDialogOpen = false;
    }
  }

  Stream<VideoDetailViewData> _watchDetail() {
    return widget.videoDetailPageContract.watch(widget.id);
  }

  Future<void> _continuePlayback(VideoDetailViewData data) async {
    final VideoDetailActionResult result =
        await widget.videoDetailPageContract.continuePlayback(widget.id);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showActionFailure(result, fallback: '无法继续播放');
      return;
    }
    final ContinueWatchingState? continueWatching = data.continueWatching;
    if (continueWatching == null) {
      _showSnackBar('没有可继续播放的进度');
      return;
    }
    final VideoDetailEpisode? episode = _episodeForMedia(
      data,
      continueWatching.mediaId,
    );
    if (episode == null || episode.localMedia == null) {
      _showSnackBar('没有找到对应的本地剧集');
      return;
    }
    await _playEpisode(episode);
  }

  Future<void> _selectEpisode(VideoDetailEpisode episode) async {
    final VideoDetailActionResult result = await widget.videoDetailPageContract
        .selectEpisode(widget.id, episode.id);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showActionFailure(result, fallback: '无法播放该剧集');
      return;
    }
    await _playEpisode(episode);
  }

  Future<void> _playEpisode(VideoDetailEpisode episode) async {
    final LocalMediaIdentity? localMedia = episode.localMedia;
    if (localMedia == null) {
      _showSnackBar('该剧集没有本地媒体文件');
      return;
    }
    const LocalPlaybackSourceHandoff handoff = LocalPlaybackSourceHandoff();
    final PlaybackSourceHandoffResult prepared = handoff.prepare(
      PlaybackSourceHandoffInput.localMediaIdentity(localMedia),
    );
    if (!prepared.isSuccess) {
      _showSnackBar(prepared.failure?.message ?? '无法解析播放源');
      return;
    }
    final DomainPlaybackCommandResult openResult =
        await widget.playbackController.open(prepared.source!);
    if (!mounted) return;
    if (!openResult.isSuccess) {
      _showSnackBar(openResult.failure?.message ?? '播放器打开失败');
      return;
    }
    final DomainPlaybackCommandResult playResult =
        await widget.playbackController.play();
    if (!mounted) return;
    if (!playResult.isSuccess) {
      _showSnackBar(playResult.failure?.message ?? '播放器启动失败');
      return;
    }
    widget.onPlaybackStarted();
  }

  VideoDetailEpisode? _episodeForMedia(
    VideoDetailViewData data,
    LocalMediaId mediaId,
  ) {
    for (final VideoDetailEpisode episode in data.episodes) {
      if (episode.localMediaId?.value == mediaId.value ||
          episode.localMedia?.id.value == mediaId.value) {
        return episode;
      }
    }
    return null;
  }

  VideoDetailEpisode? _firstPlayableEpisode(VideoDetailViewData data) {
    for (final VideoDetailEpisode episode in data.episodes) {
      if (episode.localMedia != null) return episode;
    }
    return null;
  }

  void _showActionFailure(
    VideoDetailActionResult result, {
    required String fallback,
  }) {
    _showSnackBar(result.failure?.message ?? fallback);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _setTrackingStatus(VideoTrackingStatus status) async {
    final VideoDetailActionResult result = await widget.videoDetailPageContract
        .setTrackingStatus(widget.id, status);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showSnackBar(result.failure?.message ?? '无法更新追番状态');
      return;
    }
    setState(() {
      _detailStream = _watchDetail();
    });
  }

  void _scheduleTrackingConflictPrompt(VideoDetailViewData data) {
    final VideoTrackingConflict? conflict = data.trackingConflict;
    if (conflict == null || _trackingConflictDialogOpen) return;
    final String conflictKey = _trackingConflictKey(conflict);
    if (_lastPromptedConflictKey == conflictKey) return;
    _lastPromptedConflictKey = conflictKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showTrackingConflictDialog(conflict);
    });
  }

  Future<void> _showTrackingConflictDialog(
    VideoTrackingConflict conflict,
  ) async {
    _trackingConflictDialogOpen = true;
    final ElainaThemeData theme = ElainaTheme.of(context);
    final VideoTrackingConflictResolution? resolution =
        await showDialog<VideoTrackingConflictResolution>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.surface,
          title: Text(
            '追番状态冲突',
            style: TextStyle(color: theme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ConflictLine(label: '条目', value: conflict.title),
              _ConflictLine(
                label: '本地状态',
                value: _trackingComparisonLabel(conflict.localStatus),
              ),
              _ConflictLine(
                label: '本地更新时间',
                value: _formatConflictUpdatedAt(conflict.localUpdatedAt),
              ),
              _ConflictLine(
                label: '云端状态',
                value: _trackingComparisonLabel(conflict.remoteStatus),
              ),
              _ConflictLine(
                label: '云端更新时间',
                value: _formatConflictUpdatedAt(conflict.remoteUpdatedAt),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('暂不处理', style: TextStyle(color: theme.onSurface)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                VideoTrackingConflictResolution.remoteToLocal,
              ),
              child: Text('云端同步到本地', style: TextStyle(color: theme.primary)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                VideoTrackingConflictResolution.localToRemote,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: theme.background,
              ),
              child: const Text('本地同步到云端'),
            ),
          ],
        );
      },
    );
    _trackingConflictDialogOpen = false;
    if (!mounted || resolution == null) return;

    final VideoDetailActionResult result = await widget.videoDetailPageContract
        .resolveTrackingConflict(widget.id, resolution);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showSnackBar(result.failure?.message ?? '无法同步追番状态');
      return;
    }
    setState(() {
      _detailStream = _watchDetail();
    });
  }

  String _trackingLabel(VideoTrackingStatus status) {
    return switch (status) {
      VideoTrackingStatus.notTracked => '加入追番',
      VideoTrackingStatus.planned => '想看',
      VideoTrackingStatus.watching => '在追',
      VideoTrackingStatus.completed => '已看',
      VideoTrackingStatus.onHold => '搁置',
      VideoTrackingStatus.dropped => '抛弃',
    };
  }

  String _trackingComparisonLabel(VideoTrackingStatus status) {
    return status == VideoTrackingStatus.notTracked
        ? '未追番'
        : _trackingLabel(status);
  }

  IconData _trackingIcon(VideoTrackingStatus status) {
    return switch (status) {
      VideoTrackingStatus.notTracked => Icons.favorite_border,
      VideoTrackingStatus.planned => Icons.bookmark_border,
      VideoTrackingStatus.watching => Icons.favorite,
      VideoTrackingStatus.completed => Icons.task_alt,
      VideoTrackingStatus.onHold => Icons.pause_circle_outline,
      VideoTrackingStatus.dropped => Icons.block,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: StreamBuilder<VideoDetailViewData>(
        key: ValueKey<String>(widget.id.value),
        stream: _detailStream,
        builder: (
          BuildContext context,
          AsyncSnapshot<VideoDetailViewData> snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '加载详情失败: ${snapshot.error}',
                style: TextStyle(color: theme.onSurface),
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: theme.primary),
            );
          }
          final VideoDetailViewData data = snapshot.data!;
          _scheduleTrackingConflictPrompt(data);
          return _buildDetailSurface(theme, data);
        },
      ),
    );
  }

  Widget _buildDetailSurface(
    ElainaThemeData theme,
    VideoDetailViewData data,
  ) {
    return SafeArea(
      child: Column(
        children: <Widget>[
          _buildTopBar(theme, data),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(_pagePadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                  child: LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      final bool desktop =
                          constraints.maxWidth >= _desktopBreakpoint;
                      final Widget posterColumn =
                          _buildPosterColumn(theme, data);
                      final Widget informationColumn =
                          _buildInformationColumn(theme, data);
                      if (!desktop) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: _posterWidth,
                                child: posterColumn,
                              ),
                            ),
                            const SizedBox(height: _sectionGap),
                            informationColumn,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(width: _posterWidth, child: posterColumn),
                          const SizedBox(width: 32),
                          Expanded(child: informationColumn),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ElainaThemeData theme, VideoDetailViewData data) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const ValueKey<String>(UiElementIds.videoDetailClose),
              tooltip: '返回',
              icon: const Icon(Icons.arrow_back),
              color: theme.onSurface,
              onPressed: widget.onClose,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterColumn(ElainaThemeData theme, VideoDetailViewData data) {
    final bool isTracked =
        data.trackingStatus != VideoTrackingStatus.notTracked;
    final VideoDetailEpisode? playableEpisode = _firstPlayableEpisode(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PosterFrame(coverUri: data.coverUri, theme: theme),
        const SizedBox(height: 16),
        _TrackingStatusMenuButton(
          currentStatus: data.trackingStatus,
          isTracked: isTracked,
          theme: theme,
          statusOptions: _trackedStatusOptions,
          labelFor: _trackingLabel,
          iconFor: _trackingIcon,
          onSelected: _setTrackingStatus,
          borderRadius: _trackingMenuBorderRadius,
        ),
        const SizedBox(height: 12),
        if (playableEpisode != null)
          OutlinedButton.icon(
            onPressed: () => _selectEpisode(playableEpisode),
            icon: const Icon(Icons.play_arrow),
            label: Text('播放第 ${playableEpisode.index} 话'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primary,
              side: BorderSide(color: theme.primary),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildInformationColumn(
    ElainaThemeData theme,
    VideoDetailViewData data,
  ) {
    final VideoDetailEpisode? playableEpisode = _firstPlayableEpisode(data);
    final bool hasContinueWatching = data.continueWatching != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(
                data.title,
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _StatusBadge(
              label: _trackingComparisonLabel(data.trackingStatus),
              icon: _trackingIcon(data.trackingStatus),
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildStatsStrip(theme, data.metadataStats),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            if (hasContinueWatching)
              ElevatedButton.icon(
                onPressed: () => _continuePlayback(data),
                icon: const Icon(Icons.play_circle_fill, size: 18),
                label: const Text('继续观看'),
                style: _primaryButtonStyle(theme),
              )
            else if (playableEpisode != null)
              ElevatedButton.icon(
                onPressed: () => _selectEpisode(playableEpisode),
                icon: const Icon(Icons.play_circle_fill, size: 18),
                label: Text('播放第 ${playableEpisode.index} 话'),
                style: _primaryButtonStyle(theme),
              ),
          ],
        ),
        const SizedBox(height: _sectionGap),
        _buildSummarySection(theme, data),
        const SizedBox(height: _sectionGap),
        _buildEpisodeSection(theme, data),
        const SizedBox(height: _sectionGap),
        _buildStaffSection(theme, data),
        const SizedBox(height: _sectionGap),
        _buildCharacterSection(theme, data),
        const SizedBox(height: _sectionGap),
        _buildRelationSection(theme, data),
      ],
    );
  }

  ButtonStyle _primaryButtonStyle(ElainaThemeData theme) {
    return ElevatedButton.styleFrom(
      backgroundColor: theme.primary,
      foregroundColor: theme.background,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    );
  }

  Widget _buildStatsStrip(
    ElainaThemeData theme,
    VideoDetailMetadataStats stats,
  ) {
    final List<Widget> metrics = <Widget>[
      if (stats.score != null)
        _MetricPill(
          label: '评分',
          value: stats.score!.toStringAsFixed(1),
          icon: Icons.star,
          theme: theme,
        ),
      if (stats.rank != null)
        _MetricPill(
          label: '排名',
          value: '#${stats.rank}',
          icon: Icons.leaderboard,
          theme: theme,
        ),
      if (stats.collectionTotal != null)
        _MetricPill(
          label: '收藏',
          value: '${stats.collectionTotal}',
          icon: Icons.people_alt,
          theme: theme,
        ),
      if (stats.episodeCount != null)
        _MetricPill(
          label: '话数',
          value: '${stats.episodeCount}',
          icon: Icons.video_library,
          theme: theme,
        ),
    ];
    if (metrics.isEmpty) {
      return Text(
        'Bangumi 暂无评分与收藏统计',
        style: TextStyle(color: theme.onBackground.withValues(alpha: 0.62)),
      );
    }
    return Wrap(spacing: 10, runSpacing: 10, children: metrics);
  }

  Widget _buildSummarySection(ElainaThemeData theme, VideoDetailViewData data) {
    return _SectionBlock(
      theme: theme,
      title: '简介',
      child: Text(
        data.summary ?? '暂无内容介绍。',
        style: TextStyle(
          color: theme.onBackground.withValues(alpha: 0.82),
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildEpisodeSection(ElainaThemeData theme, VideoDetailViewData data) {
    return _SectionBlock(
      theme: theme,
      title: '选集播放',
      child: _buildEpisodeGrid(theme, data),
    );
  }

  Widget _buildEpisodeGrid(ElainaThemeData theme, VideoDetailViewData data) {
    if (data.episodes.isEmpty) {
      return _EmptyLine(theme: theme, text: '暂无剧集');
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _episodeTileMaxWidth,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: _episodeTileAspectRatio,
      ),
      itemCount: data.episodes.length,
      itemBuilder: (BuildContext context, int index) {
        final VideoDetailEpisode episode = data.episodes[index];
        return _EpisodeTile(
          episode: episode,
          theme: theme,
          onTap:
              episode.localMedia == null ? null : () => _selectEpisode(episode),
        );
      },
    );
  }

  Widget _buildStaffSection(ElainaThemeData theme, VideoDetailViewData data) {
    final VideoDetailMetadataFailure? failure =
        _metadataFailureFor(data, VideoDetailMetadataSection.staff);
    if (failure != null) {
      return _SectionBlock(
        theme: theme,
        title: '制作人员',
        child: _EmptyLine(theme: theme, text: '制作人员加载失败: ${failure.message}'),
      );
    }
    if (data.credits.isEmpty) {
      return _SectionBlock(
        theme: theme,
        title: '制作人员',
        child: _EmptyLine(theme: theme, text: '暂无制作人员数据'),
      );
    }
    final List<_StaffCategory> categories = _staffCategories(data.credits);
    final String selectedRole = _selectedStaffRole == null ||
            !categories.any(
              (_StaffCategory category) => category.role == _selectedStaffRole,
            )
        ? categories.first.role
        : _selectedStaffRole!;
    final List<VideoDetailCredit> selectedCredits = categories
        .firstWhere((_StaffCategory category) => category.role == selectedRole)
        .credits;
    return _SectionBlock(
      theme: theme,
      title: '制作人员',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: _staffCategorySpacing,
            runSpacing: _staffCategorySpacing,
            children: <Widget>[
              for (final _StaffCategory category in categories)
                _StaffCategoryChip(
                  category: category,
                  selected: category.role == selectedRole,
                  theme: theme,
                  onSelected: () {
                    setState(() {
                      _selectedStaffRole = category.role;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: _staffCategoryListGap),
          for (final VideoDetailCredit credit in selectedCredits)
            _StaffRow(credit: credit, theme: theme),
        ],
      ),
    );
  }

  List<_StaffCategory> _staffCategories(List<VideoDetailCredit> credits) {
    final Map<String, List<VideoDetailCredit>> grouped =
        <String, List<VideoDetailCredit>>{};
    for (final VideoDetailCredit credit in credits) {
      grouped.putIfAbsent(credit.role, () => <VideoDetailCredit>[]).add(credit);
    }
    return grouped.entries
        .map(
          (MapEntry<String, List<VideoDetailCredit>> entry) => _StaffCategory(
            role: entry.key,
            credits: List<VideoDetailCredit>.unmodifiable(entry.value),
          ),
        )
        .toList(growable: false);
  }

  Widget _buildCharacterSection(
      ElainaThemeData theme, VideoDetailViewData data) {
    final VideoDetailMetadataFailure? failure =
        _metadataFailureFor(data, VideoDetailMetadataSection.characters);
    if (failure != null) {
      return _SectionBlock(
        theme: theme,
        title: '角色与声优',
        child: _EmptyLine(theme: theme, text: '角色与声优加载失败: ${failure.message}'),
      );
    }
    if (data.characters.isEmpty) {
      return _SectionBlock(
        theme: theme,
        title: '角色与声优',
        child: _EmptyLine(theme: theme, text: '暂无角色与声优数据'),
      );
    }
    return _SectionBlock(
      theme: theme,
      title: '角色与声优',
      child: Column(
        children: <Widget>[
          for (final VideoDetailCharacter character in data.characters)
            _CharacterRow(character: character, theme: theme),
        ],
      ),
    );
  }

  Widget _buildRelationSection(
      ElainaThemeData theme, VideoDetailViewData data) {
    final VideoDetailMetadataFailure? failure =
        _metadataFailureFor(data, VideoDetailMetadataSection.relations);
    if (failure != null) {
      return _SectionBlock(
        theme: theme,
        title: '关联条目',
        child: _EmptyLine(theme: theme, text: '关联条目加载失败: ${failure.message}'),
      );
    }
    if (data.relations.isEmpty) {
      return _SectionBlock(
        theme: theme,
        title: '关联条目',
        child: _EmptyLine(theme: theme, text: '暂无关联条目'),
      );
    }
    return _SectionBlock(
      theme: theme,
      title: '关联条目',
      child: Column(
        children: <Widget>[
          for (final VideoDetailRelatedSubject relation in data.relations)
            _RelationRow(relation: relation, theme: theme),
        ],
      ),
    );
  }

  VideoDetailMetadataFailure? _metadataFailureFor(
    VideoDetailViewData data,
    VideoDetailMetadataSection section,
  ) {
    for (final VideoDetailMetadataFailure failure in data.metadataFailures) {
      if (failure.section == section) return failure;
    }
    return null;
  }
}

typedef _TrackingLabelBuilder = String Function(VideoTrackingStatus status);
typedef _TrackingIconBuilder = IconData Function(VideoTrackingStatus status);

String _trackingConflictKey(VideoTrackingConflict conflict) {
  return <String>[
    conflict.subjectId,
    conflict.localStatus.name,
    conflict.remoteStatus.name,
    conflict.localUpdatedAt.toUtc().toIso8601String(),
    conflict.remoteUpdatedAt?.toUtc().toIso8601String() ?? '',
  ].join('|');
}

String _formatConflictUpdatedAt(DateTime? value) {
  if (value == null) return '未知';
  final DateTime local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

final class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.theme,
    required this.title,
    required this.child,
  });

  final ElainaThemeData theme;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.76),
        border: Border.all(color: theme.border),
        borderRadius:
            BorderRadius.circular(_VideoDetailPageState._sectionRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

final class _EmptyLine extends StatelessWidget {
  const _EmptyLine({
    required this.theme,
    required this.text,
  });

  final ElainaThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: theme.onBackground.withValues(alpha: 0.62),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

final class _PosterFrame extends StatelessWidget {
  const _PosterFrame({
    required this.coverUri,
    required this.theme,
  });

  final Uri? coverUri;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _VideoDetailPageState._posterAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border.all(color: theme.border),
          ),
          child: coverUri == null
              ? _buildFallback()
              : Image.network(
                  coverUri.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return _buildFallback();
                  },
                  loadingBuilder: (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? loadingProgress,
                  ) {
                    if (loadingProgress == null) return child;
                    return _buildFallback();
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Icon(
        Icons.movie_filter_outlined,
        color: theme.primary.withValues(alpha: 0.56),
        size: 48,
      ),
    );
  }
}

final class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.theme,
  });

  final String label;
  final String value;
  final IconData icon;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: theme.primary),
            const SizedBox(width: 7),
            Text(
              '$label $value',
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.primary.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: theme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: theme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.theme,
    required this.onTap,
  });

  final VideoDetailEpisode episode;
  final ElainaThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool playable = onTap != null;
    final Color foreground =
        playable ? theme.onSurface : theme.onBackground.withValues(alpha: 0.42);
    final Color accent =
        playable ? theme.primary : theme.onBackground.withValues(alpha: 0.36);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor:
            playable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: playable
                ? theme.surface.withValues(alpha: 0.9)
                : theme.surface.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: playable
                  ? theme.border
                  : theme.border.withValues(alpha: 0.38),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: <Widget>[
                Icon(
                  playable ? Icons.play_arrow : Icons.lock_outline,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '第 ${episode.index} 话',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        episode.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _StaffCategory {
  const _StaffCategory({
    required this.role,
    required this.credits,
  });

  final String role;
  final List<VideoDetailCredit> credits;

  String get label => '$role ${credits.length}';
}

final class _StaffCategoryChip extends StatelessWidget {
  const _StaffCategoryChip({
    required this.category,
    required this.selected,
    required this.theme,
    required this.onSelected,
  });

  final _StaffCategory category;
  final bool selected;
  final ElainaThemeData theme;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ChoiceChip(
        label: Text(category.label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
        backgroundColor: theme.surface,
        selectedColor: theme.primary.withValues(alpha: 0.18),
        side: BorderSide(color: selected ? theme.primary : theme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(
          color: selected ? theme.primary : theme.onBackground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

final class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.credit,
    required this.theme,
  });

  final VideoDetailCredit credit;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    final String secondary = <String>[
      if (credit.careers.isNotEmpty) credit.careers.join(' / '),
      if (credit.episodeRange != null) credit.episodeRange!,
    ].join(' · ');
    return _InfoRow(
      theme: theme,
      leading: _ImageBadge(uri: credit.imageUri, icon: Icons.person),
      label: credit.role,
      title: credit.name,
      subtitle: secondary.isEmpty ? null : secondary,
    );
  }
}

final class _CharacterRow extends StatelessWidget {
  const _CharacterRow({
    required this.character,
    required this.theme,
  });

  final VideoDetailCharacter character;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    final String actors = character.voiceActors.isEmpty
        ? '暂无声优'
        : character.voiceActors
            .map((VideoDetailVoiceActor actor) => actor.name)
            .join(' / ');
    return _InfoRow(
      theme: theme,
      leading: _ImageBadge(uri: character.imageUri, icon: Icons.face),
      label: character.role,
      title: character.name,
      subtitle: '声优: $actors',
    );
  }
}

final class _RelationRow extends StatelessWidget {
  const _RelationRow({
    required this.relation,
    required this.theme,
  });

  final VideoDetailRelatedSubject relation;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return _InfoRow(
      theme: theme,
      leading: _ImageBadge(uri: relation.coverUri, icon: Icons.movie),
      label: relation.relation,
      title: relation.title,
      subtitle: 'Bangumi ID: ${relation.id}',
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.theme,
    required this.leading,
    required this.label,
    required this.title,
    this.subtitle,
  });

  final ElainaThemeData theme;
  final Widget leading;
  final String label;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _SmallLabel(label: label, theme: theme),
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.onBackground.withValues(alpha: 0.68),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _SmallLabel extends StatelessWidget {
  const _SmallLabel({
    required this.label,
    required this.theme,
  });

  final String label;
  final ElainaThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            color: theme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

final class _ImageBadge extends StatelessWidget {
  const _ImageBadge({
    required this.uri,
    required this.icon,
  });

  final Uri? uri;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.background.withValues(alpha: 0.44),
          border: Border.all(color: theme.border),
        ),
        child: SizedBox(
          width: 46,
          height: 58,
          child: uri == null
              ? Icon(icon, color: theme.primary.withValues(alpha: 0.62))
              : Image.network(
                  uri.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return Icon(
                      icon,
                      color: theme.primary.withValues(alpha: 0.62),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

final class _TrackingStatusMenuButton extends StatelessWidget {
  const _TrackingStatusMenuButton({
    required this.currentStatus,
    required this.isTracked,
    required this.theme,
    required this.statusOptions,
    required this.labelFor,
    required this.iconFor,
    required this.onSelected,
    required this.borderRadius,
  });

  final VideoTrackingStatus currentStatus;
  final bool isTracked;
  final ElainaThemeData theme;
  final List<VideoTrackingStatus> statusOptions;
  final _TrackingLabelBuilder labelFor;
  final _TrackingIconBuilder iconFor;
  final ValueChanged<VideoTrackingStatus> onSelected;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final Color background = isTracked ? theme.secondary : theme.primary;
    return PopupMenuButton<VideoTrackingStatus>(
      tooltip: '修改追番状态',
      color: theme.surface,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<VideoTrackingStatus>>[
          for (final VideoTrackingStatus status in statusOptions)
            PopupMenuItem<VideoTrackingStatus>(
              value: status,
              child: _TrackingStatusMenuItem(
                status: status,
                selected: currentStatus == status,
                theme: theme,
                labelFor: labelFor,
                iconFor: iconFor,
              ),
            ),
        ];
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  iconFor(currentStatus),
                  size: 16,
                  color: theme.background,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    labelFor(currentStatus),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.background,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: theme.background,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _TrackingStatusMenuItem extends StatelessWidget {
  const _TrackingStatusMenuItem({
    required this.status,
    required this.selected,
    required this.theme,
    required this.labelFor,
    required this.iconFor,
  });

  final VideoTrackingStatus status;
  final bool selected;
  final ElainaThemeData theme;
  final _TrackingLabelBuilder labelFor;
  final _TrackingIconBuilder iconFor;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? theme.primary : theme.onSurface;
    return Row(
      children: <Widget>[
        Icon(iconFor(status), size: 18, color: foreground),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            labelFor(status),
            style: TextStyle(
              color: foreground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (selected) Icon(Icons.check, size: 16, color: theme.primary),
      ],
    );
  }
}

final class _ConflictLine extends StatelessWidget {
  const _ConflictLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: theme.onSurface, fontSize: 14),
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
