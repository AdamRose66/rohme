import '../example/memory_map_test.dart';

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

void main()
{
  group('A group of tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('memory map test', () async {
      simulateModel( () { return Top('top'); } );
    });
  });
}
