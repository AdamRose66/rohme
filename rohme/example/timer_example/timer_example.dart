/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:rohme/rohme.dart';

import 'register_map.dart';
import 'hardware_timer.dart';

void main() async {
  initialiseRegisterMap();
  simulateModel( () { return Top('top'); } );
}

class Top extends Module
{
  late final Memory memory;
  late final HardWareTimer hardwareTimer;
  late final Signal timerIrq;
  late final SimClock clock;

  int memoryWriteAddress = 0;

  Top( super.name )
  {
    clock = SimClock( SimDuration( microseconds : 10 ) );

    memory = Memory('memoryA',this,0x1000);
    hardwareTimer = HardWareTimer('timer',this);
    timerIrq = Signal();
  }

  @override
  void connect()
  {
    hardwareTimer.irq.implementedBy( timerIrq );
    hardwareTimer.clock.implementedBy( clock );

    timerIrq.alwaysAt( ( signal ) { interrupt(); } , posEdge );
  }

  Future<void> interrupt() async
  {
    mPrint('interrupt');
    for( int i = 0; i < 4; i++ , memoryWriteAddress += 4 )
    {
      await memory.write32( memoryWriteAddress , i );
      mPrint('  just written ${i.hex()} to ${memoryWriteAddress.hex()}');
    }
  }

  @override
  void run()
  {
    clock.start();
    timerStimulus();
  }

  Future<void> timerStimulus() async
  {
    const loops = 3;
    const clocksPerLoop = 10;

    registerMap[0x0].write( clocksPerLoop );
    registerMap[0x4]['CONTINUOUS'].write( 1 );
    registerMap[0x4]['START'].write( 1 );

    Future.delayed( clock.clockPeriod *  clocksPerLoop * loops , () {
      registerMap[0x4]['STOP'].write( 1 );
      mPrint('${registerMap[0x8].read()} timer loops have expired');
    } );
  }
}
