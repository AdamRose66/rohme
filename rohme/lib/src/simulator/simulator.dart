// Copyright 2014 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// The code in this file is a clone of [FakeAsync], originally pubished by google
// under the license above.

// Copyright 2024 Adam Rose
//
// In 2024, Adam Rose modified the original code to work using a higher precision
// [SimDuration] class, so that it can be used for modelling digital systems.
//
// These modifications are made under the BSD-3 License
//
import 'dart:async';
import 'dart:collection';

import 'sim_duration.dart';
import 'queue_map.dart';

/// The type of a microtask callback.
typedef _Microtask = void Function();

/// A clone of FakeAsync, that mocks out the passage of time within a [Zone].
///
/// Time consuming code to be simulated is passed to [run], which causes the
/// the code to be run in a [Zone] which fakes timer and microtask creation.
///
/// The code is actually executed by an Event wheel implemented in [elapse].
/// ```dart
/// Simulator simulator = Simulator();
///
/// simulator.run( ( simulator ) async {
///   await Future.delayed( SimDuration( picoseconds : 10 ) );
///  });
///
///  simulator.elapse( SimDuration( picoseconds : 1000 ) );
/// ```
/// This class uses [SimDuration] to allow finer grained time resolution than
/// is provided by FakeAsync and [Duration].
class Simulator {
  /// the zone that all simulator processes are run in.
  late final Zone zone;

  /// The amount of time that has elapsed since the beginning of the simulation.
  SimDuration get elapsed => _elapsed;
  var _elapsed = SimDuration.zero;

  /// Whether Timers created by this Simulator will include a creation stack
  /// trace in [Simulator.pendingTimersDebugString].
  final bool includeTimerStackTrace;

  /// The notional clock period for this Simulator. Used by [clockDelay].
  SimDuration clockPeriod;

  /// the name of this simulator
  final String name;

  /// The number of clock ticks elapsed since start of simulation
  int get elapsedTicks => _elapsed.inPicoseconds ~/ clockPeriod.inPicoseconds;

  /// The time at which the current call to [elapse] will finish running.
  ///
  /// This is `null` if there's no current call to [elapse].
  SimDuration? _elapsingTo;

  /// Tasks that are scheduled to run when fake time progresses.
  final _microtasks = Queue<_Microtask>();

  /// A [QueueMap] of the pending but not executed timers.
  final _timers = QueueMap<SimDuration, SimTimer>();

  /// The queue of timers in the current delta cycle
  ListQueue<SimTimer> _thisDeltaQueue = ListQueue();

  /// All the current pending timers.
  List<SimTimer> get pendingTimers {
    List<SimTimer> list = _thisDeltaQueue.toList();
    list.addAll(_timers);
    return list;
  }

  /// The debug strings for all the current pending timers.
  List<String> get pendingTimersDebugString =>
      pendingTimers.map((timer) => timer.debugString).toList(growable: false);

  /// The number of active periodic timers created within a call to [run].
  int get periodicTimerCount =>
      _thisDeltaQueue.where((timer) => timer.isPeriodic).length +
      _timers.where((timer) => timer.isPeriodic).length;

  /// The number of active non-periodic timers created within a call to [run]
  int get nonPeriodicTimerCount =>
      _thisDeltaQueue.where((timer) => !timer.isPeriodic).length +
      _timers.where((timer) => !timer.isPeriodic).length;

  /// The number of pending microtasks scheduled within a call to [run]
  int get microtaskCount => _microtasks.length;

