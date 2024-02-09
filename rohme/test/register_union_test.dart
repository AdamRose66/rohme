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

class RegView1 extends Register
{
  late final Field _a , _b , _c;

  // ignore: use_super_parameters
  RegView1( String name , SharedInt sharedInt ) : super( name , sharedInt : sharedInt )
  {
    _a = addField('a' , (0,2) );
    _b = addField('b' , (4,9) );
    _c = addField('c' , (31,32) );
  }

  set a( int data ) => _a.write( data );
  int get a => _a.read();

  set b( int data ) => _b.write( data );
  int get b => _b.read();

  set c( int data ) => _c.write( data );
  int get c => _c.read();
}

class RegView2 extends Register
{
  final List<Field> bytes = [];

  // ignore: use_super_parameters
  RegView2( String name , SharedInt sharedInt ) : super( name , sharedInt : sharedInt )
  {
    for( int i = 0; i < 4; i++ )
    {
      bytes.add( addField( 'b$i' , (i*8,(i+1)*8) ) );
    }
  }
}

void main() {
  group('A group of tests', () {
    setUp(() {
    });

    test('sharedInt register test', () async {
      Register r0 = Register('r0');

      RegView1 regView1 = RegView1('rv1', r0.sharedIntValue );
      RegView2 regView2 = RegView2('rv2', r0.sharedIntValue );

      regView1.a = 0x3;
      regView1.c = 0x1;

      print('$regView1');
      print('$regView2');
      print('$r0');

      expect( regView2.bytes[0].peek() , isNot( equals( 0 ) ) );
      expect( regView2.bytes[1].peek() , equals( 0 ) );
      expect( regView2.bytes[2].peek() , equals( 0 ) );
      expect( regView2.bytes[3].peek() , isNot( equals( 0 ) ) );

      r0.poke( 0xffffffff );

      print('$regView1');
      print('$regView2');
      print('$r0');

      expect( regView1.b , 0x1f );

      // ignore: avoid_function_literals_in_foreach_calls
      regView2.bytes.forEach( (b) => expect( b.peek() , 0xff ) );
    });
  });
}
