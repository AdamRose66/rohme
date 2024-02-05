

import '../simulator.dart';

/// Gets SimDuration from simulator.elapsed
SimDuration get simDurationElapsed => SimDuration.fromDuration( simulator.elapsed );

/// A class which can be used to run a simulation in abstract time units
class SimDuration extends Duration
{
  SimDuration( int time ) : super( microseconds: time );
  SimDuration.fromDuration( Duration duration ) : this( duration.inMicroseconds );

  @override
  // ignore: unnecessary_brace_in_string_interps
  String toString() { return '${inMicroseconds}'; }
}
