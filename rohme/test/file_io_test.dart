/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINES/S INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:async';

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

Stream<String> publish(int loops, Duration delay) async* {
  for (int i = 0; i < loops; i++) {
    yield ('message $i');
    await Future.delayed(delay);
  }
}

Future<void> subscribe(Stream<String> stream) async {
  int i = 0;

  await for (String message in stream) {
    print('subscriber $i seen $message');
    i++;
  }

  print('seen $i messages');
}

void main() {
  tearDown(() => Simulator.resetRohdSim());

  test('inject file io test', () async {
    const int loops = 4;
    bool gotHere = false;

    var publisher1 = publish(loops, Duration(milliseconds: 250));
    var publisher2 = publish(loops, Duration(milliseconds: 250));

    Simulator simulator = Simulator(clockPeriod: SimDuration(picoseconds: 10));

    simulator.run((simulator) async {
      Future.delayed(tickTime(5), () async {
        expect(simulator.elapsedTicks, 5);

        await simulator.blockingMicrotask(() => subscribe(publisher1));
        await simulator.blockingMicrotask(() => subscribe(publisher2));

        gotHere = true;
        expect(simulator.elapsedTicks, 5);
      });

      Future.delayed(tickTime(10), () async {
        expect(simulator.elapsedTicks, 10);
      });
    });

    await simulator.elapse(SimDuration(picoseconds: 1000));
    expect(gotHere, true);
  });

  test('delta file io test', () async {
    const int loops = 4;
    bool gotHere = false;

    var publisher1 = publish(loops, Duration(milliseconds: 250));
    var publisher2 = publish(loops, Duration(milliseconds: 250));

    Simulator simulator = Simulator(clockPeriod: SimDuration(picoseconds: 10));

    simulator.run((simulator) async {
      Future.delayed(tickTime(5), () async {
        expect(simulator.elapsedTicks, 5);

        await simulator.blockingDelta(() => subscribe(publisher1));
        await simulator.blockingDelta(() => subscribe(publisher2));

        gotHere = true;
        expect(simulator.elapsedTicks, 5);
      });

      Future.delayed(tickTime(10), () async {
        expect(simulator.elapsedTicks, 10);
      });
    });

    await simulator.elapse(SimDuration(picoseconds: 1000));
    expect(gotHere, true);
  });
}
