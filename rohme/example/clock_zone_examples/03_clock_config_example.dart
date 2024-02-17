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

/// This example shows how to use the [config] database to provide different
/// clocks to particular components

void main()
{
  simulateModel( () {
      /// create the clocks zones
      ClockZone clockZone1 = ClockZone( 'zone1' , simulator.zone , 2 );
      ClockZone clockZone2 = ClockZone( 'zone2' , clockZone1.zone , 2 );

      // put them in the config
      config['top.child1.clock'] = clockZone1;
      config['top.child2.clock'] = clockZone2;

      // return the top level component of the simulation
      return Top('top');
    } ,
    clockPeriod : SimDuration( picoseconds : 10 ) ,
    duration : SimDuration( picoseconds : 1000 ) );
}

class Top extends Module
{
  late final Child child1 , child2;

  Top( super.name )
  {
    child1 = Child('child1' , this);
    child2 = Child('child2' , this);
  }
}

class Child extends Module
{
  late final ClockZone clock;

  Child( super.name , super.parent )
  {
    // get the clock out of the config db
    clock = getConfig<ClockZone>( 'clock' , component: this );
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
