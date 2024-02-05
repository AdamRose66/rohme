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

void runClockTest()
{
  print('starting clock test');

  Map<int,Duration> occurredAt = {};

  simulator.run( (async) { clockTest( occurredAt ); });
  simulator.elapse( Duration( seconds: 1 ) );
  print('finished sim at ${simulator.elapsed}');

  print('occurredAt $occurredAt');

  expect( occurredAt , equals( {
    0: Duration( microseconds: 0 ) ,
    1: Duration( microseconds: 10 ),
    2: Duration( microseconds: 110 ),
    3: Duration( microseconds: 140 )
  } ) );

}

void main() async {
  group('A group of tests', () {
    setUp(() {
    });

    test('clock test', () async {
      runClockTest();
    });
  });
}

Future<void> clockTest( Map<int,Duration> occurredAt ) async
{
  SimClock clock = SimClock( Duration( microseconds : 10 ) );
  clock.start();

  f( clock , [1,2,3,4,4,4,4,4] , occurredAt );

  await clock.delay( 2 );
  print( '${simulator.elapsed} : STOP');
  clock.stop();

  await Future.delayed( clock.clockPeriod * 8 );
  print( '${simulator.elapsed} : START');
  clock.start();

  await Future.delayed( clock.clockPeriod * 8 );
  print( '${simulator.elapsed} : CANCEL');
  clock.cancel();

  print('finished test');
}

Future<void> f( SimClock clock , List<int> delays , Map<int,Duration> occurredAt ) async
{
  int count = 0;
  for( int d in delays )
  {
    print('${simulator.elapsed} stage $count');
    occurredAt[count] = simulator.elapsed;

    if( !await clock.delay( d ) )
    {
      return;
    }

    count++;
  }

  print('${simulator.elapsed} done stage $count');
}
