import 'dart:convert';

import '../../foundation/storage/storage_contracts.dart';
import 'bangumi_tracking_domain.dart';

const String bangumiLocalTrackingSettingsKey =
    'bangumi_local_tracking_records_v1';
const int bangumiLocalTrackingSchemaVersion = 1;

enum BangumiLocalTrackingSyncState {
  pending,
  synced,
}

enum BangumiTrackingSyncResultKind {
  success,
  unauthenticated,
  failed,
}

final class BangumiLocalTrackingRecord {
  const BangumiLocalTrackingRecord({
    required this.subjectId,
    required this.title,
    required this.status,
    required this.updatedAt,
    required this.syncState,
    this.coverUri,
  })  : assert(
            subjectId != '', 'Bangumi tracking subject id must not be empty.'),
        assert(title != '', 'Bangumi tracking title must not be empty.');

  final String subjectId;
  final String title;
  final BangumiTrackingStatus status;
  final Uri? coverUri;
  final DateTime updatedAt;
  final BangumiLocalTrackingSyncState syncState;
}

final class BangumiTrackingSyncResult {
  const BangumiTrackingSyncResult._({
    required this.kind,
    this.message,
  });

  const BangumiTrackingSyncResult.success()
      : this._(kind: BangumiTrackingSyncResultKind.success);

  const BangumiTrackingSyncResult.unauthenticated(String message)
      : this._(
          kind: BangumiTrackingSyncResultKind.unauthenticated,
          message: message,
        );

  const BangumiTrackingSyncResult.failed(String message)
      : this._(kind: BangumiTrackingSyncResultKind.failed, message: message);

  final BangumiTrackingSyncResultKind kind;
  final String? message;

  bool get isSuccess => kind == BangumiTrackingSyncResultKind.success;
}

abstract interface class BangumiLocalTrackingStore {
  Future<BangumiLocalTrackingRecord?> findBySubjectId(String subjectId);

  Future<List<BangumiLocalTrackingRecord>> list();

  Future<void> save(BangumiLocalTrackingRecord record);

  Future<void> remove(String subjectId);
}

abstract interface class BangumiTrackingSyncProvider {
  Future<BangumiTrackingSyncResult> syncTrackingStatus({
    required String subjectId,
    required BangumiTrackingStatus status,
  });
}

final class CloudFirstBangumiTrackingProvider
    implements BangumiTrackingProvider {
  const CloudFirstBangumiTrackingProvider({
    required BangumiLocalTrackingStore localStore,
    BangumiTrackingProvider? remoteProvider,
  })  : _localStore = localStore,
        _remoteProvider = remoteProvider;

  final BangumiLocalTrackingStore _localStore;
  final BangumiTrackingProvider? _remoteProvider;

  @override
  Future<BangumiTrackingSnapshot> currentAnimeCollection() async {
    final BangumiTrackingProvider? remoteProvider = _remoteProvider;
    if (remoteProvider != null) {
      final BangumiTrackingSnapshot remote =
          await remoteProvider.currentAnimeCollection();
      if (remote.status == BangumiTrackingLoadStatus.loaded) {
        return remote;
      }
      if (remote.status != BangumiTrackingLoadStatus.unauthenticated) {
        return remote;
      }
      final List<BangumiLocalTrackingRecord> localRecords =
          await _localStore.list();
      if (localRecords.isNotEmpty) {
        return BangumiTrackingSnapshot.loaded(
          localRecords.map(_trackingItemFromLocalRecord),
        );
      }
      return remote;
    }

    final List<BangumiLocalTrackingRecord> localRecords =
        await _localStore.list();
    return localRecords.isEmpty
        ? const BangumiTrackingSnapshot.unauthenticated(
            'Bangumi tracking has no remote provider.',
          )
        : BangumiTrackingSnapshot.loaded(
            localRecords.map(_trackingItemFromLocalRecord),
          );
  }

  static BangumiTrackingItem _trackingItemFromLocalRecord(
    BangumiLocalTrackingRecord record,
  ) {
    return BangumiTrackingItem(
      subjectId: record.subjectId,
      title: record.title,
      status: record.status,
      watchedEpisodes: 0,
      totalEpisodes: 0,
      coverUri: record.coverUri,
      updatedAt: record.updatedAt,
    );
  }
}

