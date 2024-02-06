/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import '../modelling/port.dart';
import '../primitives/access_type.dart';
import 'bus_data.dart';

/// Provides Direct Memory Access to a memory
///
/// The intention is that a master can ask for a [DmiHint], and if successful,
/// can use the hint to bypass any routers or bus fabrics between it and a slave.
/// ```dart
/// class BusMaster
/// {
///    late final MemoryPort p;
///
///    void run() async
///    {
///      p.write32( 0x100 , 0x12345678 ); // a slow write across the fabric
///
///      DmiHint dmiHint = p.getDmiHint( 0x080 );
///
///      // a direct write, to 0x80, using the view of the memory as
///      // adjusted by the DMI hint address
///      dmiHint.adjustedView.write32( 0 , 0xbeef );
///
///      /// a quick read, in effect from address 0x100
///      assert( dmiHint.adjustedView.read32( 0x80 ) == 0x12345678 );
///
///      // quick read from unadjusted address 0x100
///      assert( dmiHint.originalBusData.read32( 0x100 ) == 0x12345678 );
///     }
/// ```
class DmiHint
{
  /// The original, underlying BusData used to define the memory
  final BusData originalBusData;

  /// An adjustedView of the BusData, pointing at Byte [offset] within [originalBusData].
  final BusData adjustedView;

  /// The offset of the [adjustedView] relative to the [originalBusData]
  final int offset;

  DmiHint( this.originalBusData , this.offset ) : adjustedView = BusData.sublistView( originalBusData.byteData , originalBusData.endian , offset );
}

/// An abstract memory interface, allowing aligned access to underlying storage
///
/// reads and writes are Futures since they may consume time.
///
/// reads and writes may throw [RangeError] or [AlignmentError]
/// getDmiHint may throw [RangeError] or [NoDmiHint].
///
abstract interface class MemoryIf
{
  /// writes 64 bit [data] to an 8 byte aligned address
  Future<void> write64( int addr , int data );
  /// Returns 64 bit data from an 8 byte aligned address
  Future<int> read64( int addr );

  /// writes 32 bit [data] to a 4 byte aligned address
  Future<void> write32( int addr , int data );
  /// Returns 32 bit data from a 4 byte aligned address
  Future<int> read32( int addr );

  /// writes 16 bit [data] to a 2 byte aligned address
  Future<void> write16( int addr , int data );
  /// Returns 16 bit data from a 2 byte aligned address
  Future<int> read16( int addr );

  /// writes 8 bit [data] from [addr]
  Future<void> write8( int addr , int data );
  // returns one byte of data from [addr]
  Future<int> read8( int addr );

  /// get a DmiHint from [addr].
  ///
  /// The availability of the hint may depend on the [accessType]
  ///
  DmiHint getDmiHint( int addr , [AccessType accessType = AccessType.readWrite] );
}

/// A convenience port for [MemoryIf]
///
/// Creating this port allows us to use [Port.noSuchMethod()] to directly
/// access interface methods from the port. For example:
/// ```dart
/// late final MemoryPort memoryPort('memoryPort',this);
/// ...
/// memoryPort.read32( addr , data );
/// ```
///
class MemoryPort extends Port<MemoryIf> implements MemoryIf
{
  MemoryPort( super.name , [super.parent] );
}

/// Thrown when an alignment error is observed
class AlignmentError implements Exception
{
  int addr , alignment;

  AlignmentError( this.addr , this.alignment );

  @override
  String toString()
  {
    return 'AlignmentError: $addr.hex is not aligned to $alignment bytes';
  }
}

/// Thrown when there is no [DmiHint] available
class NoDmiHint implements Exception
{
  final int addr;
  AccessType accessType;
  final String name;

  NoDmiHint( this.name , this.addr , this.accessType );

  @override
  String toString()
  {
    return '$name: no Dmi Hint for address $addr.hex access type $accessType';
  }
}
