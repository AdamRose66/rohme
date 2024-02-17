/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

import 'dart:async';

void main() async {
  group('A group of tests', () {
    setUp(() {
    });

    test('clock test', () async {
      Simulator simulator = Simulator( clockPeriod : SimDuration( picoseconds : 10 ) );

      simulator.run( ( simulator ) async {
        await clockDelay( 2 );
        print('elapsed time is ${simulator.elapsed}');
        print('${simulator.elapsedTicks} clock ticks have elapsed');

        expect( simulator.elapsed , simulator.clockPeriod * 2 );
      });

      simulator.elapse( SimDuration( picoseconds : 1000 ) );
    });
    test('clock zone test', () async {
      Simulator simulator = Simulator( clockPeriod : SimDuration( picoseconds : 10 ) );
      ClockZone clockZone = ClockZone( 'zone' , simulator.zone , 2 );

      clockZone.run( ( clockZone ) async {
        await clockDelay( 2 );
        print('elapsed time is ${simulator.elapsed}');

        print('${simulator.elapsedTicks} simulator ticks have elapsed');
        print('${clockZone.elapsedTicks} clock ticks have elapsed');

        expect( clockZone.elapsedTicks , 2 );
        expect( simulator.elapsedTicks , 4 );
        expect( simulator.elapsed , clockZone.clockPeriod * 2 );
        expect( simulator.elapsed , simulator.clockPeriod * 4 );
      });

      simulator.elapse( SimDuration( picoseconds : 1000 ) );
    });

    test('hierarchical clock zone test', () async {
      Simulator simulator = Simulator( clockPeriod : SimDuration( picoseconds : 10 ) );
      ClockZone clockZone1 = ClockZone( 'zone1' , simulator.zone , 2 );
      ClockZone clockZone2 = ClockZone( 'zone2' , clockZone1.zone , 2 );

      clockZone2.run( ( clockZone ) async {
        await clockDelay( 2 );
        print('elapsed time is ${simulator.elapsed}');

        print('${simulator.elapsedTicks} simulator ticks have elapsed');
        print('${clockZone1.elapsedTicks} clock1 ticks have elapsed');
        print('${clockZone2.elapsedTicks} clock2 ticks have elapsed');

        expect( simulator.elapsed , simulator.clockPeriod * 8 );
        expect( simulator.elapsedTicks , 8 );
        expect( clockZone1.elapsedTicks , 4 );
        expect( clockZone2.elapsedTicks , 2 );
      });

      simulator.elapse( SimDuration( picoseconds : 1000 ) );
    });

    test('delay', () async {
      Simulator simulator = Simulator( clockPeriod : SimDuration( picoseconds : 10 ) );
      ClockZone clockZone1 = ClockZone( 'zone1' , simulator.zone , 2 );
      ClockZone clockZone2 = ClockZone( 'zone2' , clockZone1.zone , 2 );

      simulator.run( ( simulator ) async {
        await clockZone2.delay( 2 );
        print('elapsed time is ${simulator.elapsed}');
        expect( simulator.elapsed , simulator.clockPeriod * 8 );
      });

      simulator.elapse( SimDuration( picoseconds : 1000 ) );
    });

    test('suspend / resume', () async {
      Simulator simulator = Simulator( clockPeriod : SimDuration( picoseconds : 10 ) );
      ClockZone clockZone1 = ClockZone( 'zone1' , simulator.zone , 2 );
      ClockZone clockZone2 = ClockZone( 'zone2' , clockZone1.zone , 2 );

      List<SimDuration> zone1Trace = [];
      List<SimDuration> zone2Trace = [];
      late final SimDuration suspendTime , resumeTime;

      clockZone1.run( ( clockZone ) {
        Timer.periodic( tickTime( 5 ) , ( timer ) async {
          print('$clockZone');
          zone1Trace.add( simulator.elapsed );
        });
      });

      clockZone2.run( ( clockZone ) {
        Timer.periodic( tickTime( 5 ) , ( timer ) async
        {
          print('$clockZone');
          zone2Trace.add( simulator.elapsed );
        });
      });

      simulator.run( ( simulator ) async {
        await clockZone1.delay( 15 );

        print('${simulator.elapsed} ready to suspend');
        suspendTime = simulator.elapsed;
        clockZone1.suspend();

        await clockZone1.delay( 15 );

        print('${simulator.elapsed} ready to resume');
        resumeTime = simulator.elapsed;

        clockZone1.resume();
      });

      simulator.elapse( SimDuration( picoseconds : 1000 ) );

      expect( clockZone1.name , 'simulator.zone1');
      expect( clockZone2.name , 'simulator.zone1.zone2');

      expect( zone1Trace.indexWhere( ( t ) => suspendTime < t && t < resumeTime ) , -1 );
      expect( zone2Trace.indexWhere( ( t ) => suspendTime < t && t < resumeTime ) , -1 );
    });

    test('illegal resume', () async {
      print('!!! Illegal Test !!!');
      Simulator simulator = Simulator( clockPeriod : SimDuration( picoseconds : 10 ) );
      ClockZone clockZone1 = ClockZone( 'zone1' , simulator.zone , 2 );

      clockZone1.run( ( clockZone ) {
        Timer.periodic( tickTime( 5 ) , ( timer ) async {
          print('$clockZone');
        });
      });

      simulator.run( ( simulator ) async {
        print('!!! started simulator run');
        await clockZone1.delay( 15 );

        print('${simulator.elapsed} ready to suspend');

        var suspendSet = simulator.suspend(
          clockZone1.zone ,
          ( zone ) => zone == clockZone1.zone );

        await clockZone1.delay( 15 );
        print('${simulator.elapsed} ready to resume');

        bool ok = true;

        try
        {
          simulator.resume( suspendSet );
        }
        on TimerNotInFuture catch( e )
        {
          print('seen expected exception $e');
          ok = false;
        }

        expect( ok , false );
        expect( clockZone1.clockName , clockZone1.name );
      });

      simulator.elapse( SimDuration( picoseconds : 1000 ) );
    });
  });

  test('ClockDelayPort test', () {
    simulateModel( () => Top('top') , clockPeriod : SimDuration( picoseconds : 10 ) );
  });
}

class Top extends Module
{
  late final ClockDelayPort clockDelayPort;
  late final ClockZone clockZone;

  Top( super.name )
  {
    clockDelayPort = ClockDelayPort('clockDelayPort',this);
    clockZone = ClockZone('zone' , simulator.zone , 2 );
  }

  @override
  void connect()
  {
    clockDelayPort.implementedBy( clockZone );
  }

  @override
  void run()
  {
    doDelay();
  }

  Future<void> doDelay() async
  {
    await clockDelayPort.delay( 3 );
    print('$clockZone');
    expect( simulator.elapsed , SimDuration( picoseconds : 60 ) );
  }
}
