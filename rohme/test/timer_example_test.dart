import '../example/timer_example/timer_example.dart';
import '../example/timer_example/register_map.dart';

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('memory map test', () async {
      simulateModel(() {
        initialiseRegisterMap();
        return Top('top');
      });
    });
  });
}
