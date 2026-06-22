/// Stored advanced-caption records capture user profile choices and renderer
/// state, while actual native caption resources stay outside storage.
enum StoredAdvancedCaptionRendererStateKind {
  disabled,
  evaluated,
  applied,
  rejected,
  degraded,
}

final class StoredAdvancedCaptionProfileRecord {
  const StoredAdvancedCaptionProfileRecord({
    required this.id,
    required this.label,
    required this.matrixDanmakuEnabled,
    required this.dualSubtitlesEnabled,
    required this.pgsRenderingEnabled,
    required this.assEnhancementEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.primarySubtitleLanguageCode,
    this.secondarySubtitleLanguageCode,
    this.isBuiltIn = false,
  })  : assert(id != '', 'Advanced caption profile id must not be empty.'),
        assert(
            label != '', 'Advanced caption profile label must not be empty.'),
        assert(
          primarySubtitleLanguageCode == null ||
              primarySubtitleLanguageCode != '',
          'Primary subtitle language code must not be empty.',
        ),
        assert(
          secondarySubtitleLanguageCode == null ||
              secondarySubtitleLanguageCode != '',
          'Secondary subtitle language code must not be empty.',
        );

  final String id;
  final String label;
  final bool matrixDanmakuEnabled;
  final bool dualSubtitlesEnabled;
  final bool pgsRenderingEnabled;
  final bool assEnhancementEnabled;
  final String? primarySubtitleLanguageCode;
  final String? secondarySubtitleLanguageCode;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  StoredAdvancedCaptionProfileRecord copyWith({
    String? label,
    bool? matrixDanmakuEnabled,
    bool? dualSubtitlesEnabled,
    bool? pgsRenderingEnabled,
    bool? assEnhancementEnabled,
    String? primarySubtitleLanguageCode,
    String? secondarySubtitleLanguageCode,
    bool? isBuiltIn,
    DateTime? updatedAt,
  }) {
    return StoredAdvancedCaptionProfileRecord(
      id: id,
      label: label ?? this.label,
      matrixDanmakuEnabled: matrixDanmakuEnabled ?? this.matrixDanmakuEnabled,
      dualSubtitlesEnabled: dualSubtitlesEnabled ?? this.dualSubtitlesEnabled,
      pgsRenderingEnabled: pgsRenderingEnabled ?? this.pgsRenderingEnabled,
      assEnhancementEnabled:
          assEnhancementEnabled ?? this.assEnhancementEnabled,
      primarySubtitleLanguageCode:
          primarySubtitleLanguageCode ?? this.primarySubtitleLanguageCode,
      secondarySubtitleLanguageCode:
          secondarySubtitleLanguageCode ?? this.secondarySubtitleLanguageCode,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class StoredActiveAdvancedCaptionProfileRecord {
  const StoredActiveAdvancedCaptionProfileRecord({
    required this.scopeId,
    required this.profileId,
    required this.selectedAt,
  })  : assert(scopeId != '', 'Advanced caption scope id must not be empty.'),
        assert(
          profileId != '',
          'Advanced caption profile id must not be empty.',
        );

  final String scopeId;
  final String profileId;
  final DateTime selectedAt;
}

final class StoredAdvancedCaptionDualSubtitleSelectionRecord {
  const StoredAdvancedCaptionDualSubtitleSelectionRecord({
    required this.scopeId,
    required this.profileId,
    required this.primarySubtitleId,
    required this.secondarySubtitleId,
    required this.selectedAt,
    this.primaryLanguageCode,
    this.secondaryLanguageCode,
  })  : assert(scopeId != '', 'Advanced caption scope id must not be empty.'),
        assert(
            profileId != '', 'Advanced caption profile id must not be empty.'),
        assert(
            primarySubtitleId != '', 'Primary subtitle id must not be empty.'),
        assert(
          secondarySubtitleId != '',
          'Secondary subtitle id must not be empty.',
        ),
        assert(
          primarySubtitleId != secondarySubtitleId,
          'Primary and secondary subtitles must be distinct.',
        ),
        assert(
          primaryLanguageCode == null || primaryLanguageCode != '',
          'Primary language code must not be empty.',
        ),
        assert(
          secondaryLanguageCode == null || secondaryLanguageCode != '',
          'Secondary language code must not be empty.',
        );

  final String scopeId;
  final String profileId;
  final String primarySubtitleId;
  final String secondarySubtitleId;
  final String? primaryLanguageCode;
  final String? secondaryLanguageCode;
  final DateTime selectedAt;
}

final class StoredAdvancedCaptionRendererStateRecord {
  const StoredAdvancedCaptionRendererStateRecord({
    required this.scopeId,
    required this.state,
    required this.supported,
    required this.updatedAt,
    this.profileId,
    this.feature,
    this.failureReason,
    this.degradationReason,
  })  : assert(scopeId != '',
            'Advanced caption state scope id must not be empty.'),
        assert(profileId == null || profileId != '',
            'Advanced caption profile id must not be empty.'),
        assert(feature == null || feature != '',
            'Advanced caption feature must not be empty.'),
        assert(failureReason == null || failureReason != '',
            'Advanced caption failure reason must not be empty.'),
        assert(degradationReason == null || degradationReason != '',
            'Advanced caption degradation reason must not be empty.');

  final String scopeId;
  final String? profileId;
  final String? feature;
  final StoredAdvancedCaptionRendererStateKind state;
  final bool supported;
  final String? failureReason;
  final String? degradationReason;
  final DateTime updatedAt;
}

/// Persistence port for advanced caption profiles and renderer state.
/// Renderer resources and frame-budget decisions remain outside storage.
abstract interface class AdvancedCaptionStore {
  Future<StoredAdvancedCaptionProfileRecord> storeProfile(
      StoredAdvancedCaptionProfileRecord profile);

  Future<StoredAdvancedCaptionProfileRecord?> findProfileById(String profileId);

  Future<List<StoredAdvancedCaptionProfileRecord>> listProfiles();

  Future<bool> removeProfile(String profileId);

  Future<void> setActiveProfile(
      StoredActiveAdvancedCaptionProfileRecord active);

  Future<StoredActiveAdvancedCaptionProfileRecord?> activeProfile(
      String scopeId);

  Future<void> setDualSubtitleSelection(
      StoredAdvancedCaptionDualSubtitleSelectionRecord selection);

  Future<StoredAdvancedCaptionDualSubtitleSelectionRecord?>
      dualSubtitleSelection(String scopeId);

  Future<void> recordRendererState(
      StoredAdvancedCaptionRendererStateRecord state);

  Future<StoredAdvancedCaptionRendererStateRecord?> latestRendererState(
      String scopeId);
}

final class DeterministicAdvancedCaptionStore implements AdvancedCaptionStore {
  DeterministicAdvancedCaptionStore({
    Iterable<StoredAdvancedCaptionProfileRecord> seedProfiles =
        const <StoredAdvancedCaptionProfileRecord>[],
    Iterable<StoredActiveAdvancedCaptionProfileRecord> seedActiveProfiles =
        const <StoredActiveAdvancedCaptionProfileRecord>[],
    Iterable<StoredAdvancedCaptionDualSubtitleSelectionRecord> seedDualSubtitleSelections =
        const <StoredAdvancedCaptionDualSubtitleSelectionRecord>[],
    Iterable<StoredAdvancedCaptionRendererStateRecord> seedRendererStates =
        const <StoredAdvancedCaptionRendererStateRecord>[],
  }) {
    for (final StoredAdvancedCaptionProfileRecord profile in seedProfiles) {
      _profilesById[profile.id] = profile;
    }
    for (final StoredActiveAdvancedCaptionProfileRecord active
        in seedActiveProfiles) {
      _activeByScope[active.scopeId] = active;
    }
    for (final StoredAdvancedCaptionDualSubtitleSelectionRecord selection
        in seedDualSubtitleSelections) {
      _dualSubtitlesByScope[selection.scopeId] = selection;
    }
    for (final StoredAdvancedCaptionRendererStateRecord state
        in seedRendererStates) {
      _latestStateByScope[state.scopeId] = state;
    }
  }

  final Map<String, StoredAdvancedCaptionProfileRecord> _profilesById =
      <String, StoredAdvancedCaptionProfileRecord>{};
  final Map<String, StoredActiveAdvancedCaptionProfileRecord> _activeByScope =
      <String, StoredActiveAdvancedCaptionProfileRecord>{};
  final Map<String, StoredAdvancedCaptionDualSubtitleSelectionRecord>
      _dualSubtitlesByScope =
      <String, StoredAdvancedCaptionDualSubtitleSelectionRecord>{};
  final Map<String, StoredAdvancedCaptionRendererStateRecord>
      _latestStateByScope =
      <String, StoredAdvancedCaptionRendererStateRecord>{};

  @override
  Future<StoredActiveAdvancedCaptionProfileRecord?> activeProfile(
      String scopeId) {
    return Future<StoredActiveAdvancedCaptionProfileRecord?>.value(
        _activeByScope[scopeId]);
  }

  @override
  Future<StoredAdvancedCaptionDualSubtitleSelectionRecord?>
      dualSubtitleSelection(String scopeId) {
    return Future<StoredAdvancedCaptionDualSubtitleSelectionRecord?>.value(
        _dualSubtitlesByScope[scopeId]);
  }

  @override
  Future<StoredAdvancedCaptionProfileRecord?> findProfileById(
      String profileId) {
    return Future<StoredAdvancedCaptionProfileRecord?>.value(
        _profilesById[profileId]);
  }

  @override
  Future<StoredAdvancedCaptionRendererStateRecord?> latestRendererState(
      String scopeId) {
    return Future<StoredAdvancedCaptionRendererStateRecord?>.value(
        _latestStateByScope[scopeId]);
  }

  @override
  Future<List<StoredAdvancedCaptionProfileRecord>> listProfiles() {
    return Future<List<StoredAdvancedCaptionProfileRecord>>.value(
      <StoredAdvancedCaptionProfileRecord>[..._profilesById.values]..sort(
          (StoredAdvancedCaptionProfileRecord left,
                  StoredAdvancedCaptionProfileRecord right) =>
              left.label.compareTo(right.label)),
    );
  }

  @override
  Future<void> recordRendererState(
      StoredAdvancedCaptionRendererStateRecord state) {
    _latestStateByScope[state.scopeId] = state;
    return Future<void>.value();
  }

  @override
  Future<bool> removeProfile(String profileId) {
    final bool removed = _profilesById.remove(profileId) != null;
    _activeByScope.removeWhere(
        (String scopeId, StoredActiveAdvancedCaptionProfileRecord active) =>
            active.profileId == profileId);
    _dualSubtitlesByScope.removeWhere((String scopeId,
            StoredAdvancedCaptionDualSubtitleSelectionRecord selection) =>
        selection.profileId == profileId);
    _latestStateByScope.removeWhere(
        (String scopeId, StoredAdvancedCaptionRendererStateRecord state) =>
            state.profileId == profileId);
    return Future<bool>.value(removed);
  }

  @override
  Future<void> setActiveProfile(
      StoredActiveAdvancedCaptionProfileRecord active) {
    _activeByScope[active.scopeId] = active;
    return Future<void>.value();
  }

  @override
  Future<void> setDualSubtitleSelection(
      StoredAdvancedCaptionDualSubtitleSelectionRecord selection) {
    _dualSubtitlesByScope[selection.scopeId] = selection;
    return Future<void>.value();
  }

  @override
  Future<StoredAdvancedCaptionProfileRecord> storeProfile(
      StoredAdvancedCaptionProfileRecord profile) {
    _profilesById[profile.id] = profile;
    return Future<StoredAdvancedCaptionProfileRecord>.value(profile);
  }
}
