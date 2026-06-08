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

enum RssAutoDownloadPolicyChangeKind {
  registered,
  updated,
  disabled,
  removed,
}

final class RssAutoDownloadPolicyChanged extends CacheInvalidationEvent {
  const RssAutoDownloadPolicyChanged({
    required super.occurredAt,
    required this.policyId,
    required this.changeKind,
    this.sourceId,
  });

  final String policyId;
  final RssAutoDownloadPolicyChangeKind changeKind;
  final String? sourceId;
}

final class RssAutoDownloadFeedItemEvaluated
    extends CacheInvalidationEvent {
  const RssAutoDownloadFeedItemEvaluated({
    required super.occurredAt,
    required this.policyId,
    required this.feedItemId,
    required this.sourceId,
    required this.outcomeKind,
    this.ruleId,
  });

  final String policyId;
  final String? ruleId;
  final String feedItemId;
  final String sourceId;
  final String outcomeKind;
}

final class RssAutoDownloadCandidateAccepted
    extends CacheInvalidationEvent {
  const RssAutoDownloadCandidateAccepted({
    required super.occurredAt,
    required this.policyId,
    required this.ruleId,
    required this.candidateDedupeKey,
    required this.feedItemId,
    required this.sourceId,
  });

  final String policyId;
  final String ruleId;
  final String candidateDedupeKey;
  final String feedItemId;
  final String sourceId;
}

final class RssAutoDownloadCandidateRejected
    extends CacheInvalidationEvent {
  const RssAutoDownloadCandidateRejected({
    required super.occurredAt,
    required this.policyId,
    required this.feedItemId,
    required this.sourceId,
    required this.reason,
    this.ruleId,
  });

  final String policyId;
  final String? ruleId;
  final String feedItemId;
  final String sourceId;
  final String reason;
}

final class RssAutoDownloadDedupeStateChanged
    extends CacheInvalidationEvent {
  const RssAutoDownloadDedupeStateChanged({
    required super.occurredAt,
    required this.policyId,
    required this.candidateDedupeKey,
    required this.candidateId,
  });

  final String policyId;
  final String candidateDedupeKey;
  final String candidateId;
}

final class RssAutoDownloadEnqueueOutcomeRecorded
    extends CacheInvalidationEvent {
  const RssAutoDownloadEnqueueOutcomeRecorded({
    required super.occurredAt,
    required this.policyId,
    required this.candidateId,
    required this.state,
    this.taskId,
  });

  final String policyId;
  final String candidateId;
  final String state;
  final String? taskId;
}

enum OnlineRuleManifestChangeKind {
  registered,
  updated,
  disabled,
  removed,
}

final class OnlineRuleManifestChanged extends CacheInvalidationEvent {
  const OnlineRuleManifestChanged({
    required super.occurredAt,
    required this.sourceId,
    required this.changeKind,
    this.version,
  });

  final String sourceId;
  final OnlineRuleManifestChangeKind changeKind;
  final String? version;
}

final class OnlineRuleValidationStateChanged extends CacheInvalidationEvent {
  const OnlineRuleValidationStateChanged({
    required super.occurredAt,
    required this.sourceId,
    required this.valid,
    this.issueCount = 0,
  }) : assert(issueCount >= 0, 'issueCount must not be negative.');

  final String sourceId;
  final bool valid;
  final int issueCount;
}

final class OnlineRuleTargetEvaluated extends CacheInvalidationEvent {
  const OnlineRuleTargetEvaluated({
    required super.occurredAt,
    required this.sourceId,
    required this.target,
    required this.state,
  });

  final String sourceId;
  final String target;
  final String state;
}

final class OnlineRulePageRetrievalOutcomeRecorded
    extends CacheInvalidationEvent {
  const OnlineRulePageRetrievalOutcomeRecorded({
    required super.occurredAt,
    required this.sourceId,
    required this.pageUri,
    required this.state,
  });

  final String sourceId;
  final Uri pageUri;
  final String state;
}

final class OnlineRuleUnsupportedOperationRecorded
    extends CacheInvalidationEvent {
  const OnlineRuleUnsupportedOperationRecorded({
    required super.occurredAt,
    required this.sourceId,
    required this.kind,
    required this.reason,
    this.operationId,
  });

  final String sourceId;
  final String? operationId;
  final String kind;
  final String reason;
}

