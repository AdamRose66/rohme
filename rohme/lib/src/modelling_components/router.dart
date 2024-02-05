/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import '../modelling.dart';
import '../utils.dart';
import 'memory_if.dart';

/// A router that decodes inbound read/write calls and forwards them to memory mapped targets.
///
/// This simple [Router] receives inbound calls to read and write and forwards
/// them to the correct initiator port, according to the memory map.
///
/// This memory is specified by a list of (start_address,end_address,name)
/// triplets which can be specified in the constructor or by calling
/// [addInitiatorPorts].
///
/// Internally, this list is transformed into a list of
/// (start_address,end_address,[MemoryPort]) triplets, where the MemoryPorts
/// are automatically constructed.
///
/// This component both implements [MemoryIf] and provides an export, so we
/// can either connect to it by doing
/// ```dart
/// memoryPort <= memory.targetExport;
/// ```
/// in the connect phase or by doing
/// ```dart
/// memoryPort.implementedBy( memory );
/// ```
/// in the constructor.
///
/// If the read or write address map is not in the address map, then a
/// [RouterDecodeError] will be thrown.
///
/// Overlapping Address maps are decoded on a 'first in list wins' basis.
///
class Router extends Module implements MemoryIf
{
  /// Incoming read/writes come in through this export.
  late final MemoryPort targetExport;

  // this has to be fixed by the end of the construction phase.
  final List<(int,int,MemoryPort)> _initiatorPorts = [];

  /// The [Function] used to map inbound addresses to outbound addresses
  ///
  /// The default implementation subtracts the start of the address range from
  /// the inbound address.
  int Function(int,int) mapAddress = (int addr , int startAddress) { return addr - startAddress; };

  /// The router constructor has a name, a parent, and optional memoryMap description.
  Router( super.name , super.parent , [ List<(int,int,String)> initiatorDescription = const[] ] )
  {
    targetExport = MemoryPort('targetPort',this);
    addInitiatorPorts( initiatorDescription );

    targetExport.implementedBy( this );
  }

  /// Adds to the initiatorDescription list
  void addInitiatorPorts( List<(int,int,String)> initiatorDescription )
  {
    for( var d in initiatorDescription )
    {
      int startAddress , endAddress;
      String portName;

      ( startAddress , endAddress , portName ) = d;
      _initiatorPorts.add( (startAddress , endAddress , MemoryPort( portName , this )) );
    }
  }

  /// Looks up the initiator Port by name
  MemoryPort initiatorPort( String portName )
  {
    int startAddress , endAddress;
    MemoryPort memoryPort;

    ( startAddress , endAddress , memoryPort ) = _initiatorPorts.firstWhere( (r) {
      int localStartAddress , localEndAddress;
      MemoryPort localMemoryPort;

      ( localStartAddress , localEndAddress , localMemoryPort ) = r;

      localStartAddress;
      localEndAddress;

      return localMemoryPort.name == portName;
    });

    startAddress;
    endAddress;

    return memoryPort;
  }

  /// Inbound reads, writes and getDmiHint just forward to the decoded outbound
  /// port.
  ///
  /// If the address cannot be decoded, a [RouterDecodeError] will be thrown
  /// [mapAddress] is used to transform inbound to outbound addresses
  ///
  @override
  Future<void> write64( int addr , int data ) async
  {
    MemoryPort memoryPort;
    int startAddress;

    (startAddress,memoryPort) = _decode( addr );

    await memoryPort.write64( mapAddress( addr , startAddress ) , data );
  }

  @override
  Future<int> read64( int addr ) async
  {
    MemoryPort memoryPort;
    int startAddress;

    (startAddress,memoryPort) = _decode( addr );

    return await memoryPort.read64( mapAddress( addr , startAddress ) );
  }

  @override
  Future<void> write32( int addr , int data ) async
  {
    MemoryPort memoryPort;
    int startAddress;

    (startAddress,memoryPort) = _decode( addr );

    await memoryPort.write32( mapAddress( addr , startAddress ) , data );
  }

  @override
  Future<int> read32( int addr ) async
  {
    MemoryPort memoryPort;
    int startAddress;

    (startAddress,memoryPort) = _decode( addr );

    return await memoryPort.read32( mapAddress( addr , startAddress ) );
  }

  @override
  Future<void> write16( int addr , int data ) async
  {
    MemoryPort memoryPort;
    int startAddress;

    (startAddress,memoryPort) = _decode( addr );

    await memoryPort.write16( mapAddress( addr , startAddress ) , data );
  }

  @override
  Future<int> read16( int addr ) async
  {
    MemoryPort memoryPort;
    int startAddress;

    (startAddress,memoryPort) = _decode( addr );

    return await memoryPort.read16( mapAddress( addr , startAddress ) );
  }

  @override
  Future<void> write8( int addr , int data ) async
  {
    MemoryPort memoryPort;
    int startAddress;

    (startAddress,memoryPort) = _decode( addr );

    await memoryPort.write8( mapAddress( addr , startAddress ) , data );
  }

  @override
  Future<int> read8( int addr ) async
  {
    MemoryPort memoryPort;
    int startAddress;

    (startAddress,memoryPort) = _decode( addr );

    return await memoryPort.read8( mapAddress( addr , startAddress ) );
  }

  @override
  DmiHint getDmiHint( int addr , [BusAccessType busAccessType = BusAccessType.readWrite] )
  {
    MemoryPort memoryPort;
    int startAddress;

    (startAddress,memoryPort) = _decode( addr );

    return memoryPort.getDmiHint( mapAddress( addr , startAddress ) );
  }

  /// Returns a decoded (startAddress,MemoryPort] for [addr]
  ///
  /// Throws RouterDecodeError if [addr] is not in the memory map
  ///
  (int,MemoryPort) _decode( int addr )
  {
    int startAddress , endAddress;
    MemoryPort memoryPort;

    try
    {
      ( startAddress , endAddress , memoryPort ) = _initiatorPorts.firstWhere( (r) { return inRange( addr , r ); });
    }
    catch( e )
    {
      throw RouterDecodeError( fullName , 'Write' , addr );
    }

    endAddress;
    return (startAddress , memoryPort);
  }

  /// Returns true if [addr] is in the range of this [initiatorDescription]
  ///
  /// This function is used by decode logc in both the read and write methods.
  ///
  bool inRange( int addr , (int,int,MemoryPort) r )
  {
    int startAddress , endAddress;
    MemoryPort memoryPort;

    ( startAddress , endAddress , memoryPort ) = r;

    memoryPort;
    return startAddress <= addr && addr < endAddress;
  }

}

/// Thrown by the [Router] if addr is not in the address map
class RouterDecodeError implements Exception
{
  /// the name of the router doing the throwing
  final String routerName;

  /// the command ( read or write ) that has led to this exception
  final String command;

  /// the address that cannot be decoded
  final int addr;


  RouterDecodeError( this.routerName , this.command , this.addr );

  @override
  String toString()
  {
    return '$routerName Cannot Decode $command ${addr.hex}';
  }
}
