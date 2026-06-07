import 'dart:async';

sealed class CacheInvalidationEvent {
  const CacheInvalidationEvent({required this.occurredAt});

  final DateTime occurredAt;
}

final class DanmakuPosted extends CacheInvalidationEvent {
  const DanmakuPosted({
    required super.occurredAt,
    required this.subjectId,
    required this.episodeId,
  });

  final String subjectId;
  final String episodeId;
}

final class BindingChanged extends CacheInvalidationEvent {
  const BindingChanged({
    required super.occurredAt,
    required this.localMediaId,
    this.providerId,
    this.providerSubjectId,
  });

  final String localMediaId;
  final String? providerId;
  final String? providerSubjectId;
}

final class ProviderAuthChanged extends CacheInvalidationEvent {
  const ProviderAuthChanged({
    required super.occurredAt,
    required this.providerId,
  });

  final String providerId;
}

enum MediaLibraryChangeKind {
  created,
  updated,
  removed,
}

final class MediaLibraryItemChanged extends CacheInvalidationEvent {
  const MediaLibraryItemChanged({
    required super.occurredAt,
    required this.mediaLibraryItemId,
    required this.localMediaId,
    required this.changeKind,
  });

  final String mediaLibraryItemId;
  final String localMediaId;
  final MediaLibraryChangeKind changeKind;
}

final class LibraryItemAdded extends MediaLibraryItemChanged {
  const LibraryItemAdded({
    required super.occurredAt,
    required super.mediaLibraryItemId,
    required super.localMediaId,
  }) : super(changeKind: MediaLibraryChangeKind.created);
}

final class LibraryItemUpdated extends MediaLibraryItemChanged {
  const LibraryItemUpdated({
    required super.occurredAt,
    required super.mediaLibraryItemId,
    required super.localMediaId,
  }) : super(changeKind: MediaLibraryChangeKind.updated);
}

final class LibraryItemRemoved extends MediaLibraryItemChanged {
  const LibraryItemRemoved({
    required super.occurredAt,
    required super.mediaLibraryItemId,
    required super.localMediaId,
  }) : super(changeKind: MediaLibraryChangeKind.removed);
}

final class HistoryRecorded extends CacheInvalidationEvent {
  const HistoryRecorded(
      {required super.occurredAt, required this.localMediaId});

  final String localMediaId;
}

final class SeasonalCatalogUpdated extends CacheInvalidationEvent {
  const SeasonalCatalogUpdated({
    required super.occurredAt,
    required this.seasonalCatalogEntryId,
    required this.seasonYear,
    required this.seasonKind,
  });

  final String seasonalCatalogEntryId;
  final int seasonYear;
  final String seasonKind;
}

final class BangumiMatchEnqueued extends CacheInvalidationEvent {
  const BangumiMatchEnqueued({
    required super.occurredAt,
    required this.queueItemId,
    required this.seasonalCatalogEntryId,
  });

  final String queueItemId;
  final String seasonalCatalogEntryId;
}

final class BangumiMatchApplied extends CacheInvalidationEvent {
  const BangumiMatchApplied({
    required super.occurredAt,
    required this.queueItemId,
    required this.bindingId,
    required this.localMediaId,
    required this.providerSubjectId,
  });

  final String queueItemId;
  final String bindingId;
  final String localMediaId;
  final String providerSubjectId;
}

final class BtTaskCreated extends CacheInvalidationEvent {
  const BtTaskCreated({
    required super.occurredAt,
    required this.taskId,
    required this.sourceKind,
  });

  final String taskId;
  final String sourceKind;
}

final class BtMetadataUpdated extends CacheInvalidationEvent {
  const BtMetadataUpdated({
    required super.occurredAt,
    required this.taskId,
    required this.infoHash,
    required this.name,
  });

  final String taskId;
  final String infoHash;
  final String name;
}

final class BtTaskLifecycleChanged extends CacheInvalidationEvent {
  const BtTaskLifecycleChanged({
    required super.occurredAt,
    required this.taskId,
    required this.previousState,
    required this.newState,
  });

  final String taskId;
  final String previousState;
  final String newState;
}

final class BtTaskFileSelectionChanged extends CacheInvalidationEvent {
  const BtTaskFileSelectionChanged({
    required super.occurredAt,
    required this.taskId,
  });

  final String taskId;
}

