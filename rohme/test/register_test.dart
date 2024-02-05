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

class MyReg extends Register
{
  late final Field a , b , c;

  MyReg( super.name )
  {
    a = addField('a',(2,4));

    for( (int,int) range in [ (1,3) , (2,4) , (3,4) , (0,5) , (2,3) , (0,2) ] )
    {
      bool ok = true;
      try
      {
        b = addField('b',range);
      }
      on FieldOverlapError catch( e )
      {
        print('expected error $e');
        ok = false;
      }
      expect( range == (0,2) , ok );
    }

    addField('c',(4,5));

    bool ok = true;
    try
    {
      addField('c',(7,10));
    }
    on DuplicateFieldNameError catch( e )
    {
      print('expected error $e');
      ok = false;
    }
    expect( false , ok );
  }
}

MyReg r1 = MyReg( 'r1' );

void main() async {
  group('A group of tests', () {
    setUp(() {
    });

    test('simple register test', () async {
      r1.onRead = ( data ) => print('r1 saw read ${data.bin()}');
      r1.onWrite = ( data ) => print('r1 saw write ${data.bin()}');

      r1.a.onRead = ( data ) => print('r1.a saw read ${data.bin()}');
      r1.a.onWrite = ( data ) => print('r1.a saw write ${data.bin()}');

      r1.value = 0x96; // 0x96,0b10010110 { a(2, 4) = 0x1,0b1; b(0, 2) = 0x2,0b10; c(4, 5) = 0x1,0b1; }
      int a = r1.value;

      print('$r1');
      expect( a , 0x96 );

      r1.a.value = 0xffff;

      print('$r1');
      expect( r1.debugValue , 0x9e );

      // ignore: unused_local_variable
      int r1A = r1.a.value;

      expect( r1.a.debugValue , 0x3 );

      print('$r1');
      Field f = r1['c'];

      assert( f.name == 'c' );
      print('$f');

      r1.reset();
      expect( r1.debugValue , 0 );
    });
  });
}
