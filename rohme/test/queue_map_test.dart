import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

class Dummy implements Indexable<SimDuration>
{
  int x;
  SimDuration t;

  Dummy( this.x , this.t );

  @override
  String toString() => '$x';

  @override
  SimDuration get index => t;
}

void main() {
  group('A group of tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('memory map test', () {
      QueueMap<SimDuration,Dummy> queueMap1 = QueueMap();
      QueueMap<SimDuration,Dummy> queueMap2 = QueueMap();

      queueMap1..add( Dummy( 3 , SimDuration.zero ))
               ..add( Dummy( 6 , SimDuration( picoseconds : 10 )))
               ..add( Dummy( 4 , SimDuration.zero ));

      queueMap2..add( Dummy( 7 , SimDuration( picoseconds : 10 )))
               ..add( Dummy( 5 , SimDuration.zero ))
               ..add( Dummy( 8 , SimDuration( picoseconds : 10 )));

      print('queueMap1\n$queueMap1');
      print('queueMap2\n$queueMap2');

      queueMap1.addQueueMap( queueMap2 );

      print('sum\n$queueMap1');

      print('Non destructive read loop');
      int expected = 3;
      for( Dummy d in queueMap1 )
      {
        print('just read $d');
        expect( d.x , expected++ );
      }

      expect( queueMap1.isNotEmpty , true );

      print('Destructive ( popFirst ) read loop');
      expected = 3;
      while( queueMap1.isNotEmpty )
      {
        Dummy d = queueMap1.popFirst();
        print('popped $d');
        expect( d.x , expected++ );
      }

      expect( queueMap1.isEmpty , true );

      queueMap2.removeWhere( ( d ) => ( d.x % 2) == 1 );

      print('Even only\n$queueMap2');
      expect( queueMap2.every( (d) => (d.x % 2) == 0 ) , true );
    });
    test('move test', () {
      QueueMap<SimDuration,Dummy> queueMap = QueueMap();
      Dummy d4 = Dummy( 4 , SimDuration.zero );

      queueMap..add( Dummy( 3 , SimDuration.zero ))
              ..add( Dummy( 6 , SimDuration( picoseconds : 10 )))
              ..add( d4 )
              ..add( Dummy( 7 , SimDuration( picoseconds : 10 )))
              ..add( Dummy( 5 , SimDuration.zero ))
              ..add( Dummy( 8 , SimDuration( picoseconds : 10 )));

      print('Before move 4\n$queueMap');

      d4.t = SimDuration( picoseconds : 10 );
      bool firstMoveOk = queueMap.move( SimDuration.zero , d4 );
      bool secondMoveOk = queueMap.move( SimDuration.zero , d4 );

      expect( firstMoveOk , true );
      expect( secondMoveOk , false );

      print('After move 4\n$queueMap');

      late Dummy d;
      while( queueMap.isNotEmpty )
      {
        d = queueMap.popFirst();
        print('popped $d');
      }

      expect( d.x , 4 );
    });
  });
}
