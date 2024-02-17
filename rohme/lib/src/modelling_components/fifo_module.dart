/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import '../modelling.dart';
import '../primitives/fifo.dart';

/// A Module which implements and exports the FifoPutIf and FifoGetIf interfaces.
///
/// It uses [Fifo] from the primitives library for the underlying implementation.
///
class FifoModule<T> extends Module implements FifoPutIf<T> , FifoGetIf<T>
{
  /// An export which provides the FifoPutIf
  late final Port<FifoPutIf<T>> putExport;

  /// An export which provides the FifoGetIf
  late final Port<FifoGetIf<T>> getExport;

  late final Fifo<T> _fifo;

  //
  // the [delay] is the delay associated with all puts and gets. The most
  // useful delay is the default, 0, which adds a delta cycle between a
  // transaction and the time at which its effects are visible on the other
  // side of the fifo.
  //
  // The [size] is the maximum size of the buffer.
  //
  FifoModule( super.name , super.parent , {duration = Duration.zero , int size = 1} )
  {
    _fifo = Fifo( fullName , duration:duration , size:size );

    putExport = Port('putExport',this);
    getExport = Port('getExport',this);

    putExport.implementedBy( this );
    getExport.implementedBy( this );
  }

  @override
  Future<void> put( T t ) async
  {
    await _fifo.put( t );
  }

  @override
  Future<T> get() async
  {
    return await _fifo.get();
  }

  @override
  bool canPut()
  {
    return _fifo.canPut();
  }

  @override
  bool canGet()
  {
    return _fifo.canGet();
  }
}