final class BtTaskRemoved extends CacheInvalidationEvent {
  const BtTaskRemoved({required super.occurredAt, required this.taskId});

  final String taskId;
}

final class VirtualStreamCreated extends CacheInvalidationEvent {
  const VirtualStreamCreated({
    required super.occurredAt,
    required this.streamId,
    required this.taskId,
    required this.fileIndex,
  });

  final String streamId;
  final String taskId;
  final int fileIndex;
}

final class VirtualStreamRangeBuffered extends CacheInvalidationEvent {
  const VirtualStreamRangeBuffered({
    required super.occurredAt,
    required this.streamId,
    required this.startByte,
    required this.endByte,
  });

  final String streamId;
  final int startByte;
  final int endByte;
}

final class VirtualStreamRangeFailed extends CacheInvalidationEvent {
  const VirtualStreamRangeFailed({
    required super.occurredAt,
    required this.streamId,
    required this.failureKind,
    this.startByte,
    this.endByte,
  });

  final String streamId;
  final String failureKind;
  final int? startByte;
  final int? endByte;
}

final class VirtualStreamClosed extends CacheInvalidationEvent {
  const VirtualStreamClosed(
      {required super.occurredAt, required this.streamId});

  final String streamId;
}

final class PiecePriorityPlanGenerated extends CacheInvalidationEvent {
  const PiecePriorityPlanGenerated({
    required super.occurredAt,
    required this.taskId,
    required this.streamId,
    required this.planId,
    required this.profileId,
  });

  final String taskId;
  final String streamId;
  final String planId;
  final String profileId;
}

final class PiecePriorityPlanApplied extends CacheInvalidationEvent {
  const PiecePriorityPlanApplied({
    required super.occurredAt,
    required this.taskId,
    required this.streamId,
    required this.planId,
    required this.profileId,
  });

  final String taskId;
  final String streamId;
  final String planId;
  final String profileId;
}

final class PiecePriorityPlanRejected extends CacheInvalidationEvent {
  const PiecePriorityPlanRejected({
    required super.occurredAt,
    required this.taskId,
    required this.streamId,
    required this.planId,
    required this.profileId,
    this.failureKind,
  });

  final String taskId;
  final String streamId;
  final String planId;
  final String profileId;
  final String? failureKind;
}

final class PiecePriorityProfileChanged extends CacheInvalidationEvent {
  const PiecePriorityProfileChanged({
    required super.occurredAt,
    required this.taskId,
    required this.streamId,
    required this.profileId,
  });

  final String taskId;
  final String streamId;
  final String profileId;
}

final class TimelineOverlaySnapshotRefreshed extends CacheInvalidationEvent {
  const TimelineOverlaySnapshotRefreshed({
    required super.occurredAt,
    required this.streamId,
    required this.layerCount,
  });

  final String streamId;
  final int layerCount;
}

final class TimelineOverlayLayerConfigurationChanged
    extends CacheInvalidationEvent {
  const TimelineOverlayLayerConfigurationChanged({
    required super.occurredAt,
    required this.streamId,
    required this.profileId,
  });

  final String streamId;
  final String profileId;
}

final class TimelineOverlayCompositionRejected extends CacheInvalidationEvent {
  const TimelineOverlayCompositionRejected({
    required super.occurredAt,
    required this.streamId,
    required this.failureKind,
  });

  final String streamId;
  final String failureKind;
}

enum EnhancementProfileChangeKind {
  created,
  updated,
  removed,
  activated,
}

final class EnhancementProfileChanged extends CacheInvalidationEvent {
  const EnhancementProfileChanged({
    required super.occurredAt,
    required this.profileId,
    required this.changeKind,
    this.scopeId,
  });

  final String profileId;
  final EnhancementProfileChangeKind changeKind;
  final String? scopeId;
}

final class EnhancementCapabilityReevaluated extends CacheInvalidationEvent {
  const EnhancementCapabilityReevaluated({
    required super.occurredAt,
    required this.profileId,
    required this.supported,
    this.reason,
  });

  final String profileId;
  final bool supported;
  final String? reason;
}

final class EnhancementPipelineStateChanged extends CacheInvalidationEvent {
  const EnhancementPipelineStateChanged({
    required super.occurredAt,
    required this.scopeId,
    required this.previousState,
    required this.newState,
    this.profileId,
    this.failureKind,
  });

