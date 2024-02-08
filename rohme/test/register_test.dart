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
  late final Field a , b ,c;

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

class MyUnion extends RegisterWithOverlaps
{
  late final List<Field> halfwords;
  late final List<Field> bytes;

  MyUnion( super.name )
  {
    halfwords = [ addField('hw0' , (0 , 16 )) ,
                  addField('hw1' , (16 , 32 )) ];

    bytes = [ addField('b0' , (0 , 8 )) ,
              addField('b1' , (8 , 16 )) ,
              addField('b2' , (16 , 24 )) ,
              addField('b3' , (24 , 32 )) ];
  }
}

class RestrictedFieldAccessRegister extends Register
{
  late final Field wo , rw , ro;

  RestrictedFieldAccessRegister( super.name )
  {
    wo = addField('wo',(0,8),AccessType.write);
    rw = addField('rw',(8,24),AccessType.readWrite);
    ro = addField('ro',(24,32),AccessType.read);
  }
}

void main() async {
  group('A group of tests', () {
    setUp(() {
    });

    test('simple register test', () async {
      MyReg r1 = MyReg( 'r1' );

      r1.onRead = ( data ) => print('r1 saw read ${data.bin()}');
      r1.onWrite = ( data ) => print('r1 saw write ${data.bin()}');

      r1.a.onRead = ( data ) => print('r1.a saw read ${data.bin()}');
      r1.a.onWrite = ( data ) => print('r1.a saw write ${data.bin()}');

      r1.value = 0x96; // 0x96,0b10010110 { a(2, 4) = 0x1,0b1; b(0, 2) = 0x2,0b10; c(4, 5) = 0x1,0b1; }

      int expectedValue = 0x96 & 0x1f;
      int a = r1.value;

      print('$r1');
      expect( a , expectedValue );

      r1.a.value = 0xffff;

      print('$r1');
      expect( r1.a.debugValue , 0x3 );
      expect( r1.debugValue , expectedValue | ( 0x2 << 2 ) );

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

    test('union test', () async {
      MyUnion myUnion = MyUnion('union');

      myUnion.halfwords[0].value = 0x1234;
      myUnion.halfwords[1].value = 0x5678;

      expect( myUnion.bytes[0].value , equals( 0x34 ) );
      expect( myUnion.bytes[1].value , equals( 0x12 ) );
      expect( myUnion.bytes[2].value , equals( 0x78 ) );
      expect( myUnion.bytes[3].value , equals( 0x56 ) );

      myUnion.bytes[2].value = 0x0;
      expect( myUnion.halfwords[1].value , equals( 0x5600 ) );
    });

    test('simple register access test', () {
      Register ro = Register('ro', accessType : AccessType.read );
      Register wo = Register('wo', accessType : AccessType.write );

      print('$ro');
      print('$wo');

      bool ok = true;
      try
      {
        ro.value = 0x1234;
      }
      on WritetoReadOnly catch( e )
      {
        print('expected error $e');
        ok = false;
      }

      // we threw an exception
      expect( ok , equals( false ) );
      // the write never actually happened
      expect( ro.value , equals( 0 ) );

      wo.value = 0x1234;

      // the write happened
      expect( wo.debugValue , equals( 0x1234 ) );

      // but we can't read from it
      expect( wo.value , equals( 0 ) );
    });

    test('field access test', () {
      int woWriteCount = 0 , rwWriteCount = 0 , roWriteCount = 0;
      int woReadCount = 0 , rwReadCount = 0 , roReadCount = 0;

      RestrictedFieldAccessRegister reg = RestrictedFieldAccessRegister('reg');

      reg.onRead = ( v ) => print('just read reg ${v.hex()}');
      reg.onWrite = ( v ) => print('just wrote reg ${v.hex()}');

      reg.wo.onRead = ( v ) { print('just read WO ${v.hex()}'); woReadCount++; };
      reg.wo.onWrite = ( v ) { print('just wrote WO ${v.hex()}'); woWriteCount++; };

      reg.rw.onRead = ( v ) { print('just read RW ${v.hex()}'); rwReadCount++; };
      reg.rw.onWrite = ( v ) { print('just wrote RW ${v.hex()}'); rwWriteCount++; };

      reg.ro.onRead = ( v ) { print('just read RO ${v.hex()}'); roReadCount++; };
      reg.ro.onWrite = ( v ) { print('just wrote RO ${v.hex()}'); roWriteCount++; };

      reg.value = 0x12345678;

      expect( woWriteCount , 1 );
      expect( rwWriteCount , 1 );

      print('After write : $reg');

      int v = reg.value;

      expect( roReadCount , 1 );
      expect( rwReadCount , 1 );

      expect( v , 0x345600 );
      expect( woReadCount , 0 );
      expect( roWriteCount , 0 );
    });

  });
}
