/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:collection';
import 'register.dart';
import '../primitives/access_type.dart';

/// Encapsulates one master's view of the memory map
///
/// Registers can be accessed by address, using the [] operator, or by name,
/// using [getByName].
///
/// Both the [map] and [byName] maps are public. There is a certain amount of
/// risk here, but used responsibly this comes with the full array of iterators
/// provided by Dart.
///

class RegisterMap
{
  /// The name of the register map
  final String name;
  /// the size in bits of all the registers in this register map
  final int registerSize;
  /// the map of registers, ordered and indexed by address
  final SplayTreeMap<int,Register> map = SplayTreeMap();
  /// the map of registers, indexed by strings
  final Map<String,Register> byName = {};

  RegisterMap( this.name , [this.registerSize = 32]);

  /// Adds a [Register] to an [address] in the Register map
  ///
  /// [fieldDescriptors], if supplied, is a list of (registerName,start,end)
  /// triplets which can be used to create fields associated with this register.
  ///
  /// ```dart
  /// registerMap.addRegister('r0', 0x100 ,
  ///   fieldDescriptors : [
  ///     ('a',0,2) ,
  ///     ('b',4,9) ,
  ///    ('c',31,32)
  ///   ]);
  /// ```
  /// It is also possible to add fields after the [Register] has been created.
  ///
  /// Register r = registerMap.addRegister('r0', 0x100 );
  ///
  /// ```dart
  /// r.addField( r , 'a' , (0,2) );
  /// r.addField( r , 'b' , (4,9) );
  /// r.addField( r , 'b' , (31,32) );
  /// ```
  ///
  /// Whichever way is used to specify the fields, the range is specified as
  /// [from,to). In other words, b is in the range if from <= b < to.
  ///
  Register addRegister( String registerName , int address ,
    { int initialValue = 0 ,
      List<(String,int,int)> fieldDescriptors = const [] ,
      AccessType accessType = AccessType.readWrite } )
  {
    Register register = Register( registerName ,
                                  accessType: accessType ,
                                  initialValue: initialValue ,
                                  size: registerSize );

    map[address] = register;
    byName[registerName] = register;

    for( (String,int,int) f in fieldDescriptors )
    {
      String fieldName;
      int from , to;

      ( fieldName , from , to ) = f;
      register.addField( fieldName , (from,to) );
    }
    return register;
  }

  /// looks up a [Register] by name
  Register getByName( String registerName )
  {
    return byName[registerName]!;
  }

  /// looks up a Register by address
  Register operator[]( int addr )
  {
    return map[addr]!;
  }

  /// resets every register in the map to its initialValue
  void reset()
  {
    map.forEach( (addr,register) => register.reset() );
  }
}
