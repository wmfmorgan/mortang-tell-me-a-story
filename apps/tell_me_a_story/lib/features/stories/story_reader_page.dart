import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../../data/comments_api.dart';
import '../../data/people_api.dart';
import '../../data/perspectives_api.dart' hide displayNameOrMember;
import '../../data/photos_api.dart';
import '../../data/places_api.dart';
import '../../data/stories_api.dart';
import '../places/place_map.dart';
import '../places/place_picker_modal.dart';
import 'photo_strip.dart';
import 'timeframe_chips.dart';

/// First non-empty line of [body], else `Untitled`. Does not use `stories.title`.
String storyHeadline(String? body) {
  for (final line in (body ?? '').split('\n')) {
    final t = line.trim();
    if (t.isNotEmpty) return t;
  }
  return 'Untitled';
}

/// Published-only reader at `/stories/:storyId`.
class StoryReaderPage extends StatefulWidget {
  const StoryReaderPage({
    super.key,
    required this.storyId,
    this.storiesApi,
    this.peopleApi,
    this.placesApi,
    this.photosApi,
    this.commentsApi,
    this.perspectivesApi,
    this.hasMapboxToken,
    this.mapBuilder,
  });

  final String storyId;
  final StoriesGateway? storiesApi;
  final PeopleGateway? peopleApi;
  final PlacesGateway? placesApi;
  final PhotosGateway? photosApi;
  final CommentsGateway? commentsApi;
  final PerspectivesGateway? perspectivesApi;

  /// Defaults to [Env.hasMapboxToken].
  final bool? hasMapboxToken;

  /// When set, used instead of [PlaceMap] (widget tests).
  final PlaceMapBuilder? mapBuilder;

  @override
  State<StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<StoryReaderPage> {
  StoriesGateway? _storiesOverride;
  PeopleGateway? _peopleOverride;
  PlacesGateway? _placesOverride;
  PhotosGateway? _photosOverride;
  CommentsGateway? _commentsOverride;
  PerspectivesGateway? _perspectivesOverride;

  var _loading = true;
  var _notFound = false;
  var _mapFailed = false;
  Story? _story;
  List<Person> _peopleOnStory = const [];
  Place? _place;
  List<Photo> _photos = const [];
  Map<String, Uint8List> _previews = const {};
  List<Comment> _comments = const [];
  List<Perspective> _perspectives = const [];

  bool get _tokenOk => widget.hasMapboxToken ?? Env.hasMapboxToken;

  StoriesGateway get _stories =>
      widget.storiesApi ?? (_storiesOverride ??= StoriesApi());

  PeopleGateway get _people =>
      widget.peopleApi ?? (_peopleOverride ??= PeopleApi());

  PlacesGateway get _places =>
      widget.placesApi ?? (_placesOverride ??= PlacesApi());

  PhotosGateway get _photosApi =>
      widget.photosApi ?? (_photosOverride ??= PhotosApi());

  CommentsGateway get _commentsApi =>
      widget.commentsApi ?? (_commentsOverride ??= CommentsApi());

  PerspectivesGateway get _perspectivesApi =>
      widget.perspectivesApi ?? (_perspectivesOverride ??= PerspectivesApi());

  @override
  void initState() {
    super.initState();
    _mapFailed = !_tokenOk;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    var loadError = false;
    try {
      final story = await _stories.getStory(widget.storyId);
      if (!mounted) return;
      if (story.status != StoryStatus.published) {
        setState(() {
          _loading = false;
          _notFound = true;
          _story = null;
        });
        return;
      }

      List<Person> people = const [];
      try {
        final all = await _people.listPeople(story.familyId);
        people = all.where((p) => story.personIds.contains(p.id)).toList();
      } catch (_) {
        loadError = true;
      }

      Place? place;
      final placeId = story.placeId;
      if (placeId != null && placeId.isNotEmpty) {
        try {
          place = await _places.getPlace(placeId);
        } catch (_) {
          loadError = true;
        }
      }

      List<Photo> photos = const [];
      final previews = <String, Uint8List>{};
      try {
        photos = await _photosApi.listPhotos(story.id);
        for (final photo in photos) {
          try {
            previews[photo.id] = await _photosApi.downloadBytes(
              photo.storagePath,
            );
          } catch (_) {
            // Missing bytes fall back to PhotoStrip placeholder icon.
          }
        }
      } catch (_) {
        loadError = true;
      }

      List<Comment> comments = const [];
      try {
        comments = await _commentsApi.listForStory(story.id);
      } catch (_) {
        loadError = true;
      }

      List<Perspective> perspectives = const [];
      try {
        perspectives = await _perspectivesApi.listForStory(story.id);
      } catch (_) {
        loadError = true;
      }

      if (!mounted) return;
      setState(() {
        _story = story;
        _peopleOnStory = people;
        _place = place;
        _photos = photos;
        _previews = previews;
        _comments = comments;
        _perspectives = perspectives;
        _loading = false;
        _notFound = false;
      });
      if (loadError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Try again')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notFound = true;
        _story = null;
      });
    }
  }

  void _retryMap() {
    setState(() => _mapFailed = !_tokenOk);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('story-reader'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 120,
        leading: TextButton(
          onPressed: () => context.go(AppRoutes.timeline),
          child: const Text('Timeline'),
        ),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notFound || _story == null) {
      return const Center(child: Text('Not found'));
    }

    final story = _story!;
    final theme = Theme.of(context);
    final place = _place;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            storyHeadline(story.body),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text(_timeframeLabel(story))),
          ),
          if (_peopleOnStory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final person in _peopleOnStory)
                  Chip(label: Text(person.name)),
              ],
            ),
          ],
          if (place != null) ...[
            const SizedBox(height: 12),
            Text(place.label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildPlaceMap(place),
          ],
          const SizedBox(height: 16),
          Text(story.body ?? '', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _noop, child: Text('Add photos')),
          ),
          PhotoStrip(
            photos: _photos,
            previews: _previews,
            onAdd: _noop,
            onRemove: _noopPhoto,
            onRetry: _noop,
            uploadFailed: false,
            canAdd: false,
          ),
          const SizedBox(height: 24),
          Text('Perspectives', style: theme.textTheme.titleMedium),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  context.push(AppRoutes.storyPerspectivePath(widget.storyId)),
              child: const Text('+ Add your perspective'),
            ),
          ),
          for (final row in _perspectives) ...[
            Text(row.authorLabel, style: theme.textTheme.titleSmall),
            Text(row.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Text('Comments', style: theme.textTheme.titleMedium),
          const Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _noop, child: Text('+ Add comment')),
          ),
          for (final row in _comments) ...[
            Text(row.authorLabel, style: theme.textTheme.titleSmall),
            Text(row.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceMap(Place place) {
    if (_mapFailed || !_tokenOk) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(placeMapFailureCopy),
          TextButton(
            onPressed: _retryMap,
            child: const Text(placeMapRetryLabel),
          ),
        ],
      );
    }

    final builder = widget.mapBuilder;
    if (builder != null) {
      return builder(lat: place.lat, lng: place.lng);
    }
    return PlaceMap(
      lat: place.lat,
      lng: place.lng,
      height: 140,
      onTileError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _mapFailed = true);
      },
    );
  }
}

void _noop() {}

void _noopPhoto(Photo photo) {}

String _timeframeLabel(Story story) {
  final end = story.timeframeEnd;
  if (end != null) {
    for (final decade in decadeChips) {
      if (_sameDay(story.timeframeStart, decade.start) &&
          _sameDay(end, decade.end)) {
        return decade.label;
      }
    }
  }
  return _ymd(story.timeframeStart);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _ymd(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
