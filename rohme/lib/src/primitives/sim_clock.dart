/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:async';

import '../simulator.dart';
import '../modelling.dart';


// TBD : possibly split the SimClock interface into two ?

/// A convenience Port for the entire SimClock interface
class SimClockPort extends Port<SimClock> implements SimClock
{
  SimClockPort( super.name , super.parent );
}

/// A Controllable Simulation Clock with a [clockPeriod] Duration
///
/// Client Processes can await on a specified number of [clockPeriod]s:
/// ```dart
/// await clock.delay( n );
/// ```
///
/// The clock controller process can start the clock with [start()] and stop it
// with [stop()]:
/// ```dart
/// SimClock clock = SimClock( Duration( microseconds : 100 ) );
/// clock.start();
/// await Future.delayed( clock.clockPeriod * 100 );
/// clock.stop();
/// await Future.delayed( clock.clockPeriod * 100 );
/// clock.stop();
///
/// If a Client Process is awaiting the clock when it is stopped, then it will
/// patiently wait for it restart.
///
/// The clock controller process can also cancel the clock altogether. This will
/// cause all awaiting clocks to immediately return false. It's up to the Client
/// process to decide how to deal with this.
///
/// /// ```dart
/// bool clockOK = await clock.delay( n );
/// if( !clockOk ) return;
/// ```
/// It might be worth turning this into an exception ...
class SimClock
{
  /// the period of the clock
  Duration clockPeriod;
  /// the time at which the clock last started
  late Duration elapsedAtStart;
  List<SimClockCompleter> _clockCompleterList = [];

  SimClock( this.clockPeriod );

  /// Waits for [n] [clockPeriod]s
  ///
  /// Returns true if the clock was not cancelled during the wait, false if was
  Future<bool> delay( int n )
  {
    SimClockCompleter clockCompleter = SimClockCompleter( this , n );
    _clockCompleterList.add( clockCompleter );
    return clockCompleter.future;
  }

  /// (re)Starts the clock
  Future<void> start() async {
    elapsedAtStart = simulator.elapsed;
    for( var c in _clockCompleterList )
    {
      c.start();
    }
  }

  /// Stops the clock.
  void stop()
  {
    for( var c in _clockCompleterList )
    {
      c.stop();
    }
  }

  /// Cancels the clock
  void cancel()
  {
    for( var c in _clockCompleterList )
    {
      c.cancel();
    }
    _clockCompleterList = [];
  }

  /// the number of [clockPeriod]s since the clock was last started
  int get ticksSinceStart
  {
    return (simulator.elapsed.inMicroseconds - elapsedAtStart.inMicroseconds) ~/ clockPeriod.inMicroseconds;
  }
}

// A class used by [SimClock]
class SimClockCompleter
{
  // the ticks remaining until completion, relative to when this completer was
  // last started
  int ticksUntilCompletion;

  // the number of clockPeriods consumed by this clock when this completer was
  // last started
  late int ticksWhenStarted;

  // the simClock that this completer was created by
  SimClock simClock;

  // the timer used to do the completion ( null if not started )
  //
  // We use a timer rather than a simple Future because timers are cancellable
  Timer? timer;

  // the completer that the client awaits
  final Completer<bool> completer = Completer();

  SimClockCompleter( this.simClock , this.ticksUntilCompletion )
  {
    start();
  }

  // stops ( ie pauses ) the completion
  //
  // Does nothing if not previously started.
  void stop()
  {
    if( timer != null )
    {
      timer?.cancel();
      ticksUntilCompletion -= ( simClock.ticksSinceStart - ticksWhenStarted );

      timer = null;
    }
  }

  // (re)starts the completion
  //
  // Does nothing if already started. Completes with true if not cancelled.
  void start()
  {
    if( timer == null )
    {
      ticksWhenStarted = simClock.ticksSinceStart;
      timer = Timer( simClock.clockPeriod * ticksUntilCompletion ,
        () {
          if( timer != null ) {
            simClock._clockCompleterList.remove( this );
            completer.complete( true );
          }
      } );
    }
  }

  // cancel completes the completion with false.
  void cancel()
  {
    timer = null;
    completer.complete( false );
  }

  Future<bool> get future => completer.future;
}
