/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

import 'dart:async';

// These tests show the difference between a [Simulator] and the native Dart
// scheduler, when it comes to the timing of microtasks.
//
// The [Simulator] 'saves up' all the microtasks until the end of the delta,
// while the native scheduler executes them between successive timers in the
// same delta.
//
// Or more precisely, the Dart scheduler has no concept of a delta so it
// schedules a microtask before the next timer, even if the next timer was
// previously scheduled to occur at the same time as the currently executing
// timer.

void main() {
  group('micro task tests', () {
    setUp(() {});

    test('simulator test - delta cycle', () async {
      Simulator simulator =
          Simulator(clockPeriod: SimDuration(picoseconds: 10));

      late MicrotaskTest microtaskTest;

      simulator.run((simulator) async {
        microtaskTest = MicrotaskTest();
        await Future.delayed(Duration(microseconds: 1));
        microtaskTest.run();
      });

      simulator.elapse(SimDuration(microseconds: 30));
      print('$microtaskTest');

      StringBuffer buffer = StringBuffer();

      buffer.writeln('wake up 1');
      buffer.writeln('wake up 2');
      buffer.writeln('microtask 1 - after');
      buffer.writeln('microtask 2 - after');

      expect(microtaskTest.buffer.toString(), buffer.toString());
    });

    test('real time test', () async {
      MicrotaskTest microtaskTest = MicrotaskTest();
      await Future.delayed(Duration(microseconds: 1));
      microtaskTest.run();
      await Future.delayed(Duration(microseconds: 30));
      print('$microtaskTest');

      StringBuffer buffer = StringBuffer();

      buffer.writeln('wake up 1');
      buffer.writeln('microtask 1 - after');
      buffer.writeln('wake up 2');
      buffer.writeln('microtask 2 - after');

      expect(microtaskTest.buffer.toString(), buffer.toString());
    });
  });
}

class MicrotaskTest {
  StringBuffer buffer = StringBuffer();

  void run() {
    Future.delayed(Duration.zero, () {
      buffer.writeln('wake up 1');
      scheduleMicrotask(() => buffer.writeln('microtask 1 - after'));
    });
    //scheduleMicrotask( () => buffer.writeln('microtask 1 - before') );

    Future.delayed(Duration.zero, () {
      buffer.writeln('wake up 2');
      scheduleMicrotask(() => buffer.writeln('microtask 2 - after'));
    });
    //scheduleMicrotask( () => buffer.writeln('microtask 2 - before') );
  }

  @override
  String toString() => buffer.toString();
}
