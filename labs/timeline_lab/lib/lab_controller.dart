import 'package:flutter/foundation.dart';

import 'filter/timeline_filter.dart';
import 'model/lab_models.dart';
import 'model/seed.dart';
import 'renderers/renderer_contract.dart';

/// Single state owner for the lab.
class LabController extends ChangeNotifier {
  LabController({this.seed = 42, int datasetSize = 120})
    : _datasetSize = datasetSize,
      _dataset = generateDataset(seed: seed, storyCount: datasetSize) {
    _recompute();
  }

  final int seed;

  LabDataset _dataset;
  LabDataset get dataset => _dataset;

  int _datasetSize;
  int get datasetSize => _datasetSize;

  TimelineFilter _filter = const TimelineFilter();
  TimelineFilter get filter => _filter;

  RendererKind _renderer = RendererKind.sliverList;
  RendererKind get renderer => _renderer;

  String? _selectedStoryId;
  String? get selectedStoryId => _selectedStoryId;

  List<TimelineEntry> _entries = const [];
  List<TimelineEntry> get entries => _entries;

  int _matchCount = 0;
  int get matchCount => _matchCount;

  LabStory? get selectedStory {
    final id = _selectedStoryId;
    if (id == null) return null;
    for (final s in _dataset.stories) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _recompute() {
    _entries = applyFilter(_dataset, _filter);
    _matchCount = _entries.where((e) => e.matched).length;
  }

  void setFilter(TimelineFilter filter) {
    _filter = filter;
    _recompute();
    notifyListeners();
  }

  void setRenderer(RendererKind kind) {
    _renderer = kind;
    notifyListeners();
  }

  void select(String? id) {
    _selectedStoryId = id;
    notifyListeners();
  }

  void setDatasetSize(int size) {
    _datasetSize = size;
    _dataset = generateDataset(seed: seed, storyCount: size);
    _selectedStoryId = null;
    _filter = _filter.copyWith(
      personIds: const {},
      placeIds: const {},
      familyIds: const {},
    );
    _recompute();
    notifyListeners();
  }
}
