/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:collection';
import 'dart:async';

/// An abstract interface class for the put side of a [Fifo]
abstract interface class FifoPutIf<T>
{
  /// An asynchronous put method.
  ///
  /// Completes when the implementer is able to accept the transaction [t].
  Future<void> put( T t );

  /// A synchronous canPut method
  ///
  /// Returns true if there is room in the implementer to accept a transacion.
  ///
  /// For a fifo, equivalent to isNotFull
  ///
  bool canPut();
}

/// An abstract interface class for the get side of a [Fifo]
abstract interface class FifoGetIf<T>
{
  /// An asynchronous get method.
  ///
  /// Completes when the implementer has something to return.
  ///
  Future<T> get();

  /// A synchronous canGet method.
  ///
  /// Returns true if the implementer has something to get.
  ///
  /// For a fifo, equivalent to isNotEmpty
  bool canGet();
}

/// An asynchronous Fifo with configurable buffer size and delays
class Fifo<T> implements FifoPutIf<T> , FifoGetIf<T>
{
  /// the internal data storage
  final ListQueue<T> _data = ListQueue();

  /// the Duration for each put and get
  final Duration? duration;

  /// the buffer depth of the fifo
  final int size;

  /// The name of this fifo
  ///
  /// Used for debug
  ///
  final String name;

  Fifo( this.name , {this.duration = Duration.zero , this.size = 1} )
  {
    if( duration != null ) print('$name constructed with duration $duration');
    if( size < 1 )
    {
      throw FifoSizeError( size );
    }
  }

  // internal completers used to signify that a put or get has just happened
  Completer<void> _justSet = Completer();
  Completer<void> _justConsumed = Completer();

  /// An asynchronous put method, which unblocks when there is room in the fifo
  @override
  Future<void> put( T t ) async
  {
    if( !canPut() )
    {
      await _justConsumed.future;
    }

    if( duration != null )
    {
      await Future.delayed( duration! );
    }

    _data.addFirst( t );

    if( !_justSet.isCompleted ) _justSet.complete();
    _justConsumed = Completer();
  }

  /// A synchronous get method, which unblocks when there is something to be got from the fifo.
  ///
  @override
  Future<T> get() async
  {
    if( !canGet() )
    {
      await _justSet.future;
    }

    // immediately block other gets
    T newT = _data.last;

    if( duration != null )
    {
        await Future.delayed( duration! );
    }

    _data.removeLast();

    if( !_justConsumed.isCompleted ) _justConsumed.complete();
    _justSet = Completer();

    return newT;
  }

  @override
  bool canGet() => _data.isNotEmpty;

  @override
  bool canPut() => _data.length < size;
}

/// An exception thrown when trying to create a Fifo of size less than one
class FifoSizeError extends Error
{
  int size;
  FifoSizeError( this.size );

  @override
  String toString()
  {
    return 'size must be greater or equal to one, but $size was observed';
  }
}
