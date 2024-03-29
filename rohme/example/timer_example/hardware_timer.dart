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

/// An abstract base class for the Rohd and Rohme Hardware timers.
///
/// This class defines the registers and signals needed by a HardWareTimer to
/// interact with the external Rohme environment.
abstract class HardWareTimer extends Module {
  // external connections
  late final SignalWritePort irq;

  // internal fields and registers
  late final Register timeRegister, controlRegister, elapsedRegister;
  late final Field startField, stopField, continuousField;

  // the number of system clocks per timer clock
  final int clockDivider;

  HardWareTimer(super.name, super.parent, this.clockDivider) {
    // create the irq port used to communicate with the outside world
    irq = SignalWritePort('irq', this);

    // get the registers from the register map
    timeRegister = registerMap.getByName('TIMER.TIME');
    controlRegister = registerMap.getByName('TIMER.CONTROL');
    elapsedRegister = registerMap.getByName('TIMER.ELAPSED');

    // get the fields from the registers
    startField = controlRegister['START'];
    stopField = controlRegister['STOP'];
    continuousField = controlRegister['CONTINUOUS'];
  }
}