final class OnlineRuleCapabilityChanged extends CacheInvalidationEvent {
  const OnlineRuleCapabilityChanged({
    required super.occurredAt,
    required this.sourceId,
    required this.supported,
    this.reason,
  });

  final String sourceId;
  final bool supported;
  final String? reason;
}

enum WebViewSessionChallengeChangeKind {
  required,
  opened,
  completed,
  captured,
  backfilled,
  expired,
  revoked,
  failed,
}

final class WebViewSessionChallengeChanged extends CacheInvalidationEvent {
  const WebViewSessionChallengeChanged({
    required super.occurredAt,
    required this.challengeRequestId,
    required this.providerScope,
    required this.origin,
    required this.changeKind,
    this.reason,
  });

  final String challengeRequestId;
  final String providerScope;
  final Uri origin;
  final WebViewSessionChallengeChangeKind changeKind;
  final String? reason;
}

final class WebViewSessionArtifactCaptured extends CacheInvalidationEvent {
  const WebViewSessionArtifactCaptured({
    required super.occurredAt,
    required this.challengeRequestId,
    required this.artifactId,
    required this.providerScope,
    required this.origin,
    required this.artifactKind,
  });

  final String challengeRequestId;
  final String artifactId;
  final String providerScope;
  final Uri origin;
  final String artifactKind;
}

final class WebViewSessionBackfillOutcomeRecorded
    extends CacheInvalidationEvent {
  const WebViewSessionBackfillOutcomeRecorded({
    required super.occurredAt,
    required this.attemptId,
    required this.challengeRequestId,
    required this.providerScope,
    required this.state,
    this.reason,
  });

  final String attemptId;
  final String challengeRequestId;
  final String providerScope;
  final String state;
  final String? reason;
}

final class WebViewSessionArtifactStateChanged extends CacheInvalidationEvent {
  const WebViewSessionArtifactStateChanged({
    required super.occurredAt,
    required this.artifactId,
    required this.providerScope,
    required this.state,
    this.reason,
  });

  final String artifactId;
  final String providerScope;
  final String state;
  final String? reason;
}

final class WebViewSessionCapabilityChanged extends CacheInvalidationEvent {
  const WebViewSessionCapabilityChanged({
    required super.occurredAt,
    required this.providerScope,
    required this.capability,
    required this.supported,
    this.reason,
  });

  final String providerScope;
  final String capability;
  final bool supported;
  final String? reason;
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

enum FallbackAdapterChangeKind {
  registered,
  deregistered,
}

final class FallbackAdapterRegistrationChanged
    extends CacheInvalidationEvent {
  const FallbackAdapterRegistrationChanged({
    required super.occurredAt,
    required this.adapterId,
    required this.changeKind,
  });

  final String adapterId;
  final FallbackAdapterChangeKind changeKind;
}

final class FallbackCapabilityReevaluated extends CacheInvalidationEvent {
  const FallbackCapabilityReevaluated({
    required super.occurredAt,
    required this.adapterId,
    required this.supported,
    this.reason,
  });

  final String adapterId;
  final bool supported;
  final String? reason;
}

final class FallbackSelectionChanged extends CacheInvalidationEvent {
  const FallbackSelectionChanged({
    required super.occurredAt,
    required this.scopeId,
    required this.reason,
    this.adapterId,
  });

  final String scopeId;
  final String? adapterId;
  final String reason;
}

final class FallbackStrategyStateChanged extends CacheInvalidationEvent {
  const FallbackStrategyStateChanged({
    required super.occurredAt,
    required this.scopeId,
    required this.previousState,
    required this.newState,
    this.adapterId,
    this.failureKind,
  });

  final String scopeId;
  final String previousState;
  final String newState;
  final String? adapterId;
  final String? failureKind;
}

final class FallbackDisabled extends CacheInvalidationEvent {
  const FallbackDisabled({required super.occurredAt, required this.scopeId});

  final String scopeId;
}

final class FallbackRejected extends CacheInvalidationEvent {
  const FallbackRejected({
    required super.occurredAt,
    required this.scopeId,
    required this.failureKind,
    required this.reason,
  });

  final String scopeId;
  final String failureKind;
  final String reason;
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
