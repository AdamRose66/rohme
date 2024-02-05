/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:async';
import 'dart:math';

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

void runNotificationTest( int d1 , int d2 )
{
  print('starting notification test');

  simulator.run( (async) { notificationTest( d1 , d2 ); });
  simulator.elapse( Duration( seconds:1 ));

  print('finished sim at ${simulator.elapsed}');
}

Future<void> notificationTest( int d1 , int d2 ) async
{
  var l = [ notifier( 'n1' , d1 ) , notifier( 'n2' , d2 ) ];
  waitForAllNotifications( 'w' , l , max( d1 , d2 ) );
  waitForAnyNotification( 'w' , l , min( d1 , d2 ) );
}

Future<void> notifier( String name , int delay ) async
{
  print('$name: about to wait for $delay at ${simulator.elapsed}');
  await Future.delayed( Duration( microseconds: delay ) );

  print('$name: done notification at ${simulator.elapsed}');
  return;
}

Future<void> waitForAllNotifications( String name , List<Future<void>> notifications , int expectedTime ) async
{
  print('$name: about to wait for all notifications at ${simulator.elapsed}');
  await Future.wait( notifications );
  print('$name: seen all notifications at ${simulator.elapsed}');

  expect( simulator.elapsed, equals( Duration( microseconds: expectedTime ) ) );
}

Future<void> waitForAnyNotification( String name , List<Future<void>> notifications , expectedTime ) async
{
  print('$name: about to wait for one notification at ${simulator.elapsed}');
  await Future.any( notifications );
  print('$name: seen one notification at ${simulator.elapsed}');

  expect( simulator.elapsed, equals( Duration( microseconds: expectedTime ) ) );
}

void main() async {
  group('A group of tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('Notification Test', () async {
      runNotificationTest( 10 , 20 );
    });
  });
}
