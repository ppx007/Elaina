import '../baseline_defaults.dart';

enum StoredVirtualMediaStreamLifecycleState {
  active,
  closed,
  failed,
}

enum StoredVirtualStreamEventKind {
  created,
  rangeBuffered,
  rangeFailed,
  closed,
  failed,
}

final class StoredVirtualMediaStreamRecord {
  const StoredVirtualMediaStreamRecord({
    required this.id,
    required this.taskId,
    required this.fileIndex,
    required this.lengthBytes,
    required this.lifecycleState,
    required this.createdAt,
    required this.updatedAt,
    this.contentUri,
    this.mimeType,
    this.message,
  })  : assert(id != '', 'Virtual media stream id must not be empty.'),
        assert(taskId != '', 'BT task id must not be empty.'),
        assert(fileIndex >= 0, 'BT file index must not be negative.'),
        assert(lengthBytes >= 0, 'lengthBytes must not be negative.');

  final String id;
  final String taskId;
  final int fileIndex;
  final int lengthBytes;
  final StoredVirtualMediaStreamLifecycleState lifecycleState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Uri? contentUri;
  final String? mimeType;
  final String? message;

  StoredVirtualMediaStreamRecord copyWith({
    StoredVirtualMediaStreamLifecycleState? lifecycleState,
    DateTime? updatedAt,
    String? message,
  }) {
    return StoredVirtualMediaStreamRecord(
      id: id,
      taskId: taskId,
      fileIndex: fileIndex,
      lengthBytes: lengthBytes,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contentUri: contentUri,
      mimeType: mimeType,
      message: message ?? this.message,
    );
  }
}

final class StoredVirtualStreamBufferedRangeRecord {
  const StoredVirtualStreamBufferedRangeRecord({
    required this.streamId,
    required this.startByte,
    required this.endByte,
    required this.observedAt,
  })  : assert(streamId != '', 'Virtual media stream id must not be empty.'),
        assert(startByte >= 0, 'startByte must not be negative.'),
        assert(endByte >= startByte,
            'endByte must be greater than or equal to startByte.');

  final String streamId;
  final int startByte;
  final int endByte;
  final DateTime observedAt;
}

final class StoredVirtualStreamEventRecord {
  const StoredVirtualStreamEventRecord({
    required this.streamId,
    required this.eventKind,
    required this.occurredAt,
    this.rangeStart,
    this.rangeEnd,
    this.failureKind,
    this.message,
  })  : assert(streamId != '', 'Virtual media stream id must not be empty.'),
        assert(rangeStart == null || rangeStart >= 0,
            'rangeStart must not be negative.'),
        assert(rangeEnd == null || rangeStart != null,
            'rangeEnd requires rangeStart.'),
        assert(
            rangeEnd == null || (rangeStart != null && rangeEnd >= rangeStart),
            'rangeEnd must be greater than or equal to rangeStart.');

  final String streamId;
  final StoredVirtualStreamEventKind eventKind;
  final DateTime occurredAt;
  final int? rangeStart;
  final int? rangeEnd;
  final String? failureKind;
  final String? message;
}

abstract interface class VirtualMediaStreamStore {
  Future<StoredVirtualMediaStreamRecord> storeStream(
      StoredVirtualMediaStreamRecord stream);

  Future<StoredVirtualMediaStreamRecord?> findStreamById(String streamId);

  Future<StoredVirtualMediaStreamRecord?> findStreamForTaskFile({
    required String taskId,
    required int fileIndex,
  });

  Future<List<StoredVirtualMediaStreamRecord>> listStreams(
      {int offset = 0, int limit = defaultListPageLimit});

  Future<int> count();

  Future<void> recordBufferedRange(
      StoredVirtualStreamBufferedRangeRecord range);

  Future<List<StoredVirtualStreamBufferedRangeRecord>> bufferedRangesFor(
      String streamId);

  Future<void> recordEvent(StoredVirtualStreamEventRecord event);

  Future<StoredVirtualStreamEventRecord?> latestEvent(String streamId);
}

