/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:rohd/rohd.dart';
import '../hardware_timer.dart';

import 'rohd_timer.dart';

/// This is a Rohme wrapper around the underlying Rohd [Timer] implementation.
///
/// It has the [Logic] signals needed to communicate with the underlying
/// implementation, appropriate read/write callback methods and a [run] method
/// to do basic initialisation and bring the Timer out of reset.
class RohdHardWareTimer extends HardWareTimer {
  // the wrapper for the underlying Rohm timer
  late final Timer _timer;

  // the Logic signals needed to drive the RohdTimer
  late final Logic _clkLogic;
  final _resetLogic = Logic(name: 'reset');
  final _startLogic = Logic(name: 'start');
  final _continuousLogic = Logic(name: 'continuous');
  final _stopLogic = Logic(name: 'stop');
  final _saturationLogic = Logic(name: 'saturation', width: 8);

  RohdHardWareTimer(super.name, super.parent, super.clockDivider) {
    // create the Rohd clock
    _clkLogic = SimpleClockGenerator(clockDivider).clk;

    // create the Rohd timer
    _timer = Timer(
        clk: _clkLogic,
        reset: _resetLogic,
        start: _startLogic,
        continuous: _continuousLogic,
        stop: _stopLogic,
        saturation: _saturationLogic);

    // set the callbacks used when we see an external write
    startField.onWrite = (data) => _startLogic.inject(data);
    stopField.onWrite = (data) => _stopLogic.inject(data);
    continuousField.onWrite = (data) => _continuousLogic.inject(data);
    timeRegister.onWrite = (data) => _saturationLogic.inject(data);

    _timer.interrupt.posedge.listen((e) => irq.nba(1));
    _timer.interrupt.negedge.listen((e) => irq.nba(0));

    // update values for reading
    _timer.elapsed.changed
        .listen((e) => elapsedRegister.poke(e.newValue.toInt()));
  }

  @override
  void run() async {
    await _timer.build();
    mPrint('going into reset');

    _resetLogic.inject(1);
    _startLogic.inject(0);
    _stopLogic.inject(0);
    _continuousLogic.inject(0);
    _saturationLogic.inject(0);

    await _clkLogic.nextPosedge;
    mPrint('coming out of reset');
    _resetLogic.put(0);
  }
}
