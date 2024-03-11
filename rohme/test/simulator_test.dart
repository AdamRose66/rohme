/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
import 'dart:async';
import 'package:rohme/rohme.dart';

import 'package:test/test.dart';

void main() {
  tearDown(() async {
    Simulator.resetRohdSim();
  });

  test('scheduler posts event in future', () async {
    bool timerExpired = false;
    Simulator simulator = Simulator(clockPeriod: SimDuration(picoseconds: 10));

    simulator.run((simulator) async {
      Future.delayed(tickTime(5), () {
        expect(simulator.elapsed, SimDuration(picoseconds: 50));
        timerExpired = true;
      });
    });

    await simulator.elapse(SimDuration(picoseconds: 1000));

    expect(timerExpired, true);
    expect(simulator.elapsed, SimDuration(picoseconds: 50));
  });

  test('microtask between deltas', () async {
    Simulator simulator = Simulator(clockPeriod: SimDuration(picoseconds: 10));
    List<String> log = [];

    simulator.run((simulator) {
      Future.delayed(tickTime(5), () {
        log.add('timer');

        Future.delayed(SimDuration.zero, () {
          log.add('delta 1');
        });

        Future.delayed(SimDuration.zero, () {
          log.add('delta 2');
        });

        scheduleMicrotask(() {
          log.add('microtask 1');
        });

        scheduleMicrotask(() {
          log.add('microtask 2');
        });
      });
    });

    await simulator.elapse(SimDuration(picoseconds: 1000));
    expect(log, ['timer', 'microtask 1', 'microtask 2', 'delta 1', 'delta 2']);
  });

  test('cancel non-periodic', () async {
    Simulator simulator = Simulator(clockPeriod: SimDuration(picoseconds: 10));

    bool done5 = false;
    bool done10 = false;

    simulator.run((simulator) {
      late Timer t10;
      Timer(tickTime(5), () {
        done5 = true;
        t10.cancel();
      });
      t10 = Timer(tickTime(10), () {
        done10 = true;
      });
    });

    await simulator.elapse(SimDuration(picoseconds: 1000));

    expect(done5, true);
    expect(done10, false);
  });

  test('periodic self cancel', () async {
    Simulator simulator = Simulator(clockPeriod: SimDuration(picoseconds: 10));

    int wakeUpCount = 0;
    late Timer timer;

    simulator.run((simulator) {
      timer = Timer.periodic(tickTime(5), (timer) {
        wakeUpCount++;
        expect(timer.isActive, true);
        if (timer.tick == 1) timer.cancel();
      });
    });

    await simulator.elapse(SimDuration(picoseconds: 1000));

    expect(timer.isActive, false);
    expect(timer.tick, 2);
    expect(wakeUpCount, 2);
  });

  test('periodic external cancel', () async {
    Simulator simulator = Simulator(clockPeriod: SimDuration(picoseconds: 10));

    int wakeUpCount = 0;
    late Timer timer;

    simulator.run((simulator) {
      timer = Timer.periodic(tickTime(5), (timer) {
        wakeUpCount++;
      });

      Future.delayed(tickTime(8), () => timer.cancel());
    });

    await simulator.elapse(SimDuration(picoseconds: 1000));
    expect(wakeUpCount, 1);
  });

  test('periodic cancel resume', () async {
    Simulator simulator = Simulator(clockPeriod: SimDuration(picoseconds: 10));

    List<int> wakeUpTicks = [];
    late Timer timer;

    simulator.run((simulator) {
      timer = Timer.periodic(
          tickTime(10), (timer) => wakeUpTicks.add(simulator.elapsedTicks));

      Future.delayed(tickTime(18), () => timer.cancel());
      Future.delayed(tickTime(38), () {
        SimTimer simTimer = timer as SimTimer;

        simTimer.reschedule(tickTime(20));
        simTimer.resume();
      });
    });

    await simulator.elapse(SimDuration(picoseconds: 1000));
    expect(wakeUpTicks, [10, 40, 50, 60, 70, 80, 90, 100]);
  });
}