final class DeterministicVirtualMediaStreamStore
    implements VirtualMediaStreamStore {
  DeterministicVirtualMediaStreamStore({
    Iterable<StoredVirtualMediaStreamRecord> seedStreams =
        const <StoredVirtualMediaStreamRecord>[],
  }) {
    for (final StoredVirtualMediaStreamRecord stream in seedStreams) {
      _streamsById[stream.id] = stream;
    }
  }

  final Map<String, StoredVirtualMediaStreamRecord> _streamsById =
      <String, StoredVirtualMediaStreamRecord>{};
  final Map<String, List<StoredVirtualStreamBufferedRangeRecord>>
      _rangesByStreamId =
      <String, List<StoredVirtualStreamBufferedRangeRecord>>{};
  final Map<String, StoredVirtualStreamEventRecord> _eventsByStreamId =
      <String, StoredVirtualStreamEventRecord>{};

  @override
  Future<List<StoredVirtualStreamBufferedRangeRecord>> bufferedRangesFor(
      String streamId) {
    return Future<List<StoredVirtualStreamBufferedRangeRecord>>.value(
      <StoredVirtualStreamBufferedRangeRecord>[
        ...?_rangesByStreamId[streamId],
      ],
    );
  }

  @override
  Future<int> count() => Future<int>.value(_streamsById.length);

  @override
  Future<StoredVirtualMediaStreamRecord?> findStreamById(String streamId) {
    return Future<StoredVirtualMediaStreamRecord?>.value(
        _streamsById[streamId]);
  }

  @override
  Future<StoredVirtualMediaStreamRecord?> findStreamForTaskFile({
    required String taskId,
    required int fileIndex,
  }) {
    for (final StoredVirtualMediaStreamRecord stream in _streamsById.values) {
      if (stream.taskId == taskId && stream.fileIndex == fileIndex) {
        return Future<StoredVirtualMediaStreamRecord?>.value(stream);
      }
    }
    return Future<StoredVirtualMediaStreamRecord?>.value();
  }

  @override
  Future<StoredVirtualStreamEventRecord?> latestEvent(String streamId) {
    return Future<StoredVirtualStreamEventRecord?>.value(
        _eventsByStreamId[streamId]);
  }

  @override
  Future<List<StoredVirtualMediaStreamRecord>> listStreams(
      {int offset = 0, int limit = defaultListPageLimit}) {
    assert(offset >= 0, 'offset must not be negative.');
    assert(limit > 0, 'limit must be positive.');
    final List<StoredVirtualMediaStreamRecord> streams =
        <StoredVirtualMediaStreamRecord>[..._streamsById.values];
    final int start = offset > streams.length ? streams.length : offset;
    final int end =
        start + limit > streams.length ? streams.length : start + limit;
    return Future<List<StoredVirtualMediaStreamRecord>>.value(
        streams.sublist(start, end));
  }

  @override
  Future<void> recordBufferedRange(
      StoredVirtualStreamBufferedRangeRecord range) {
    final List<StoredVirtualStreamBufferedRangeRecord> ranges =
        <StoredVirtualStreamBufferedRangeRecord>[
      ...?_rangesByStreamId[range.streamId],
      range,
    ]..sort(
            (StoredVirtualStreamBufferedRangeRecord left,
                    StoredVirtualStreamBufferedRangeRecord right) =>
                left.startByte.compareTo(right.startByte),
          );
    _rangesByStreamId[range.streamId] = _mergeRanges(ranges);
    return Future<void>.value();
  }

  @override
  Future<void> recordEvent(StoredVirtualStreamEventRecord event) {
    _eventsByStreamId[event.streamId] = event;
    return Future<void>.value();
  }

  @override
  Future<StoredVirtualMediaStreamRecord> storeStream(
      StoredVirtualMediaStreamRecord stream) {
    _streamsById[stream.id] = stream;
    return Future<StoredVirtualMediaStreamRecord>.value(stream);
  }

  static List<StoredVirtualStreamBufferedRangeRecord> _mergeRanges(
      List<StoredVirtualStreamBufferedRangeRecord> ranges) {
    final List<StoredVirtualStreamBufferedRangeRecord> merged =
        <StoredVirtualStreamBufferedRangeRecord>[];
    for (final StoredVirtualStreamBufferedRangeRecord range in ranges) {
      if (merged.isEmpty) {
        merged.add(range);
        continue;
      }
      final StoredVirtualStreamBufferedRangeRecord previous = merged.last;
      if (range.startByte > previous.endByte + 1) {
        merged.add(range);
        continue;
      }
      merged[merged.length - 1] = StoredVirtualStreamBufferedRangeRecord(
        streamId: previous.streamId,
        startByte: previous.startByte,
        endByte:
            range.endByte > previous.endByte ? range.endByte : previous.endByte,
        observedAt: range.observedAt.isAfter(previous.observedAt)
            ? range.observedAt
            : previous.observedAt,
      );
    }
    return merged;
  }
}
