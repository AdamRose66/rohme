import 'dart:async';

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

int anyCount = 0;
int posCount = 0;
int negCount = 0;
int valCount = 0;
int alwaysCount = 0;

Future<void> monitorAny(Signal s) async {
  while (true) {
    await s.changed();
    print('monitorAny seen change on s : now ${s.currentValue}');
    anyCount++;
  }
}

Future<void> monitorPos(Signal s) async {
  while (true) {
    await s.changed(posEdge);
    print('monitorPos seen rising edge on s : now ${s.currentValue}');
    posCount++;
  }
}

Future<void> monitorNeg(Signal s) async {
  while (true) {
    await s.changed(negEdge);
    print('monitorNeg seen falling edge on s : now ${s.currentValue}');
    negCount++;
  }
}

Future<void> monitorVal(Signal s, int n) async {
  while (true) {
    await s.changed((s) {
      return s.currentValue == n;
    });
    print('monitorVal seen ${s.currentValue} on s');
    valCount++;
  }
}

void main() {
  group('Signal Tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('signal test 1', () async {
      const iterations = 5;
      Signal s = Signal();

      s.alwaysAt((s) {
        print('observed s change ${s.currentValue}');
        alwaysCount++;
      });

      monitorAny(s);
      monitorPos(s);
      monitorNeg(s);
      monitorVal(s, 4);

      for (int i = 0; i < iterations; i++) {
        print('old value ${s.currentValue}');
        s.nba(s.currentValue + 1);
        print('mid value ${s.currentValue}');
        await Future.delayed(SimDuration.zero);
      }
      s.nba(0);
      await Future.delayed(SimDuration.zero);

      expect(anyCount, equals(iterations + 1));
      expect(posCount, equals(1));
      expect(negCount, equals(1));
      expect(valCount, equals(1));
      expect(alwaysCount, equals(iterations + 1));
    });

    test('repeated NBA', () async {
      bool fired = false;

      runZonedGuarded(() async {
        Signal s = Signal();

        s.nba(2);
        s.nba(2);
        s.nba(3);
      }, (error, stackTrace) {
        print('Seen expected error: $error');
        fired = true;
      });

      await Future.delayed(SimDuration.zero);
      expect(fired, true);
    });

    test('same value NBA OK', () async {
      Signal s = Signal();

      s.nba(4);
      s.nba(4);
      await Future.delayed(SimDuration.zero);
      s.nba(5);

      expect(s.currentValue, 4);
      await Future.delayed(SimDuration.zero);
      expect(s.currentValue, 5);
    });

    test('signal port test', () async {
      Signal s = Signal();

      SignalReadPort signalReadPort = SignalReadPort('readPort', null);
      SignalWritePort signalWritePort = SignalWritePort('writePort', null);

      signalWritePort.implementedBy(s);
      signalReadPort.implementedBy(s);

      SignalReadIf readIf = signalReadPort;
      SignalWriteIf writeIf = signalWritePort;

      writeIf.nba(4);
      await Future.delayed(SimDuration.zero);
      expect(readIf.currentValue, 4);
    });
  });
}
