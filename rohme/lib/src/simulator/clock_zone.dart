
import 'sim_duration.dart';
import 'simulator.dart';
import '../modelling/port.dart';

import 'dart:async';

/// waits n ticks, as defined by zone[#clockPeriod]
///
/// The clockPeriod is defined in the constructor of [Simulator] or [ClockZone]
/// and is passed into the Zone as a zone value. This means that
/// ```dart
/// await clockDelay( n );
/// ```
/// can use the current Zone's clockPeriod to await the appropriate amount of
/// simulation time.
Future<void> clockDelay( int n ) async
{
  await Future.delayed( tickTime( n ) );
}

/// Returns a [SimDuration] equivalent to n clock ticks in the current [Zone]
SimDuration tickTime( int n ) => Zone.current[#clockPeriod] * n;

/// An abstract interface used to remotely await in a [ClockZone]
abstract interface class ClockDelayIf
{
  Future<void> delay( int n );
}

/// A convenience [Port] for [ClockDelayIf]
///
/// ```dart
/// late final ClockDelayPort clock;
/// ...
/// await clock.delay( 3 );
/// ```
class ClockDelayPort extends Port<ClockDelayIf> implements ClockDelayIf
{
  ClockDelayPort( super.name , super.parent );
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
class ClockZone implements ClockDelayIf
{
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
  Set<FakeTimer> _suspended = <FakeTimer>{};

  /// The time of the last suspension
  SimDuration _suspensionTime = SimDuration.zero;

  /// Forks a new zone with the same scheduler and a longer clockPeriod as the
  /// [parentZone].
  ClockZone( String name , Zone parentZone , this.divisor ) :
    clockPeriod = parentZone[#clockPeriod] * divisor ,
    simulator = parentZone[#simulator] ,
    zone = parentZone.fork(
      zoneValues: {
        #clockPeriod: parentZone[#clockPeriod] * divisor ,
        #parentZone : parentZone ,
        #name: '${parentZone[#name]}.$name'
      }
    );

  /// Returns the full hierarchical name of this [ClockZone]
  String get name => zone[#name];

  @override
  String toString() => '$name : time ${zone[#simulator].elapsed} ticks $elapsedTicks';

  /// Runs callback in [zone]
  R run<R>( R Function( ClockZone ) callback ) => zone.run( () => callback( this ) );

  /// delays n [clockPeriod]s, whichever zone this is called from.
  ///
  /// ```dart
  /// await clockDelay( n );
  /// ```
  /// will resume n [clockPeriod]s after the await.
  @override
  Future<void> delay( int n ) async
  {
    await run( ( clockZone ) async { await clockDelay( n ); } );
  }

  /// Returns the number of elapsed clock ticks
  int get elapsedTicks => simulator.elapsed.inPicoseconds ~/ clockPeriod.inPicoseconds;

  /// Suspends all timers in [simulator] that are in [zone] or one of its
  /// chidren.
  ///
  /// Also stores the time of suspension. Does nothing if no resume has been
  /// called after previous suspension.
  void suspend()
  {
    if( _suspended.isNotEmpty )
    {
      return;
    }

    _suspended = simulator.suspend( zone , ( zone ) => _equalsOrIsChild( zone ) );
    _suspensionTime = simulator.elapsed;
  }

  /// Resumes previously suspended Timers
  ///
  /// Adds the time since the suspension to all suspended timers before
  /// adding them back into [Simulator]
  ///
  void resume()
  {
    if( _suspended.isEmpty )
    {
      return;
    }

    SimDuration timeSinceSuspension = simulator.elapsed - _suspensionTime;

    // ignore: avoid_function_literals_in_foreach_calls
    _suspended.forEach( (timer) => timer.reschedule( timeSinceSuspension ) );

    simulator.resume( _suspended );
  }

  /// is child this, or a (recursive) child of this
  bool _equalsOrIsChild( Zone child )
  {
    for( Zone? c = child; c != null; c = c[#parentZone] )
    {
      if( c == zone )
      {
        return true;
      }
    }

    return false;
  }
}