  /// Creates a [Simulator].
  ///
  /// A Zone is forked here, for use later in [run].
  ///
  /// The [zone] specifies local implementations of createTimer,
  /// createPeriodicTimer and scheduleMicrotask.
  ///
  /// The [clockPeriod], this, and [name] are passed into the simulator's
  /// [zone] as zone values.
  Simulator(
      {this.clockPeriod = const SimDuration(picoseconds: 1),
      this.includeTimerStackTrace = true,
      this.name = 'simulator'}) {
    zone = Zone.current.fork(
        zoneValues: {#clockPeriod: clockPeriod, #simulator: this, #name: name},
        specification: ZoneSpecification(
            createTimer: (_, __, ___, duration, callback) =>
                _createTimer(duration, callback, false),
            createPeriodicTimer: (_, __, ___, duration, callback) =>
                _createTimer(duration, callback, true),
            scheduleMicrotask: (_, __, ___, microtask) =>
                _microtasks.add(microtask)));
  }

  /// Simulates the asynchronous passage of time.
  ///
  /// Throws an [ArgumentError] if [SimDuration] is negative. Throws a [StateError]
  /// if a previous call to [elapse] has not yet completed.
  ///
  /// Any timers created within [run] will fire if their time is within
  /// [duration]. The microtask queue is processed before and after each
  /// timer fires.
  void elapse(SimDuration duration) {
    if (duration.inPicoseconds < 0) {
      throw ArgumentError.value(duration, 'duration', 'may not be negative');
    } else if (_elapsingTo != null) {
      throw StateError('Cannot elapse until previous elapse is complete.');
    }

    _elapsingTo = _elapsed + duration;
    _fireTimersWhile((callTime) => callTime <= _elapsingTo!);
    _elapseTo(_elapsingTo!);
    _elapsingTo = null;
  }

  /// Simulates the synchronous passage of time, resulting from blocking or
  /// expensive calls.
  ///
  /// Neither timers nor microtasks are run during this call, but if this is
  /// called within [elapse] they may fire afterwards.
  ///
  /// Throws an [ArgumentError] if [duration] is negative.
  void elapseBlocking(SimDuration duration) {
    if (duration.inPicoseconds < 0) {
      throw ArgumentError('Cannot call elapse with negative duration');
    }

    _elapsed += duration;
    final elapsingTo = _elapsingTo;
    if (elapsingTo != null && _elapsed > elapsingTo) _elapsingTo = _elapsed;
  }

  /// Runs [callback] in a [Zone] where all asynchrony is controlled by `this`.
  ///
  /// All [Future]s, [Stream]s, [Timer]s, microtasks, and other time-based
  /// asynchronous features used within [callback] are simulated by [elapse]
  /// rather than the passing of real time.
  ///
  /// Calls [callback] with `this` as argument and returns its result.
  ///
  T run<T>(T Function(Simulator self) callback) =>
      zone.run(() => callback(this));

  /// Runs all pending microtasks scheduled within a call to [run] until there
  /// are no more microtasks scheduled.
  ///
  /// Does not run timers.
  void flushMicrotasks() {
    while (_microtasks.isNotEmpty) {
      _microtasks.removeFirst()();
    }
  }

  /// Elapses time until there are no more active timers.
  ///
  /// If `flushPeriodicTimers` is `true` (the default), this will repeatedly run
  /// periodic timers until they're explicitly canceled. Otherwise, this will
  /// stop when the only active timers are periodic.
  ///
  /// The [timeout] controls how much fake time may elapse before a [StateError]
  /// is thrown. This ensures that a periodic timer doesn't cause this method to
  /// deadlock. It defaults to one hour.
  void flushTimers(
      {SimDuration timeout = const SimDuration(hours: 1),
      bool flushPeriodicTimers = true}) {
    final absoluteTimeout = _elapsed + timeout;
    _fireTimersWhile((callTime) {
      if (callTime > absoluteTimeout) {
        // TODO(nweiz): Make this a [TimeoutException].
        throw StateError('Exceeded timeout $timeout while flushing timers');
      }

      if (flushPeriodicTimers) return _timers.isNotEmpty;

      // Continue firing timers until the only ones left are periodic *and*
      // every periodic timer has had a change to run against the final
      // value of [_elapsed].
      return _timers
          .any((timer) => !timer.isPeriodic || timer._nextCall <= _elapsed);
    });
  }

  /// Invoke the callback for each timer until [predicate] returns `false` for
  /// the next timer that would be fired.
  ///
  /// Microtasks are flushed before and after each timer is fired. Before each
  /// timer fires, [_elapsed] is updated to the appropriate duration.
  void _fireTimersWhile(bool Function(SimDuration callTime) predicate) {
    for (flushMicrotasks(); _timers.isNotEmpty; flushMicrotasks()) {
      SimDuration deltaTime = _timers.firstKey;

      if (!predicate(deltaTime)) {
        break;
      }

      _elapseTo(deltaTime);
      _thisDeltaQueue = _timers.removeFirstQueue();

      while (_thisDeltaQueue.isNotEmpty) {
        final timer = _thisDeltaQueue.removeFirst();
        assert(timer._nextCall == deltaTime);
        timer._fire();
      }
    }
  }

  /// Creates a new timer controlled by `this` that fires [callback] after
  /// [duration] (or every [duration] if [periodic] is `true`).
  Timer _createTimer(Duration duration, Function callback, bool periodic) {
    SimDuration simDuration =
        duration is SimDuration ? duration : SimDuration.fromDuration(duration);
    final timer = SimTimer._(simDuration, callback, periodic, this,
        includeStackTrace: includeTimerStackTrace);
    _timers.add(timer);
    return timer;
  }

  /// Sets [_elapsed] to [to] if [to] is longer than [_elapsed].
  void _elapseTo(SimDuration to) {
    if (to > _elapsed) _elapsed = to;
  }

  /// removes all timers for which selector( timer.zone ) is true
  Set<SimTimer> suspend(Zone zone, bool Function(Zone) selector) {
    Set<SimTimer> selectedTimers = <SimTimer>{};

    _thisDeltaQueue.removeWhere((timer) {
      bool selected = selector(timer.zone);
      if (selected) selectedTimers.add(timer);
      return selected;
    });

    _timers.removeWhere((timer) {
      bool selected = selector(timer.zone);
      if (selected) selectedTimers.add(timer);
      return selected;
    });

    return selectedTimers;
  }

  /// adds [suspendedTimers] back into _timers.
  ///
  /// Checks that no timer in [suspendedTimers] is in the past. If it is,
  /// throws TimerNotInFuture.
  void resume(Set<SimTimer> suspendedTimers) {
    // check we're not trying to resume a timer in the past
    // ignore: avoid_function_literals_in_foreach_calls
    suspendedTimers.forEach((timer) {
      if (timer._nextCall < elapsed) {
        throw TimerNotInFuture(elapsed, timer._nextCall);
      }
      _timers.add(timer);
    });
  }
}

class TimerNotInFuture implements Exception {
  SimDuration elapsed, nextCall;

