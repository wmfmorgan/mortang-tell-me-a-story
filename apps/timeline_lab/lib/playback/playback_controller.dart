import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../filter/timeline_filter.dart';
import '../lab_controller.dart';
import '../model/lab_models.dart';
import '../renderers/renderer_contract.dart';
import 'playback_schedule.dart';

/// Speeds offered by the playback bar.
const playbackSpeeds = [0.5, 1.0, 2.0, 4.0];

/// Owns the playback clock. Renderers listen to it directly (paint-level
/// repaints, per-card reveal), so ticks never rebuild the whole app through
/// [LabController].
///
/// The clock is a raw [Ticker], not an `AnimationController`: with the
/// platform's disable-animations flag a default controller runs at 5% of its
/// duration, which would turn a 60 s playback into 3 s. Reduced motion is
/// handled explicitly instead: reveals become instant.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required TickerProvider vsync,
    required LabController lab,
  }) : _lab = lab {
    _ticker = vsync.createTicker(_onTick);
    _design = defaultDesignFor(lab.renderer);
    _rebuild(keepYear: null);
    lab.addListener(_onLab);
  }

  /// Time-true renderers sweep; card lists step story by story.
  static PlaybackDesign defaultDesignFor(RendererKind kind) => switch (kind) {
    RendererKind.painterRail ||
    RendererKind.zoomCanvas ||
    RendererKind.swimlanes ||
    RendererKind.treeGraph ||
    RendererKind.treemap => PlaybackDesign.sweep,
    RendererKind.sliverList ||
    RendererKind.renderBoxLayout => PlaybackDesign.steps,
  };

  final LabController _lab;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  late PlaybackSchedule _schedule;
  List<TimelineEntry>? _entries;
  RendererKind? _renderer;

  late PlaybackDesign _design;
  PlaybackDesign get design => _design;

  double _speed = 1;
  double get speed => _speed;

  bool _follow = true;

  /// Whether renderers keep the cursor / current story in view.
  bool get follow => _follow;

  /// Set from the widget tree (`MediaQuery.disableAnimationsOf` or the
  /// platform's reduce-motion flag). When true, reveals are instant.
  bool reducedMotion = false;

  bool _active = false;

  /// A playback session exists (playing or paused). When false, everything
  /// is shown and renderers draw exactly as without playback.
  bool get active => _active;

  bool get playing => _ticker.isActive;

  double _clock = 0;
  double get clock => _clock;
  double get duration => _schedule.duration;
  double get progress => duration == 0 ? 0 : (_clock / duration).clamp(0, 1);

  int get revealedCount => _active ? _schedule.revealedCount(_clock) : 0;
  int get total => _schedule.ids.length;

  /// Cursor as a fractional year, or null when idle.
  double? get cursorYear => _active ? _schedule.yearAt(_clock) : null;

  /// Most recently revealed story, or null when idle / before the first.
  LabStory? get current {
    if (!_active) return null;
    final i = _schedule.currentIndex(_clock);
    return i < 0 ? null : _entries![i].story;
  }

  /// Visibility of [storyId]: 1 when idle.
  double reveal(String storyId) => _active
      ? _schedule.reveal(
          storyId,
          _clock,
          fade: reducedMotion ? 0 : _schedule.fade,
        )
      : 1;

  void play() {
    if (total == 0) return;
    if (!_active || _clock >= duration) _clock = 0;
    _active = true;
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
    notifyListeners();
  }

  void pause() {
    if (_ticker.isActive) _ticker.stop();
    notifyListeners();
  }

  /// Ends the session and shows everything again.
  void stop() {
    if (_ticker.isActive) _ticker.stop();
    _active = false;
    _clock = 0;
    notifyListeners();
  }

  /// Moves the clock; starts a paused session if idle.
  void seek(double t) {
    _active = true;
    _clock = t.clamp(0, duration);
    notifyListeners();
  }

  /// Steps to the previous/next distinct reveal (a story, or a year in batch
  /// mode) and shows it fully. Pauses.
  void step(int delta) {
    if (total == 0) return;
    if (_ticker.isActive) _ticker.stop();
    final at = _schedule.revealAt;
    final c = _active ? _schedule.currentIndex(_clock) : -1;
    final int target;
    if (delta > 0) {
      target = c < 0 ? 0 : _schedule.revealedCount(at[c]).clamp(0, total - 1);
    } else {
      target = c <= 0 ? 0 : (_schedule.startedBefore(at[c]) - 1).clamp(0, c);
    }
    seek(at[target] + _schedule.fade);
  }

  void setSpeed(double speed) {
    _speed = speed;
    notifyListeners();
  }

  void setFollow(bool follow) {
    if (_follow == follow) return;
    _follow = follow;
    notifyListeners();
  }

  void setDesign(PlaybackDesign design) {
    if (design == _design) return;
    _design = design;
    _rebuild(keepYear: cursorYear);
    notifyListeners();
  }

  void _onLab() {
    final rendererChanged = _lab.renderer != _renderer;
    final entriesChanged = !identical(_lab.entries, _entries);
    if (rendererChanged) {
      _renderer = _lab.renderer;
      if (!_active) _design = defaultDesignFor(_lab.renderer);
    }
    if (entriesChanged || rendererChanged) {
      _rebuild(keepYear: cursorYear);
      notifyListeners();
    }
  }

  /// Rebuilds the schedule from the lab's entries, keeping the cursor on the
  /// same year so a filter change mid-play doesn't jump.
  void _rebuild({required double? keepYear}) {
    _entries = _lab.entries;
    _renderer ??= _lab.renderer;
    _schedule = switch (_design) {
      PlaybackDesign.sweep => PlaybackSchedule.sweep(_entries!),
      PlaybackDesign.steps => PlaybackSchedule.steps(_entries!),
    };
    if (keepYear != null) {
      _clock = _schedule.timeForYear(keepYear).clamp(0, _schedule.duration);
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    _clock += dt * _speed;
    if (_clock >= duration) {
      _clock = duration;
      _ticker.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _lab.removeListener(_onLab);
    _ticker.dispose();
    super.dispose();
  }
}