final class SettingsBangumiLocalTrackingStore
    implements BangumiLocalTrackingStore {
  const SettingsBangumiLocalTrackingStore(
    SettingsStore settingsStore, {
    String key = bangumiLocalTrackingSettingsKey,
  })  : _settingsStore = settingsStore,
        _key = key;

  final SettingsStore _settingsStore;
  final String _key;

  @override
  Future<BangumiLocalTrackingRecord?> findBySubjectId(String subjectId) async {
    return (await _recordsBySubjectId())[subjectId];
  }

  @override
  Future<List<BangumiLocalTrackingRecord>> list() async {
    final List<BangumiLocalTrackingRecord> records =
        (await _recordsBySubjectId()).values.toList()
          ..sort(_compareLocalTrackingRecords);
    return List<BangumiLocalTrackingRecord>.unmodifiable(records);
  }

  @override
  Future<void> save(BangumiLocalTrackingRecord record) async {
    final Map<String, BangumiLocalTrackingRecord> records =
        await _recordsBySubjectId();
    records[record.subjectId] = record;
    await _write(records.values);
  }

  @override
  Future<void> remove(String subjectId) async {
    final Map<String, BangumiLocalTrackingRecord> records =
        await _recordsBySubjectId();
    records.remove(subjectId);
    await _write(records.values);
  }

  Future<Map<String, BangumiLocalTrackingRecord>> _recordsBySubjectId() async {
    final String? raw = await _settingsStore.readString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return <String, BangumiLocalTrackingRecord>{};
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw StateError('Bangumi local tracking JSON is invalid: $error');
    }
    final Map<String, Object?> object =
        _jsonObject(decoded, 'Bangumi local tracking state');
    final int version = _intValue(object[_fieldVersion]);
    if (version != bangumiLocalTrackingSchemaVersion) {
      throw StateError('Unsupported Bangumi local tracking schema: $version');
    }
    final Object? items = object[_fieldItems];
    if (items is! List<Object?>) {
      throw StateError('Bangumi local tracking state is missing items.');
    }
    final Map<String, BangumiLocalTrackingRecord> records =
        <String, BangumiLocalTrackingRecord>{};
    for (final Object? item in items) {
      final BangumiLocalTrackingRecord record = _recordFromJson(
        _jsonObject(item, 'Bangumi local tracking item'),
      );
      records[record.subjectId] = record;
    }
    return records;
  }

  Future<void> _write(Iterable<BangumiLocalTrackingRecord> records) {
    final Map<String, Object?> encoded = <String, Object?>{
      _fieldVersion: bangumiLocalTrackingSchemaVersion,
      _fieldItems: <Object?>[
        for (final BangumiLocalTrackingRecord record in records)
          _recordToJson(record),
      ],
    };
    return _settingsStore.writeString(
      key: _key,
      value: jsonEncode(encoded),
    );
  }
}

const String _fieldVersion = 'version';
const String _fieldItems = 'items';
const String _fieldSubjectId = 'subject_id';
const String _fieldTitle = 'title';
const String _fieldStatus = 'status';
const String _fieldCoverUri = 'cover_uri';
const String _fieldUpdatedAt = 'updated_at';
const String _fieldSyncState = 'sync_state';

Map<String, Object?> _recordToJson(BangumiLocalTrackingRecord record) {
  return <String, Object?>{
    _fieldSubjectId: record.subjectId,
    _fieldTitle: record.title,
    _fieldStatus: record.status.name,
    if (record.coverUri != null) _fieldCoverUri: record.coverUri.toString(),
    _fieldUpdatedAt: record.updatedAt.toUtc().toIso8601String(),
    _fieldSyncState: record.syncState.name,
  };
}

BangumiLocalTrackingRecord _recordFromJson(Map<String, Object?> json) {
  final String subjectId = _stringValue(json[_fieldSubjectId]);
  final String title = _stringValue(json[_fieldTitle]);
  final String statusName = _stringValue(json[_fieldStatus]);
  final String syncStateName = _stringValue(json[_fieldSyncState]);
  final String updatedAtRaw = _stringValue(json[_fieldUpdatedAt]);
  final DateTime? updatedAt = DateTime.tryParse(updatedAtRaw);
  if (updatedAt == null) {
    throw StateError('Bangumi local tracking item has invalid updated_at.');
  }
  return BangumiLocalTrackingRecord(
    subjectId: subjectId,
    title: title,
    status: _trackingStatusByName(statusName),
    coverUri: _optionalUri(json[_fieldCoverUri]),
    updatedAt: updatedAt.toUtc(),
    syncState: _syncStateByName(syncStateName),
  );
}

int _compareLocalTrackingRecords(
  BangumiLocalTrackingRecord left,
  BangumiLocalTrackingRecord right,
) {
  final int updated = right.updatedAt.compareTo(left.updatedAt);
  if (updated != 0) return updated;
  return left.title.compareTo(right.title);
}

Map<String, Object?> _jsonObject(Object? value, String label) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map(
      (Object? key, Object? value) => MapEntry<String, Object?>('$key', value),
    );
  }
  throw StateError('$label must be a JSON object.');
}

String _stringValue(Object? value) {
  return value is String ? value.trim() : '';
}

int _intValue(Object? value) {
  return switch (value) {
    final int number => number,
    final double number => number.round(),
    final String text => int.tryParse(text) ?? -1,
    _ => -1,
  };
}

Uri? _optionalUri(Object? value) {
  final String raw = _stringValue(value);
  if (raw.isEmpty) return null;
  return Uri.tryParse(raw);
}

BangumiTrackingStatus _trackingStatusByName(String name) {
  for (final BangumiTrackingStatus status in BangumiTrackingStatus.values) {
    if (status.name == name) return status;
  }
  throw StateError('Unknown Bangumi tracking status: $name');
}

BangumiLocalTrackingSyncState _syncStateByName(String name) {
  for (final BangumiLocalTrackingSyncState state
      in BangumiLocalTrackingSyncState.values) {
    if (state.name == name) return state;
  }
  throw StateError('Unknown Bangumi local tracking sync state: $name');
}
