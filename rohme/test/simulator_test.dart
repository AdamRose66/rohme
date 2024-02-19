// Copyright 2014 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Copyright 2024 Adam Rose
//
// Modified to use [Simulator] and [SimDuration] instead of [fakeAsync]
// and [Duration], for modelling digital hardware systems
//
// Changes are made under the BDS-3 license

import 'dart:async';
import 'package:rohme/rohme.dart';

import 'package:test/test.dart';

void main() {
  //final initialTime = DateTime(2000);
  final elapseBy = const SimDuration(days: 1);
/*
  test('should set initial time', () {
    expect(Simulator().getClock(initialTime).now(), initialTime);
  });
*/
  group('elapseBlocking', () {
    test('should elapse time without calling timers', () {
      Timer(elapseBy ~/ 2, neverCalled);
      Simulator().elapseBlocking(elapseBy);
    });

    test('should elapse time by the specified amount', () {
      final async = Simulator()..elapseBlocking(elapseBy);
      expect(async.elapsed, elapseBy);
    });

    test('should throw when called with a negative SimDuration', () {
      expect(() => Simulator().elapseBlocking(const SimDuration(days: -1)),
          throwsArgumentError);
    });
  });

  group('elapse', () {
    test('should elapse time by the specified amount', () {
      Simulator().run((async) {
        async.elapse(elapseBy);
        expect(async.elapsed, elapseBy);
      });
    });

    test('should throw ArgumentError when called with a negative SimDuration',
        () {
      expect(() => Simulator().elapse(const SimDuration(days: -1)),
          throwsArgumentError);
    });

    test('should throw when called before previous call is complete', () {
      Simulator().run((async) {
        Timer(elapseBy ~/ 2, expectAsync0(() {
          expect(() => async.elapse(elapseBy), throwsStateError);
        }));
        async.elapse(elapseBy);
      });
    });

    group('when creating timers', () {
      test('should call timers expiring before or at end time', () {
        Simulator().run((async) {
          Timer(elapseBy ~/ 2, expectAsync0(() {}));
          Timer(elapseBy, expectAsync0(() {}));
          async.elapse(elapseBy);
        });
      });

      test('should call timers expiring due to elapseBlocking', () {
        Simulator().run((async) {
          Timer(elapseBy, () => async.elapseBlocking(elapseBy));
          Timer(elapseBy * 2, expectAsync0(() {}));
          async.elapse(elapseBy);
          expect(async.elapsed, elapseBy * 2);
        });
      });

      test('should call timers at their scheduled time', () {
        Simulator().run((async) {
          Timer(elapseBy ~/ 2, expectAsync0(() {
            expect(async.elapsed, elapseBy ~/ 2);
          }));

          final periodicCalledAt = <SimDuration>[];
          Timer.periodic(
              elapseBy ~/ 2, (_) => periodicCalledAt.add(async.elapsed));

          async.elapse(elapseBy);
          expect(periodicCalledAt, [elapseBy ~/ 2, elapseBy]);
        });
      });

      test('should not call timers expiring after end time', () {
        Simulator().run((async) {
          Timer(elapseBy * 2, neverCalled);
          async.elapse(elapseBy);
        });
      });

      test('should not call canceled timers', () {
        Simulator().run((async) {
          Timer(elapseBy ~/ 2, neverCalled).cancel();
          async.elapse(elapseBy);
        });
      });

      test('should call periodic timers each time the SimDuration elapses', () {
        Simulator().run((async) {
          Timer.periodic(elapseBy ~/ 10, expectAsync1((_) {}, count: 10));
          async.elapse(elapseBy);
        });
      });

      test('should call timers occurring at the same time in FIFO order', () {
        Simulator().run((async) {
          final log = [];
          Timer(elapseBy ~/ 2, () => log.add('1'));
          Timer(elapseBy ~/ 2, () => log.add('2'));
          async.elapse(elapseBy);
          expect(log, ['1', '2']);
        });
      });
/*
      test('should maintain FIFO order even with periodic timers', () {
        Simulator().run((async) {
          final log = [];
          Timer.periodic(elapseBy ~/ 2, (_) => log.add('periodic 1'));
          Timer(elapseBy ~/ 2, () => log.add('delayed 1'));
          Timer(elapseBy, () => log.add('delayed 2'));
          Timer.periodic(elapseBy, (_) => log.add('periodic 2'));

          async.elapse(elapseBy);
          expect(log, [
            'periodic 1',
            'delayed 1',
            'periodic 1',
            'delayed 2',
            'periodic 2'
          ]);
        });
      });
*/
      test('should process microtasks surrounding each timer', () {
        Simulator().run((async) {
          var microtaskCalls = 0;
          var timerCalls = 0;
          void scheduleMicrotasks() {
            for (var i = 0; i < 5; i++) {
              scheduleMicrotask(() => microtaskCalls++);
            }
          }

          scheduleMicrotasks();
          Timer.periodic(elapseBy ~/ 5, (_) {
            timerCalls++;
            expect(microtaskCalls, 5 * timerCalls);
            scheduleMicrotasks();
          });
          async.elapse(elapseBy);
          expect(timerCalls, 5);
          expect(microtaskCalls, 5 * (timerCalls + 1));
        });
      });

      test('should pass the periodic timer itself to callbacks', () {
        Simulator().run((async) {
          late Timer constructed;
          constructed = Timer.periodic(elapseBy, expectAsync1((passed) {
            expect(passed, same(constructed));
          }));
          async.elapse(elapseBy);
        });
      });

      test('should call microtasks before advancing time', () {
        Simulator().run((async) {
          scheduleMicrotask(expectAsync0(() {
            expect(async.elapsed, SimDuration.zero);
          }));
          async.elapse(const SimDuration(minutes: 1));
        });
      });

      test('should add event before advancing time', () {
        Simulator().run((async) {
          final controller = StreamController();
          expect(controller.stream.first.then((_) {
            expect(async.elapsed, SimDuration.zero);
          }), completes);
          controller.add(null);
          async.elapse(const SimDuration(minutes: 1));
        });
      });

      test('should increase negative SimDuration timers to zero SimDuration',
          () {
        Simulator().run((async) {
          final negativeSimDuration = const SimDuration(days: -1);
          Timer(negativeSimDuration, expectAsync0(() {
            expect(async.elapsed, SimDuration.zero);
          }));
          async.elapse(const SimDuration(minutes: 1));
        });
      });

      test('should not be additive with elapseBlocking', () {
        Simulator().run((async) {
          Timer(SimDuration.zero, () => async.elapseBlocking(elapseBy * 5));
          async.elapse(elapseBy);
          expect(async.elapsed, elapseBy * 5);
        });
      });

      group('isActive', () {
        test('should be false after timer is run', () {
          Simulator().run((async) {
            final timer = Timer(elapseBy ~/ 2, () {});
            async.elapse(elapseBy);
            expect(timer.isActive, isFalse);
          });
        });

        test('should be true after periodic timer is run', () {
          Simulator().run((async) {
            final timer = Timer.periodic(elapseBy ~/ 2, (_) {});
            async.elapse(elapseBy);
            expect(timer.isActive, isTrue);
          });
        });

        test('should be false after timer is canceled', () {
          Simulator().run((async) {
            final timer = Timer(elapseBy ~/ 2, () {})..cancel();
            expect(timer.isActive, isFalse);
          });
        });
      });

      test('should work with new Future()', () {
        Simulator().run((async) {
          Future(expectAsync0(() {}));
          async.elapse(SimDuration.zero);
        });
      });

      test('should work with Future.delayed', () {
        Simulator().run((async) {
          Future.delayed(elapseBy, expectAsync0(() {}));
          async.elapse(elapseBy);
        });
      });

      test('should work with Future.timeout', () {
        Simulator().run((async) {
          final completer = Completer();
          expect(completer.future.timeout(elapseBy ~/ 2),
              throwsA(const TypeMatcher<TimeoutException>()));
          async.elapse(elapseBy);
          completer.complete();
        });
      });

      // TODO: Pausing and resuming the timeout Stream doesn't work since
      // it uses `new Stopwatch()`.
      //
      // See https://code.google.com/p/dart/issues/detail?id=18149
      test('should work with Stream.periodic', () {
        Simulator().run((async) {
          expect(Stream.periodic(const SimDuration(minutes: 1), (i) => i),
              emitsInOrder([0, 1, 2]));
          async.elapse(const SimDuration(minutes: 3));
        });
      });

      test('should work with Stream.timeout', () {
        Simulator().run((async) {
          final controller = StreamController<int>();
          final timed =
              controller.stream.timeout(const SimDuration(minutes: 2));

          final events = <int>[];
          final errors = [];
          timed.listen(events.add, onError: errors.add);

          controller.add(0);
          async.elapse(const SimDuration(minutes: 1));
          expect(events, [0]);

          async.elapse(const SimDuration(minutes: 1));
          expect(errors, hasLength(1));
          expect(errors.first, const TypeMatcher<TimeoutException>());
        });
      });
    });
  });

  group('flushMicrotasks', () {
    test('should flush a microtask', () {
      Simulator().run((async) {
        Future.microtask(expectAsync0(() {}));
        async.flushMicrotasks();
      });
    });

    test('should flush microtasks scheduled by microtasks in order', () {
      Simulator().run((async) {
        final log = [];
        scheduleMicrotask(() {
          log.add(1);
          scheduleMicrotask(() => log.add(3));
        });
        scheduleMicrotask(() => log.add(2));

        async.flushMicrotasks();
        expect(log, [1, 2, 3]);
      });
    });

    test('should not run timers', () {
      Simulator().run((async) {
        final log = [];
        scheduleMicrotask(() => log.add(1));
        Timer.run(() => log.add(2));
        Timer.periodic(const SimDuration(seconds: 1), (_) => log.add(2));

        async.flushMicrotasks();
        expect(log, [1]);
      });
    });
  });

  group('flushTimers', () {
    test('should flush timers in FIFO order', () {
      Simulator().run((async) {
        final log = [];
        Timer.run(() {
          log.add(1);
          Timer(elapseBy, () => log.add(3));
        });
        Timer.run(() => log.add(2));

        async.flushTimers(timeout: elapseBy * 2);
        expect(log, [1, 2, 3]);
        expect(async.elapsed, elapseBy);
      });
    });
/*
    test(
        'should run collateral periodic timers with non-periodic first if '
        'scheduled first', () {
      Simulator().run((async) {
        final log = [];
        Timer(const SimDuration(seconds: 2), () => log.add('delayed'));
        Timer.periodic(
            const SimDuration(seconds: 1), (_) => log.add('periodic'));

        async.flushTimers(flushPeriodicTimers: false);
        expect(log, ['periodic', 'delayed', 'periodic']);
      });
    });

    test(
        'should run collateral periodic timers with periodic first '
        'if scheduled first', () {
      Simulator().run((async) {
        final log = [];
        Timer.periodic(
            const SimDuration(seconds: 1), (_) => log.add('periodic'));
        Timer(const SimDuration(seconds: 2), () => log.add('delayed'));

        async.flushTimers(flushPeriodicTimers: false);
        expect(log, ['periodic', 'periodic', 'delayed']);
      });
    });
*/
    test('should time out', () {
      Simulator().run((async) {
        // Schedule 3 timers. All but the last one should fire.
        for (var delay in [30, 60, 90]) {
          Timer(SimDuration(minutes: delay),
              expectAsync0(() {}, count: delay == 90 ? 0 : 1));
        }

        expect(() => async.flushTimers(), throwsStateError);
      });
    });

    test('should time out a chain of timers', () {
      Simulator().run((async) {
        var count = 0;
        void createTimer() {
          Timer(const SimDuration(minutes: 30), () {
            count++;
            createTimer();
          });
        }

        createTimer();
        expect(() => async.flushTimers(timeout: const SimDuration(hours: 2)),
            throwsStateError);
        expect(count, 4);
      });
    });

    test('should time out periodic timers', () {
      Simulator().run((async) {
        Timer.periodic(
            const SimDuration(minutes: 30), expectAsync1((_) {}, count: 2));
        expect(() => async.flushTimers(timeout: const SimDuration(hours: 1)),
            throwsStateError);
      });
    });

    test('should flush periodic timers', () {
      Simulator().run((async) {
        var count = 0;
        Timer.periodic(const SimDuration(minutes: 30), (timer) {
          if (count == 3) timer.cancel();
          count++;
        });
        async.flushTimers(timeout: const SimDuration(hours: 20));
        expect(count, 4);
      });
    });

    test('should compute absolute timeout as elapsed + timeout', () {
      Simulator().run((async) {
        var count = 0;
        void createTimer() {
          Timer(const SimDuration(minutes: 30), () {
            count++;
            if (count < 4) createTimer();
          });
        }

        createTimer();
        async
          ..elapse(const SimDuration(hours: 1))
          ..flushTimers(timeout: const SimDuration(hours: 1));
        expect(count, 4);
      });
    });
  });

  group('stats', () {
    test('should report the number of pending microtasks', () {
      Simulator().run((async) {
        expect(async.microtaskCount, 0);
        scheduleMicrotask(() {});
        expect(async.microtaskCount, 1);
        scheduleMicrotask(() {});
        expect(async.microtaskCount, 2);
        async.flushMicrotasks();
        expect(async.microtaskCount, 0);
      });
    });

    test('it should report the number of pending periodic timers', () {
      Simulator().run((async) {
        expect(async.periodicTimerCount, 0);
        final timer = Timer.periodic(const SimDuration(minutes: 30), (_) {});
        expect(async.periodicTimerCount, 1);
        Timer.periodic(const SimDuration(minutes: 20), (_) {});
        expect(async.periodicTimerCount, 2);
        async.elapse(const SimDuration(minutes: 20));
        expect(async.periodicTimerCount, 2);
        timer.cancel();
        expect(async.periodicTimerCount, 1);
      });
    });

    test('it should report the number of pending non periodic timers', () {
      Simulator().run((async) {
        expect(async.nonPeriodicTimerCount, 0);
        final timer = Timer(const SimDuration(minutes: 30), () {});
        expect(async.nonPeriodicTimerCount, 1);
        Timer(const SimDuration(minutes: 20), () {});
        expect(async.nonPeriodicTimerCount, 2);
        async.elapse(const SimDuration(minutes: 25));
        expect(async.nonPeriodicTimerCount, 1);
        timer.cancel();
        expect(async.nonPeriodicTimerCount, 0);
      });
    });

    test('should report debugging information of pending timers', () {
      Simulator().run((simulator) {
        expect(simulator.pendingTimers, isEmpty);
        final nonPeriodic =
            Timer(const SimDuration(seconds: 1), () {}) as SimTimer;
        final periodic =
            Timer.periodic(const SimDuration(seconds: 2), (Timer timer) {})
                as SimTimer;
        final debugInfo = simulator.pendingTimers;
        expect(debugInfo.length, 2);
        expect(
          debugInfo,
          containsAll([
            nonPeriodic,
            periodic,
          ]),
        );

        const thisFileName = 'simulator_test.dart';
        expect(nonPeriodic.debugString, contains(':01.000000'));
        expect(nonPeriodic.debugString, contains('periodic: false'));
        expect(nonPeriodic.debugString, contains(thisFileName));
        expect(periodic.debugString, contains(':02.0'));
        expect(periodic.debugString, contains('periodic: true'));
        expect(periodic.debugString, contains(thisFileName));
      });
    });

    test(
        'should report debugging information of pending timers excluding '
        'stack traces', () {
      Simulator(includeTimerStackTrace: false).run((simulator) {
        expect(simulator.pendingTimers, isEmpty);
        final nonPeriodic =
            Timer(const SimDuration(seconds: 1), () {}) as SimTimer;
        final periodic =
            Timer.periodic(const SimDuration(seconds: 2), (Timer timer) {})
                as SimTimer;
        final debugInfo = simulator.pendingTimers;
        expect(debugInfo.length, 2);
        expect(
          debugInfo,
          containsAll([
            nonPeriodic,
            periodic,
          ]),
        );

        const thisFileName = 'simulator_test.dart';
        expect(nonPeriodic.debugString, contains(':01.0'));
        expect(nonPeriodic.debugString, contains('periodic: false'));
        expect(nonPeriodic.debugString, isNot(contains(thisFileName)));
        expect(periodic.debugString, contains(':02.0'));
        expect(periodic.debugString, contains('periodic: true'));
        expect(periodic.debugString, isNot(contains(thisFileName)));
      });
    });
  });

  group('timers', () {
    test("should become inactive as soon as they're invoked", () {
      return Simulator().run((async) {
        late Timer timer;
        timer = Timer(elapseBy, expectAsync0(() {
          expect(timer.isActive, isFalse);
        }));

        expect(timer.isActive, isTrue);
        async.elapse(elapseBy);
        expect(timer.isActive, isFalse);
      });
    });

    test('should increment tick in a non-periodic timer', () {
      return Simulator().run((async) {
        late Timer timer;
        timer = Timer(elapseBy, expectAsync0(() {
          expect(timer.tick, 1);
        }));

        expect(timer.tick, 0);
        async.elapse(elapseBy);
      });
    });

    test('should increment tick in a periodic timer', () {
      return Simulator().run((async) {
        final ticks = [];
        Timer.periodic(
            elapseBy,
            expectAsync1((timer) {
              ticks.add(timer.tick);
            }, count: 2));
        async
          ..elapse(elapseBy)
          ..elapse(elapseBy);
        expect(ticks, [1, 2]);
      });
    });
  });
/*
  group('clock', () {
    test('updates following elapse()', () {
      Simulator().run((async) {
        final before = clock.now();
        async.elapse(elapseBy);
        expect(clock.now(), before.add(elapseBy));
      });
    });

    test('updates following elapseBlocking()', () {
      Simulator().run((async) {
        final before = clock.now();
        async.elapseBlocking(elapseBy);
        expect(clock.now(), before.add(elapseBy));
      });
    });

    group('starts at', () {
      test('the time at which the Simulator was created', () {
        final start = DateTime.now();
        Simulator().run((async) {
          expect(clock.now(), _closeToTime(start));
          async.elapse(elapseBy);
          expect(clock.now(), _closeToTime(start.add(elapseBy)));
        });
      });

      test('the value of clock.now()', () {
        final start = DateTime(1990, 8, 11);
        withClock(Clock.fixed(start), () {
          Simulator().run((async) {
            expect(clock.now(), start);
            async.elapse(elapseBy);
            expect(clock.now(), start.add(elapseBy));
          });
        });
      });

      test('an explicit value', () {
        final start = DateTime(1990, 8, 11);
        Simulator(initialTime: start).run((async) {
          expect(clock.now(), start);
          async.elapse(elapseBy);
          expect(clock.now(), start.add(elapseBy));
        });
      });
    });
  });
  */
}

/*
/// Returns a matcher that asserts that a [DateTime] is within 100ms of
/// [expected].
Matcher _closeToTime(DateTime expected) => predicate(
    (actual) =>
        expected.difference(actual as DateTime).inMilliseconds.abs() < 100,
    'is close to $expected');
*/
