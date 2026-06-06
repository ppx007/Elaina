enum StoredEnhancementPipelineStateKind {
  disabled,
  evaluated,
  applied,
  rejected,
  degraded,
}

final class StoredEnhancementProfileRecord {
  const StoredEnhancementProfileRecord({
    required this.id,
    required this.label,
    required this.scalerIntent,
    required this.hdrHandlingIntent,
    required this.debandIntent,
    required this.anime4kPresetIntent,
    required this.createdAt,
    required this.updatedAt,
    this.isBuiltIn = false,
  })  : assert(id != '', 'Enhancement profile id must not be empty.'),
        assert(label != '', 'Enhancement profile label must not be empty.'),
        assert(scalerIntent != '', 'Scaler intent must not be empty.'),
        assert(
            hdrHandlingIntent != '', 'HDR handling intent must not be empty.'),
        assert(debandIntent != '', 'Deband intent must not be empty.'),
        assert(anime4kPresetIntent != '',
            'Anime4K preset intent must not be empty.');

  final String id;
  final String label;
  final String scalerIntent;
  final String hdrHandlingIntent;
  final String debandIntent;
  final String anime4kPresetIntent;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  StoredEnhancementProfileRecord copyWith({
    String? label,
    String? scalerIntent,
    String? hdrHandlingIntent,
    String? debandIntent,
    String? anime4kPresetIntent,
    bool? isBuiltIn,
    DateTime? updatedAt,
  }) {
    return StoredEnhancementProfileRecord(
      id: id,
      label: label ?? this.label,
      scalerIntent: scalerIntent ?? this.scalerIntent,
      hdrHandlingIntent: hdrHandlingIntent ?? this.hdrHandlingIntent,
      debandIntent: debandIntent ?? this.debandIntent,
      anime4kPresetIntent: anime4kPresetIntent ?? this.anime4kPresetIntent,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class StoredActiveEnhancementProfileRecord {
  const StoredActiveEnhancementProfileRecord({
    required this.scopeId,
    required this.profileId,
    required this.selectedAt,
  })  : assert(
            scopeId != '', 'Enhancement selection scope id must not be empty.'),
        assert(profileId != '', 'Enhancement profile id must not be empty.');

  final String scopeId;
  final String profileId;
  final DateTime selectedAt;
}

final class StoredEnhancementPipelineStateRecord {
  const StoredEnhancementPipelineStateRecord({
    required this.scopeId,
    required this.state,
    required this.supported,
    required this.updatedAt,
    this.profileId,
    this.failureReason,
    this.budgetPressure,
    this.degradationTargetProfileId,
  })  : assert(scopeId != '', 'Enhancement state scope id must not be empty.'),
        assert(profileId == null || profileId != '',
            'Enhancement profile id must not be empty.'),
        assert(failureReason == null || failureReason != '',
            'Enhancement failure reason must not be empty.'),
        assert(budgetPressure == null || budgetPressure >= 0,
            'budgetPressure must not be negative.'),
        assert(
            degradationTargetProfileId == null ||
                degradationTargetProfileId != '',
            'Enhancement degradation target profile id must not be empty.');

  final String scopeId;
  final String? profileId;
  final StoredEnhancementPipelineStateKind state;
  final bool supported;
  final String? failureReason;
  final double? budgetPressure;
  final String? degradationTargetProfileId;
  final DateTime updatedAt;

  StoredEnhancementPipelineStateRecord copyWith({
    String? profileId,
    StoredEnhancementPipelineStateKind? state,
    bool? supported,
    String? failureReason,
    double? budgetPressure,
    String? degradationTargetProfileId,
    DateTime? updatedAt,
  }) {
    return StoredEnhancementPipelineStateRecord(
      scopeId: scopeId,
      profileId: profileId ?? this.profileId,
      state: state ?? this.state,
      supported: supported ?? this.supported,
      failureReason: failureReason ?? this.failureReason,
      budgetPressure: budgetPressure ?? this.budgetPressure,
      degradationTargetProfileId:
          degradationTargetProfileId ?? this.degradationTargetProfileId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

abstract interface class EnhancementProfileStore {
  Future<StoredEnhancementProfileRecord> storeProfile(
      StoredEnhancementProfileRecord profile);

  Future<StoredEnhancementProfileRecord?> findProfileById(String profileId);

  Future<List<StoredEnhancementProfileRecord>> listProfiles();

  Future<bool> removeProfile(String profileId);

  Future<void> setActiveProfile(StoredActiveEnhancementProfileRecord active);

  Future<StoredActiveEnhancementProfileRecord?> activeProfile(String scopeId);

  Future<void> recordPipelineState(StoredEnhancementPipelineStateRecord state);

  Future<StoredEnhancementPipelineStateRecord?> latestPipelineState(
      String scopeId);
}

final class DeterministicEnhancementProfileStore
    implements EnhancementProfileStore {
  DeterministicEnhancementProfileStore({
    Iterable<StoredEnhancementProfileRecord> seedProfiles =
        const <StoredEnhancementProfileRecord>[],
    Iterable<StoredActiveEnhancementProfileRecord> seedActiveProfiles =
        const <StoredActiveEnhancementProfileRecord>[],
    Iterable<StoredEnhancementPipelineStateRecord> seedPipelineStates =
        const <StoredEnhancementPipelineStateRecord>[],
  }) {
    for (final StoredEnhancementProfileRecord profile in seedProfiles) {
      _profilesById[profile.id] = profile;
    }
    for (final StoredActiveEnhancementProfileRecord active
        in seedActiveProfiles) {
      _activeByScope[active.scopeId] = active;
    }
    for (final StoredEnhancementPipelineStateRecord state
        in seedPipelineStates) {
      _latestStateByScope[state.scopeId] = state;
    }
  }

  final Map<String, StoredEnhancementProfileRecord> _profilesById =
      <String, StoredEnhancementProfileRecord>{};
  final Map<String, StoredActiveEnhancementProfileRecord> _activeByScope =
      <String, StoredActiveEnhancementProfileRecord>{};
  final Map<String, StoredEnhancementPipelineStateRecord> _latestStateByScope =
      <String, StoredEnhancementPipelineStateRecord>{};

  @override
  Future<StoredActiveEnhancementProfileRecord?> activeProfile(String scopeId) {
    return Future<StoredActiveEnhancementProfileRecord?>.value(
        _activeByScope[scopeId]);
  }

  @override
  Future<StoredEnhancementProfileRecord?> findProfileById(String profileId) {
    return Future<StoredEnhancementProfileRecord?>.value(
        _profilesById[profileId]);
  }

  @override
  Future<StoredEnhancementPipelineStateRecord?> latestPipelineState(
      String scopeId) {
    return Future<StoredEnhancementPipelineStateRecord?>.value(
        _latestStateByScope[scopeId]);
  }

  @override
  Future<List<StoredEnhancementProfileRecord>> listProfiles() {
    return Future<List<StoredEnhancementProfileRecord>>.value(
      <StoredEnhancementProfileRecord>[..._profilesById.values]..sort(
          (StoredEnhancementProfileRecord left,
                  StoredEnhancementProfileRecord right) =>
              left.label.compareTo(right.label)),
    );
  }

  @override
  Future<void> recordPipelineState(StoredEnhancementPipelineStateRecord state) {
    _latestStateByScope[state.scopeId] = state;
    return Future<void>.value();
  }

  @override
  Future<bool> removeProfile(String profileId) {
    final bool removed = _profilesById.remove(profileId) != null;
    _activeByScope.removeWhere(
        (String scopeId, StoredActiveEnhancementProfileRecord active) =>
            active.profileId == profileId);
    _latestStateByScope.removeWhere(
        (String scopeId, StoredEnhancementPipelineStateRecord state) =>
            state.profileId == profileId);
    return Future<bool>.value(removed);
  }

  @override
  Future<void> setActiveProfile(StoredActiveEnhancementProfileRecord active) {
    _activeByScope[active.scopeId] = active;
    return Future<void>.value();
  }

  @override
  Future<StoredEnhancementProfileRecord> storeProfile(
      StoredEnhancementProfileRecord profile) {
    _profilesById[profile.id] = profile;
    return Future<StoredEnhancementProfileRecord>.value(profile);
  }
}
