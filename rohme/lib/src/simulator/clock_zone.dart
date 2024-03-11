/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
import 'sim_duration.dart';
import 'simulator.dart';
import '../modelling/port.dart';

import 'dart:async';

/// waits n ticks, as defined by the zone's clockPeriod.
///
/// The clockPeriod is defined in the constructor of [Simulator] or [ClockZone]
/// and is passed into the Zone as a zone value. This means that
/// ```dart
/// await clockDelay( n );
/// ```
/// can use the current Zone's clockPeriod to await the appropriate amount of
/// simulation time.
Future<void> clockDelay(int n) async {
  await Future.delayed(tickTime(n));
}

/// Returns a [SimDuration] equivalent to n clock ticks in the current [Zone]
SimDuration tickTime(int n) => Zone.current[#clockPeriod] * n;

/// An abstract interface used to remotely await in a [ClockZone]
abstract interface class ClockDelayIf {
  /// Waits n clock cycles in the [ClockZone]
  Future<void> delay(int n);

  /// Returns the number of elapsed ticks in the [ClockZone]
  int get elapsedTicks;

  /// The name of the [ClockZone]
  String get clockName;
}

/// A convenience [Port] for [ClockDelayIf]
///
/// ```dart
/// late final ClockDelayPort clock;
/// ...
/// await clock.delay( 3 );
/// print('${clock.clockName}: ticks ${clock.elapsedTicks}');
/// ```
class ClockDelayPort extends Port<ClockDelayIf> implements ClockDelayIf {
  ClockDelayPort(super.name, super.parent);
}

/// Divides the [parentZone]'s clock frequency, for use in [clockDelay]
///
/// This class forks a new [Zone] which divides the parent's clock by [divisor].
/// ( In other words, it multiplies the parent's clock period by [divisor] ).
///
/// Functions [run] by this clockZone will see the divided ( slower ) clock when
/// they call [clockDelay].
/// ```dart
/// Simulator simulator = Simulator( clockPeriod : SimDuration( picoseconds : 10 ) );
/// ClockZone clockZone1 = ClockZone( simulator.zone , 2 );
/// ClockZone clockZone2 = ClockZone( clockZone1.zone , 2 );
///
/// clockZone2.run( () async {
///  await clockDelay( 2 );
///
///  print('${simulator.elapsedTicks} simulator ticks have elapsed'); // prints 8
///  print('${clockZone1.elapsedTicks} clock1 ticks have elapsed');   // prints 4
///  print('${clockZone2.elapsedTicks} clock2 ticks have elapsed');   // prints 2
/// }
/// ```
/// Note: we assume that the parentZone has #simulator and #clockPeriod zoneValues
/// in its zoneValues array. This is guaranteed if the zone is [Simulator.zone]
/// or [ClockZone.zone].
///
class ClockZone implements ClockDelayIf {
  /// The amount by which the [parentZone]'s clock frequency is divided
  ///
  /// In other words, the amount by which the [clockPeriod] is mutliplied
  final int divisor;

  /// The [parentZone]'s clock multiplied by the [divisor].
  final SimDuration clockPeriod;

  /// The underlying simulator
  final Simulator simulator;

  /// The [Zone] which this [ClockZone] forks.
  final Zone zone;

  /// The set of currently suspended timers.
  Set<SimTimer> _suspended = <SimTimer>{};

  /// The time of the last suspension
  SimDuration _suspensionTime = SimDuration.zero;

  /// Forks a new zone with the same scheduler and a longer clockPeriod as the
  /// [parentZone].
  ClockZone(String name, Zone parentZone, this.divisor)
      : clockPeriod = parentZone[#clockPeriod] * divisor,
        simulator = parentZone[#simulator],
        zone = parentZone.fork(zoneValues: {
          #clockPeriod: parentZone[#clockPeriod] * divisor,
          #parentZone: parentZone,
          #name: '${parentZone[#name]}.$name'
        });

  /// Returns the full hierarchical name of this [ClockZone]
  String get name => zone[#name];

  /// Same as [name], used to disambiguate when used in [ClockDelayPort]
  ///
  /// Needed since [Port] has its own name getter.
  @override
  String get clockName => name;

  @override
  String toString() =>
      '$name : time ${zone[#simulator].elapsed} ticks $elapsedTicks';

  /// Runs callback in [zone]
  R run<R>(R Function(ClockZone) callback) => zone.run(() => callback(this));

  /// delays n [clockPeriod]s, whichever zone this is called from.
  ///
  /// ```dart
  /// await clockDelay( n );
  /// ```
  /// will resume n [clockPeriod]s after the await.
  @override
  Future<void> delay(int n) async {
    await run((clockZone) async {
      await clockDelay(n);
    });
  }

  /// Returns the number of elapsed clock ticks
  @override
  int get elapsedTicks =>
      simulator.elapsed.inPicoseconds ~/ clockPeriod.inPicoseconds;

  /// Suspends all timers in [simulator] that are in [zone] or one of its
  /// chidren.
  ///
  /// Also stores the time of suspension. Does nothing if no resume has been
  /// called after previous suspension.
  void suspend() {
    if (_suspended.isNotEmpty) {
      return;
    }

    print('doing clock zone suspend');
    _suspended = simulator.suspend(zone, (zone) => _equalsOrIsChild(zone));
    _suspensionTime = simulator.elapsed;
  }

  /// Resumes previously suspended Timers
  ///
  /// Adds the time since the suspension to all suspended timers before
  /// adding them back into [Simulator]
  ///
  void resume() {
    if (_suspended.isEmpty) {
      return;
    }

    SimDuration timeSinceSuspension = simulator.elapsed - _suspensionTime;

    // ignore: avoid_function_literals_in_foreach_calls
    _suspended.forEach((timer) => timer.reschedule(timeSinceSuspension));

    simulator.resume(_suspended);
  }

  /// is child this, or a (recursive) child of this
  bool _equalsOrIsChild(Zone child) {
    for (Zone? c = child; c != null; c = c[#parentZone]) {
      if (c == zone) {
        return true;
      }
    }

    return false;
  }
}
