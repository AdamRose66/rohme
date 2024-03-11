/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:async';
import 'sim_duration.dart';

import 'package:rohd/rohd.dart' as rohd show Simulator;

typedef _RohdSim = rohd.Simulator;

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
///  await simulator.elapse( SimDuration( picoseconds : 1000 ) );
/// ```
/// This class uses [SimDuration] to allow finer grained time resolution than
/// is provided by FakeAsync and [Duration].
class Simulator {
  /// the zone that all simulator processes are run in.
  late final Zone zone;

  /// The amount of time that has elapsed since the beginning of the simulation.
  SimDuration get elapsed => clockPeriod * _RohdSim.time;

  /// The notional clock period for this Simulator. Used by [clockDelay].
  SimDuration clockPeriod;

  /// the name of this simulator
  final String name;

  /// The number of clock ticks elapsed since start of simulation
  int get elapsedTicks => _RohdSim.time;

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
      this.name = 'simulator'}) {
    zone = Zone.current.fork(
        zoneValues: {#clockPeriod: clockPeriod, #simulator: this, #name: name},
        specification: ZoneSpecification(
            createTimer: (_, __, ___, duration, callback) =>
                _createTimer(duration, callback, false),
            createPeriodicTimer: (_, __, ___, duration, callback) =>
                _createTimer(duration, callback, true),
            scheduleMicrotask: (_, __, ___, microtask) =>
                _RohdSim.injectAction(microtask)));
  }

  /// Simulates the asynchronous passage of time.
  Future<void> elapse(SimDuration duration) async {
    _RohdSim.setMaxSimTime(duration.inPicoseconds ~/ clockPeriod.inPicoseconds);
    await _RohdSim.run();
    print('sim done after $elapsed');
  }

  static void resetRohdSim() async => await _RohdSim.reset();

  /// The currently active [SimTimer]s
  final Set<SimTimer> _activeTimers = <SimTimer>{};

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

  /// Creates a new timer controlled by `this` that fires [callback] after
  /// [duration] (or every [duration] if [periodic] is `true`).
  Timer _createTimer(Duration duration, Function callback, bool periodic) {
    SimDuration simDuration =
        duration is SimDuration ? duration : SimDuration.fromDuration(duration);
    final timer = SimTimer._(simDuration, callback, periodic, this);
    return timer;
  }

  /// suspends all timers for which selector( timer.zone ) is true
  ///
  /// cancels all timers for which selector( timer.zone ) is true, removes
  /// the timer from [_activeTimers] and returns the Set of suspended timers
  /// so that they can be [resume]d later.
  Set<SimTimer> suspend(Zone zone, bool Function(Zone) selector) {
    var toBeSuspended = _activeTimers.where((timer) => selector(zone));
    Set<SimTimer> selectedTimers = Set.from(toBeSuspended);

    /// ignore: avoid_function_literals_in_foreach_calls
    selectedTimers.forEach((timer) => timer.cancel());
    return selectedTimers;
  }

  /// Resumes suspended timers
  void resume(Set<SimTimer> suspendedTimers) {
    // ignore: avoid_function_literals_in_foreach_calls
    suspendedTimers.forEach((timer) {
      timer.resume();
    });
  }

  /// Schedules and waits for the completion of a microtask
  ///
  /// The [action] will normally be a Future, and most likely used for handling
  /// an external stream.
  Future<void> blockingMicrotask(dynamic Function() action) async =>
      await _blockUntil(_RohdSim.injectAction, action);

  /// Schedules and waits for the completion of an action in the next delta cycle
  ///
  /// The [action] will normally be a Future, and most likely used for handling
  /// an external stream.
  Future<void> blockingDelta(dynamic Function() action) async =>
      await _blockUntil(
          (action) => _RohdSim.registerAction(_RohdSim.time, action), action);

  /// Schedules and waits for an [action] using an arbitrary [registrationMethod]
  ///
  /// [registrationMethod] will typically interact with the core simulator in
  /// some way.
  ///
  /// The [action] will normally be a Future, and most likely used for handling
  /// an external stream.
  ///
  /// Used in [blockingMicrotask] and [blockingDelta].
  Future<void> _blockUntil(
      registrationMethod, dynamic Function() action) async {
    Completer<void> completer = Completer();

    registrationMethod(() async {
      await action();
      completer.complete();
    });

    await completer.future;
  }
}

/// An implementation of [Timer] that's controlled by a [Simulator].
class SimTimer implements Timer {
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

  /// The zone in which this timer was created
  final Zone zone = Zone.current;

  late bool _isActive;
  var _tick = 0;

  @override
  int get tick => _tick;

  @override
  bool get isActive => _isActive;

  SimTimer._(this.duration, this._callback, this.isPeriodic, this._simulator) {
    _activate();
    _scheduleNext();
  }

  /// cancels this timer ( although it may be resumed later )
  @override
  void cancel() {
    _RohdSim.cancelAction(_nextTick, _fire);
    _deactivate();
  }

  /// Increments the scheduled next call time by [duration]
  ///
  /// Typically called between [cancel] and [resume]. Will have unpredictable
  /// effects if called while timer is active.
  void reschedule(SimDuration duration) {
    _nextCall += duration;
  }

  /// Resumes a previously cancelled timer
  void resume() {
    _activate();
    _RohdSim.registerAction(_nextTick, _fire);
  }

  /// calls [_callback], and manages [_tick], [_isActive] and the next firing
  void _fire() {
    if (isPeriodic) {
      _callback(this);
      _tick++;
      if (_isActive) _scheduleNext();
    } else {
      _deactivate();
      _callback();
    }
  }

  void _scheduleNext() {
    _nextCall = _simulator.elapsed + duration;
    _RohdSim.registerAction(_nextTick, _fire);
  }

  void _activate() {
    _simulator._activeTimers.add(this);
    _isActive = true;
  }

  void _deactivate() {
    _simulator._activeTimers.remove(this);
    _isActive = false;
  }

  int get _nextTick =>
      _nextCall.inPicoseconds ~/ _simulator.clockPeriod.inPicoseconds;

  @override
  String toString() =>
      '_nextCall $_nextCall isPeriodic $isPeriodic zone ${zone[#name]}';
}