  final String scopeId;
  final String previousState;
  final String newState;
  final String? profileId;
  final String? failureKind;
}

final class AVSyncSampleIngested extends CacheInvalidationEvent {
  const AVSyncSampleIngested({
    required super.occurredAt,
    required this.scopeId,
    required this.driftMillis,
    required this.health,
  });

  final String scopeId;
  final int driftMillis;
  final String health;
}

final class AVSyncHealthTransitioned extends CacheInvalidationEvent {
  const AVSyncHealthTransitioned({
    required super.occurredAt,
    required this.scopeId,
    required this.previousHealth,
    required this.newHealth,
    required this.reason,
  });

  final String scopeId;
  final String previousHealth;
  final String newHealth;
  final String reason;
}

final class AVSyncDegradationDecisionRecorded extends CacheInvalidationEvent {
  const AVSyncDegradationDecisionRecorded({
    required super.occurredAt,
    required this.scopeId,
    required this.action,
    required this.health,
    required this.reason,
  });

  final String scopeId;
  final String action;
  final String health;
  final String reason;
}

final class AVSyncRecoveryStateChanged extends CacheInvalidationEvent {
  const AVSyncRecoveryStateChanged({
    required super.occurredAt,
    required this.scopeId,
    required this.recoveredHealth,
  });

  final String scopeId;
  final String recoveredHealth;
}

enum AdvancedCaptionProfileChangeKind {
  created,
  updated,
  removed,
  activated,
}

final class AdvancedCaptionProfileChanged extends CacheInvalidationEvent {
  const AdvancedCaptionProfileChanged({
    required super.occurredAt,
    required this.profileId,
    required this.changeKind,
    this.scopeId,
  });

  final String profileId;
  final AdvancedCaptionProfileChangeKind changeKind;
  final String? scopeId;
}

final class AdvancedCaptionCapabilityReevaluated
    extends CacheInvalidationEvent {
  const AdvancedCaptionCapabilityReevaluated({
    required super.occurredAt,
    required this.profileId,
    required this.supported,
    this.reason,
  });

  final String profileId;
  final bool supported;
  final String? reason;
}

final class AdvancedCaptionRendererStateChanged
    extends CacheInvalidationEvent {
  const AdvancedCaptionRendererStateChanged({
    required super.occurredAt,
    required this.scopeId,
    required this.previousState,
    required this.newState,
    this.profileId,
    this.feature,
    this.failureKind,
  });

  final String scopeId;
  final String previousState;
  final String newState;
  final String? profileId;
  final String? feature;
  final String? failureKind;
}

final class AdvancedCaptionDualSubtitleSelectionChanged
    extends CacheInvalidationEvent {
  const AdvancedCaptionDualSubtitleSelectionChanged({
    required super.occurredAt,
    required this.scopeId,
    required this.profileId,
    required this.primarySubtitleId,
    required this.secondarySubtitleId,
    this.primaryLanguageCode,
    this.secondaryLanguageCode,
  });

  final String scopeId;
  final String profileId;
  final String primarySubtitleId;
  final String secondarySubtitleId;
  final String? primaryLanguageCode;
  final String? secondaryLanguageCode;
}

final class AdvancedCaptionDegradationStateChanged
    extends CacheInvalidationEvent {
  const AdvancedCaptionDegradationStateChanged({
    required super.occurredAt,
    required this.scopeId,
    required this.degraded,
    required this.reason,
    this.profileId,
  });

  final String scopeId;
  final bool degraded;
  final String reason;
  final String? profileId;
}

abstract interface class CacheInvalidationBus {
  Stream<CacheInvalidationEvent> get events;

  void publish(CacheInvalidationEvent event);
}

final class StreamCacheInvalidationBus implements CacheInvalidationBus {
  StreamCacheInvalidationBus()
      : _controller =
            StreamController<CacheInvalidationEvent>.broadcast(sync: true);

  final StreamController<CacheInvalidationEvent> _controller;

  @override
  Stream<CacheInvalidationEvent> get events => _controller.stream;

  @override
  void publish(CacheInvalidationEvent event) {
    if (_controller.isClosed) {
      throw StateError('Cannot publish after CacheInvalidationBus is closed.');
    }
    _controller.add(event);
  }

  Future<void> close() => _controller.close();
}
