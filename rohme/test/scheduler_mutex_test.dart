/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:async';

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

List<SimDuration> criticalA = [];
List<SimDuration> criticalB = [];

void runMutexTest( int loops )
{
  print('starting mutexTest');

  simulator.run( (async) { mutexTest( loops ); });
  simulator.elapse( SimDuration( seconds:1 ));
  print('finished sim at ${simulator.elapsed}');

  expect( criticalA.length , equals( loops ) );
  expect( criticalB.length , equals( loops ) );

  expectNoOverlap( criticalA , criticalB );
}

Future<void> mutexTest( int loops ) async
{
  Mutex mutex = Mutex('mutex');

  greedy( 'a' , loops , mutex , criticalA );
  greedy( 'b' , loops , mutex , criticalB );
}

Future<void> greedy( String name , int loops , Mutex m , List<SimDuration> criticalSections ) async
{
  for( int i = 0; i < loops; i++ )
  {
    await m.lock( name );
    criticalSections.add( simulator.elapsed );

    print('$name (${simulator.elapsed}): starting critical section $i');
    await Future.delayed( SimDuration( microseconds: 10 ) );
    print('$name (${simulator.elapsed}): ending critical section $i');

    await m.unlock( name );
  }
}

void expectNoOverlap( List<SimDuration> l1 , List<SimDuration> l2 )
{
  for( SimDuration t1 in l1 )
  {
    for( SimDuration t2 in l2 )
    {
      expect( t1 , isNot( equals( t2 ) ) );
    }
  }
}

//
// this is by no means an exhaustive test of Mutex, and we haven't even
// started on Semaphore with size > 1
//
// But the basic functioning of a mutex with time critical sections is tested
// below
//
void main() async {
  group('A group of tests', () {
    setUp(() {
    });

    test('Mutex Test', () async {
      runMutexTest( 3 );
    });
    test('Semaphore Size Test', () {
      bool ok = true;
      try
      {
        Semaphore('s',size:-1);
      }
      on SemaphoreSizeError catch( e )
      {
        print('seen expected error $e');
        ok = false;
      }
      expect( ok , false );
    });
    test('Semaphore Used Test', () async {
      bool ok = true;
      Semaphore semaphore = Semaphore('s',size:2);

      await semaphore.acquire();
      expect( semaphore.used , 1 );
    });
  });
}
