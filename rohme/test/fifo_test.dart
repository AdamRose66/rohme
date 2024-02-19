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

void runFifoTest(SimDuration duration, int size) {
  simulator.run((async) {
    fifoTest(duration, size);
  });
  simulator.elapse(SimDuration(seconds: 1));
  print('finished test at ${simulator.elapsed}');
}

void fifoTest(SimDuration duration, int size) async {
  print('starting fifoTest $duration');

  final int n = 4;

  Fifo<int> fifo = Fifo('fifo', duration: duration, size: size);

  producer('producer', n, fifo);
  consumer('consumer', n, fifo);
}

Future<void> producer(String name, int n, Fifo<int> fifo) async {
  for (int i = 0; i < n; i++) {
    print('  $name just about to put $i at ${simulator.elapsed}');
    await fifo.put(i);
    print('  $name just done put $i at ${simulator.elapsed}');
  }
}

Future<void> consumer(String name, int n, Fifo<int> fifo) async {
  for (int i = 0; i < n; i++) {
    print('  $name just about to get at ${simulator.elapsed}');
    int v = await fifo.get();
    print('  $name just done get $v at ${simulator.elapsed}');

    expect(i, equals(v));
  }
}

void main() async {
  group('A group of tests', () {
    bool beenHere = false;
    setUp(() {
      if (!beenHere) {
        simulateModel(() {
          return Module('top');
        });
      }
      beenHere = true;
    });

    test('Fifo Test', () async {
      runFifoTest(SimDuration.zero, 1);
      runFifoTest(SimDuration(microseconds: 10), 1);

      runFifoTest(SimDuration.zero, 2);
      runFifoTest(SimDuration(microseconds: 10), 2);
    });

    test('Fifo Size Test', () {
      bool ok = true;
      try {
        Fifo('f', size: 0);
      } on FifoSizeError catch (e) {
        print('expected error $e');
        ok = false;
      }
      expect(ok, false);
    });
  });
}
