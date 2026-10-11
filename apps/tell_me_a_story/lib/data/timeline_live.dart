import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

const timelineLiveTables = ['stories', 'photos', 'comments', 'perspectives'];

/// Whether a realtime row should refresh the open family timeline.
///
/// Draft inserts and other families stay off the published rail.
bool timelineEventMatters({
  required String familyId,
  required String table,
  required String? eventFamilyId,
  required String? status,
  required bool isDelete,
}) {
  if (eventFamilyId != null && eventFamilyId != familyId) return false;
  if (table == 'stories' &&
      !isDelete &&
      status != null &&
      status != 'published') {
    return false;
  }
  return true;
}

abstract class TimelineLive {
  void watch({required String familyId, required void Function() onChange});

  /// Reader feed for one story. The default does nothing so existing fakes
  /// keep compiling. The timeline [watch] stays on `family_id`.
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {}

  void dispose();
}

class SupabaseTimelineLive implements TimelineLive {
  SupabaseTimelineLive({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  RealtimeChannel? _channel;
  RealtimeChannel? _storyChannel;
  Timer? _debounce;
  Timer? _storyDebounce;
  String? _familyId;
  String? _storyId;

  @override
  void watch({required String familyId, required void Function() onChange}) {
    if (_familyId == familyId && _channel != null) return;
    _stop();
    _familyId = familyId;
    // Topic is the table, not an app channel name (Design Doc §7).
    final channel = _client.channel('public:stories');
    for (final table in timelineLiveTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: familyId,
        ),
        callback: (payload) {
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          final matters = timelineEventMatters(
            familyId: familyId,
            table: table,
            eventFamilyId: record['family_id'] as String?,
            status: record['status'] as String?,
            isDelete: payload.eventType == PostgresChangeEvent.delete,
          );
          if (!matters) return;
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 200), onChange);
        },
      );
    }
    channel.subscribe();
    _channel = channel;
  }

  @override
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {
    if (_storyId == storyId && _storyChannel != null) return;
    _stopStory();
    _storyId = storyId;
    final channel = _client.channel('public:comments');
    for (final table in const ['comments', 'perspectives', 'photos']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'story_id',
          value: storyId,
        ),
        callback: (_) {
          _storyDebounce?.cancel();
          _storyDebounce = Timer(const Duration(milliseconds: 200), onChange);
        },
      );
    }
    channel.subscribe();
    _storyChannel = channel;
  }

  void _stopStory() {
    _storyDebounce?.cancel();
    _storyDebounce = null;
    final channel = _storyChannel;
    _storyChannel = null;
    if (channel != null) {
      _client.removeChannel(channel);
    }
  }

  void _stop() {
    _debounce?.cancel();
    _debounce = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      _client.removeChannel(channel);
    }
  }

  @override
  void dispose() {
    _familyId = null;
    _storyId = null;
    _stop();
    _stopStory();
  }
}
