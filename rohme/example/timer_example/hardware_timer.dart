
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

class HardWareTimer extends Module
{
  // external connections
  late final SignalWritePort irq;

  // internal fields and registers
  late final Register _timeRegister , _controlRegister , _elapsedRegister;
  late final Field _startField , _stopField , _continuousField;

  // internal variables
  bool carryOn = false;

  HardWareTimer( super.name , [super.parent] )
  {
    // create the irq port used to communicate with the outside world
    irq = SignalWritePort('irq',this);

    // get the registers from the register map
    _timeRegister = registerMap.getByName('TIMER.TIME');
    _controlRegister = registerMap.getByName('TIMER.CONTROL');
    _elapsedRegister = registerMap.getByName('TIMER.ELAPSED');

    // get the fields from the registers
    _startField = _controlRegister['START'];
    _stopField = _controlRegister['STOP'];
    _continuousField = _controlRegister['CONTINUOUS'];

    // set the callbacks used when we see an external write
    _startField.onWrite = ( data ) { controlStartWrite(); };
    _stopField.onWrite = ( data ) { controlStopWrite(); };
  }

  // the internal getters used by this model
  int get _time => _timeRegister.peek();
  int get _elapsed => _elapsedRegister.peek();
  bool get _start => _startField.peek() != 0;
  bool get _stop => _stopField.peek() != 0;
  bool get _continuous => _continuousField.peek() != 0;

  // the internal setters used by this model
  set _elapsed( int v ) => _elapsedRegister.poke( v );
  set _start( bool b ) => _startField.poke( b ? 1 : 0 );
  set _stop( bool b ) => _stopField.poke( b ? 1 : 0 );

  // This future is called when we see a CONTROL.START
  //
  // It awaits timerLoop() at least once, and will carry on doing so
  // if it is a continuous loop, the clock has not expired, and the start
  // field is still true
  Future<void> controlStartWrite() async {
    _elapsed = 0;
    _stop = false;

    bool wasContinuousAtBeginning = _continuous;

    for( bool carryOn = await timerLoop();
         wasContinuousAtBeginning && carryOn && _start;
         carryOn = await timerLoop() ) {}
  }

  // The core timer loop.
  //
  // It awaits _time clocks and if the clock has not been cancelled and the
  // timer has not been stopped, it creates a delta cycle glitch on the irq
  Future<bool> timerLoop() async
  {
    await clockDelay( _time );

    if( _stop ) {
      return false;
    }

    _elapsed++;

    await irq.nba( 1 );
    await irq.nba( 0 );

    return true;
  }

  // called when we see a write to CONTROL.STOP
  void controlStopWrite() {
    _stop = true;
    _start = false;
  }
}
