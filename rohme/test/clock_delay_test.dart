
import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

import 'dart:async';


void main() async {
  group('A group of tests', () {
    setUp(() {
    });

    test('clock test', () async {
      Simulator simulator = Simulator( clockPeriod : SimDuration( picoseconds : 10 ) );

      simulator.run( (async) async {
        await clockDelay( 2 );
        print('elapsed time is ${simulator.elapsed}');
        print('${simulator.elapsedTicks} clock ticks have elapsed');

        expect( simulator.elapsed , simulator.clockPeriod * 2 );
      });

      simulator.elapse( SimDuration( picoseconds : 1000 ) );
    });
  });
}
