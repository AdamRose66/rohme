/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:rohme/rohme.dart';
import '../hardware_timer.dart';

class RohmeHardWareTimer extends HardWareTimer {
  RohmeHardWareTimer(super.name, super.parent, super.clockDivider) {
    // set the callbacks used when we see an external write
    startField.onWrite = (data) {
      controlStartWrite();
    };
    stopField.onWrite = (data) {
      controlStopWrite();
    };
  }

  // the internal getters used by this model
  int get time => timeRegister.peek();
  int get elapsed => elapsedRegister.peek();
  bool get start => startField.peek() != 0;
  bool get stop => stopField.peek() != 0;
  bool get continuous => continuousField.peek() != 0;

  // the internal setters used by this model
  set elapsed(int v) => elapsedRegister.poke(v);
  set start(bool b) => startField.poke(b ? 1 : 0);
  set stop(bool b) => stopField.poke(b ? 1 : 0);

  // This future is called when we see a CONTROL.START
  //
  // It awaits timerLoop() at least once, and will carry on doing so
  // if it is a continuous loop, the clock has not expired, and the start
  // field is still true
  Future<void> controlStartWrite() async {
    elapsed = 0;
    stop = false;

    bool wasContinuousAtBeginning = continuous;

    for (bool carryOn = await timerLoop();
        wasContinuousAtBeginning && carryOn && start;
        carryOn = await timerLoop()) {}
  }

  // The core timer loop.
  //
  // It awaits time clocks and if the clock has not been cancelled and the
  // timer has not been stopped, it creates a delta cycle glitch on the irq
  Future<bool> timerLoop() async {
    await clockDelay(time * clockDivider);

    if (stop) {
      return false;
    }

    elapsed++;

    await irq.nba(1);
    await irq.nba(0);

    return true;
  }

  // called when we see a write to CONTROL.STOP
  void controlStopWrite() {
    stop = true;
    start = false;
  }
}
