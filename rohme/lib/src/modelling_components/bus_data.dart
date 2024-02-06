/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:typed_data';
import 'memory_if.dart';
import '../primitives/access_type.dart';

/// A wrapper around ByteData, adding allignment checking and [DmiHint]s.
///
/// We would prefer to extend [ByteData] but ByteData is abstract and final
/// So instead we instantiate and delegate.
///
class BusData
{
  /// The endianness used for the reads and writes
  final Endian endian;

  /// The underlying storage
  final ByteData byteData;

  BusData( int length , [this.endian = Endian.little] ) : byteData = ByteData( length );

  BusData.sublistView(TypedData data, this.endian , [int start = 0, int? end]) :
    byteData = ByteData.sublistView( data , start , end );

  BusData.view(ByteBuffer buffer, this.endian , [int offsetInBytes = 0, int? length]):
    byteData = ByteData.view( buffer , offsetInBytes , length );

  void write64( int addr , int data )
  {
    checkAlignment( addr , 4 );
    byteData.setUint64( addr , data , endian );
  }

  int read64( int addr )
  {
    checkAlignment( addr , 4 );
    return byteData.getUint64( addr , endian );
  }

  void write32( int addr , int data )
  {
    checkAlignment( addr , 4 );
    byteData.setUint32( addr , data , endian );
  }

  int read32( int addr )
  {
    checkAlignment( addr , 4 );
    return byteData.getUint32( addr , endian );
  }

  void write16( int addr , int data )
  {
    checkAlignment( addr , 2 );
    byteData.setUint16( addr , data , endian );
  }

  int read16( int addr )
  {
    checkAlignment( addr , 2 );
    return byteData.getUint16( addr , endian );
  }

  void write8( int addr , int data )
  {
    byteData.setUint8( addr , data );
  }

  int read8( int addr )
  {
    return byteData.getUint8( addr );
  }

  /// For memory, always returns a [DmiHint], assuming [addr] is in range.
  DmiHint getDmiHint( int addr , [AccessType accessType = AccessType.readWrite] )
  {
      return DmiHint( this , addr );
  }

  /// used by reads and writes to check correct alignment
  void checkAlignment( int addr , int alignment )
  {
    if( (addr & (alignment - 1)) != 0 )
    {
      throw AlignmentError( addr , alignment );
    }
  }
}
