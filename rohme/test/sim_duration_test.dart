import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

void main()
{
  group('Sim Duration Test', () {
    test('Sim Duration test', () {
      final onePicoSecond = const SimDuration( picoseconds : 1 );
      final oneNanoSecond = const SimDuration( nanoseconds : 1 );
      final oneMicroSecond = const SimDuration( microseconds : 1 );
      final twoPicoSeconds = const SimDuration( picoseconds : 2 );
      final twoNanoSeconds = const SimDuration( nanoseconds : 2 );

      expect( twoPicoSeconds , greaterThan( onePicoSecond ) );
      expect( onePicoSecond * 2 , equals( twoPicoSeconds ) );

      expect( oneMicroSecond * .002 , equals( twoNanoSeconds ) );

      final str = '${onePicoSecond + oneNanoSecond + oneMicroSecond}';
      print( str );
      expect( str , equals('0:00:00.000001.001001') );
    });
    test('Sim Duration test', () {
      final d = Duration( microseconds : 1 );
      final onePicoSecond = const SimDuration( picoseconds : 1 );
      final same = SimDuration( microseconds : 1 );
      final less = same - onePicoSecond;
      final more = same + onePicoSecond;

      print('${d} ${less} ${same} ${more}');

      print('same test');
      compare( d , same , 0 ,
               [true,true,true,false,false] ,
               [true,true,true,false,false] );

      print('more test');
      compare( d , more , 1 ,
              [true,false,true,false,true] ,
              [false,true,false,true,false] );

      print('less test');
      compare( d , less , -1 ,
              [false,true,false,true,false] ,
              [false,false,true,false,true] );

    });
  });
  test('Constructor Test', () {
    final onePicoSecond = const SimDuration( picoseconds : 1 );
    final oneNanoSecond = const SimDuration( nanoseconds : 1 );
    final oneMicroSecond = const SimDuration( microseconds : 1 );
    final oneMilliSecond = const SimDuration( milliseconds : 1 );
    final oneSecond = const SimDuration( seconds : 1 );
    final oneMinute = const SimDuration( minutes : 1 );
    final oneHour = const SimDuration( hours : 1 );
    final oneDay = const SimDuration( days : 1 );

    print('oneMilliSecond ${oneMilliSecond}');

    expect( oneNanoSecond , onePicoSecond * 1000 );
    expect( oneMicroSecond , onePicoSecond * 1000 * 1000 );
    expect( oneMilliSecond , onePicoSecond * 1000 * 1000 * 1000 );
    expect( oneSecond , onePicoSecond * 1000 * 1000 * 1000 * 1000 );
    expect( oneMinute , onePicoSecond * 1000 * 1000 * 1000 * 1000 * 60 );
    expect( oneHour , onePicoSecond * 1000 * 1000 * 1000 * 1000 * 60 * 60 );
    expect( oneDay , onePicoSecond * 1000 * 1000 * 1000 * 1000 * 60 * 60 * 24 );

  });

}

void compare( Duration d , SimDuration simD , int comparison , List<bool> durationToSim , List<bool> simToDuration )
{
  expect( simD.compareTo( d ) , comparison );

  print('comparing Duration $d to SimDuration $simD using $durationToSim');
  expect( d == simD , durationToSim[0] );
  expect( SimDuration.fromDuration( d ) >= simD , durationToSim[1] );
  expect( SimDuration.fromDuration( d ) <= simD , durationToSim[2] );
  expect( SimDuration.fromDuration( d ) > simD , durationToSim[3] );
  expect( SimDuration.fromDuration( d ) < simD , durationToSim[4] );

  print('comparing SimDuration $simD to Duration $d using $simToDuration');
  expect( simD == d , simToDuration[0] );
  expect( simD >= d , simToDuration[1] );
  expect( simD <= d , simToDuration[2] );
  expect( simD > d , simToDuration[3] );
  expect( simD < d , simToDuration[4] );
}