  TimerNotInFuture(this.elapsed, this.nextCall);

  @override
  String toString() {
    return 'Current time is $elapsed , so cannot schedule timer at $nextCall, which is in the past';
  }
}

/// An implementation of [Timer] that's controlled by a [Simulator].
class SimTimer implements Timer, Indexable<SimDuration> {
  /// If this is periodic, the time that should elapse between firings of this
  /// timer.
  ///
  /// This is not used by non-periodic timers.
  final SimDuration duration;

  /// The callback to invoke when the timer fires.
  ///
  /// For periodic timers, this is a `void Function(Timer)`. For non-periodic
  /// timers, it's a `void Function()`.
  final Function _callback;

  /// Whether this is a periodic timer.
  final bool isPeriodic;

  /// The [Simulator] instance that controls this timer.
  final Simulator _simulator;

  /// The value of [Simulator._elapsed] at (or after) which this timer should be
  /// fired.
  late SimDuration _nextCall;

  /// The index used in [Simulation._timers]
  @override
  SimDuration get index => _nextCall;

  /// The current stack trace when this timer was created.
  ///
  /// If [Simulator.includeTimerStackTrace] is set to false then accessing
  /// this field will throw a [TypeError].
  StackTrace get creationStackTrace => _creationStackTrace!;
  final StackTrace? _creationStackTrace;

  /// The zone in which this time was created
  final Zone zone = Zone.current;

  bool _isCancelled = false;
  var _tick = 0;

  @override
  int get tick => _tick;

  /// Returns debugging information to try to identify the source of the
  /// [Timer].
  String get debugString => 'Timer (duration: $duration, periodic: $isPeriodic)'
      '${_creationStackTrace != null ? ', created:\n$creationStackTrace' : ''}';

  SimTimer._(
      SimDuration duration, this._callback, this.isPeriodic, this._simulator,
      {bool includeStackTrace = true})
      : duration = duration < SimDuration.zero ? SimDuration.zero : duration,
        _creationStackTrace = includeStackTrace ? StackTrace.current : null {
    _nextCall = _simulator._elapsed + this.duration;
  }

  @override
  bool get isActive => _simulator._timers.contains(this);

  @override
  void cancel() {
    _simulator._timers.remove(this);
    _isCancelled = true;
  }

  /// Fires this timer's callback and updates its state as necessary.
  void _fire() {
    _tick++;
    if (isPeriodic) {
      // ignore: avoid_dynamic_calls
      _callback(this);
      if (!_isCancelled) {
        reschedule(duration);
        _simulator._timers.add(this);
      }
    } else {
      // ignore: avoid_dynamic_calls
      _callback();
    }
  }

  /// increments _nextCall by duration
  void reschedule(SimDuration duration) {
    _nextCall += duration;
  }

  /// a string representation of this timer
  @override
  String toString() => '$index periodic $isPeriodic';
}
