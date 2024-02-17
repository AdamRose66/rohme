import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('memory map test', () async {
      FifoModule<int> fifoModule = FifoModule('fifoModule', null);

      expect(fifoModule.canPut(), true);
      expect(fifoModule.canGet(), false);

      await fifoModule.put(2);

      expect(fifoModule.canPut(), false);
      expect(fifoModule.canGet(), true);

      int n = await fifoModule.get();

      expect(n, 2);

      expect(fifoModule.canPut(), true);
      expect(fifoModule.canGet(), false);
    });
  });
}
