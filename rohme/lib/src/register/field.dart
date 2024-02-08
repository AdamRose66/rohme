/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'register.dart';
import 'register_base.dart';
import '../primitives/access_type.dart';
import '../utils/hex_print.dart';

/// The Field Class.
///
/// The [Field] class does not store an underlying value. Instead, it has a
/// reference to the register and a mask which it uses to do the correct bit
/// twiddling.
///
/// Read and Write callbacks may be associated with a Field.
class Field extends RegisterBase
{
  /// The [Register] that this field is part of.
  final RegisterWithOverlaps register;
  /// The range of this field ( [from,to) )
  final (int,int) range;
  /// The mask needed by this register to correctly modify the [Register].
  final int mask;

  /// needed to unpack the range
  int get from
  {
    // ignore: unused_local_variable
    int f , t;

    (f,t) = range;

    return f;
  }

  /// A Field requires a register, a name and a [from,to) range
  Field( this.register , String name , this.range ,
         [AccessType accessType = AccessType.readWrite]):
    mask = calculateMask( range ) ,
    super( name , accessType );

  /// The debugValue setter ( ie poke )
  @override
  set debugValue( int data )
  {
    register.debugValue = (register.debugValue & ~mask) | ((data << from) & mask);
  }

  /// The debugValue getter ( ie peek )
  @override
  int get debugValue
  {
    return (register.debugValue & mask) >> from;
  }

  /// A [String] representation of this field
  @override
  String toString()
  {
    String str;
    int from , to;

    (from,to) = range;
    str = '$name : ${register.name}[$from,$to] = ${debugValue.bin()}';

    if( accessType != AccessType.readWrite )
    {
      str += ' : ${accessType} only';
    }

    return str;
  }

  /// A static function used by the constructor to calculate the mask
  static int calculateMask( (int,int) range )
  {
    int mask = 0;

    int from , to;

    (from,to) = range;

    for( int i = from , m = (0x1 << from); i < to; i++ , m <<= 1 )
    {
      mask |= m;
    }

    return mask;
  }
}
