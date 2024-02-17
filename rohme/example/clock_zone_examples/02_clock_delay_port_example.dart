/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:rohme/rohme.dart';
import 'dart:async';

/// This example shows how to reference a clock generated in one part
/// of the [Module] hierarchy in a distant part of the hierarchy, by
/// connecting [ClockDelayPort]s across the hierarchy.

void main()
{
  simulateModel( () => Top('top') ,
            clockPeriod : SimDuration( picoseconds : 10 ) ,
            duration : SimDuration( picoseconds : 1000 ) );
}

class Top extends Module
{
  late final ClockGenerator clockGenerator;
  late final Child child1 , child2;

  Top( super.name )
  {
    /// create the [ClockGenerator] and the two [Child] modules
    clockGenerator = ClockGenerator('clockGenerator',this);
    child1 = Child('child1' , this);
    child2 = Child('child2' , this);
  }

  @override
  void connect()
  {
    /// Connect child clocks to the generator clocks
    child1.clock <= clockGenerator.clock1;
    child2.clock <= clockGenerator.clock2;
  }
}

/// [ClockGenerator] generates two related clocks
class ClockGenerator extends Module
{
  /// The two external [ClockDelayPort] exports
  late final ClockDelayPort clock1 , clock2;

  /// The two private [ClockZone]s
  late final ClockZone _clockZone1,  _clockZone2;

  ClockGenerator( super.name , super.parent )
  {
    _clockZone1 = ClockZone( 'zone1' , simulator.zone , 2 );
    _clockZone2 = ClockZone( 'zone2' , _clockZone1.zone , 2 );

    clock1 = ClockDelayPort('clockPort1',this);
    clock2 = ClockDelayPort('clockPort2',this);
  }

  @override
  void connect()
  {
    /// Connect both exports directly to their [ClockZone] implentations
    clock1.implementedBy( _clockZone1 );
    clock2.implementedBy( _clockZone2 );
  }
}

class Child extends Module
{
  /// Each child is connected to its own clock
  late final ClockDelayPort clock;

  Child( super.name , super.parent )
  {
    clock = ClockDelayPort('clock' , this );
  }

  @override
  void run()
  {
    loop();
  }

  Future<void> loop () async
  {
    while( true )
    {
      await clock.delay( 5 );
      mPrint('${clock.clockName} : ${clock.elapsedTicks}');
    }
  }
}
