/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:async';

/// An acquire / release protoocol for a Semaphore
abstract interface class SemaphoreIf
{
  Future<void> acquire( {int n = 1 , String? threadName} );
  Future<void> release( {int n = 1 , String? threadName} );
}

/// A lock/unlock protoocol for a Semaphore
abstract interface class MutexIf
{
  Future<void> lock( [String? threadName]);
  Future<void> unlock( [String? threadName] );
}

/// Models a Semaphore.
///
/// The Semaphore starts with [size] resources.
/// ```dart
/// await semaphore.acquire( n );
/// ```
/// waits until it is possible to acquire n of those resources.
/// ```dart
///
/// await semaphore.release( n );
/// ```
/// releases n resources
///
class Semaphore implements SemaphoreIf
{
  int _remaining;

  /// The name of the Semaphore
  ///
  /// useful for debug
  ///
  final String name;

  /// The initial ( and maximum ) number of resources owned by the [Semaphore]
  final int size;

  Semaphore( this.name , {this.size = 1} ) : _remaining = size
  {
    if( size < 1 ) throw SemaphoreSizeError( name , size );
  }

  /// The number of the Semaphore's resources that have been consumed
  int get used => size - _remaining;

  /// The number of the Semaphore's resources that are still available
  int get available => _remaining;

  /// The list of acquireRequests, in the order that they were made
  final List<AcquireRequest> _acquireRequests = [];

  /// Immediately Releases n resources
  ///
  /// And completes the oldest matching request that can be serviced, if there
  /// is one. If [threadName] is not null, then debug messages are turned on.
  ///
  @override
  Future<void> release( {int n = 1 , String? threadName} ) async
  {
    _remaining += n;
    if( threadName != null ) {
      print('  release $threadName immediately releasing $n resources ( $_remaining now available )');
    }

    try
    {
      AcquireRequest acquireRequest = _acquireRequests.firstWhere( (item) { return item.requested <= available; } );

      if( threadName != null )
      {
        print('  release $threadName issuing completion for $n resources to ${acquireRequest.name}');
      }

      _acquireRequests.remove( acquireRequest );
      acquireRequest.completer.complete();
    }
    on StateError
    {
      if( threadName != null ) {
        print('  release $threadName despite release $n there are no acquireRequests can be completed');
      }
    }

    // give just released acquire request time to grab some resources
    // before this thread unfairly regrabs them.
    await Future.delayed( Duration.zero );
  }

  /// Acquires n resources
  ///
  /// Waits a delta at the end to ensure fairness, so should nearly always
  /// be called using await.
  @override
  Future<void> acquire( {int n = 1 , String? threadName} ) async
  {
    if( threadName != null ) {
      print('  acquire $threadName would like to acquire $n resources when $_remaining are available');
      print('  acquireRequests list length ${_acquireRequests.length}');
    }

    // we put this request in the queue if either there are others pending or
    // the request cannot be serviced
    if( _acquireRequests.isNotEmpty || n > available )
    {
      if( threadName != null )
      {
        print('  acquire $threadName adding $n requests to queue ($_remaining are available)');
      }

      AcquireRequest acquireRequest = AcquireRequest(n , threadName);
      _acquireRequests.add( acquireRequest );
      await acquireRequest.completer.future;

      if( threadName != null )
      {
        print('  acquire $threadName has been completed');
      }
    }

    if( n > available )
    {
      throw SemaphoreAcquireError( threadName , available , n );
    }

    // immediately acquire resources
    _remaining -= n;
    if( threadName != null ) {
      print('  acquire $threadName: just acquired $n resources - $_remaining are now available');
    }

    // give other threads a chance to run
    await Future.delayed( Duration.zero );
  }
}

///
/// A Mutex is a Semaphore of size one with different names for the methods.
///
class Mutex extends Semaphore implements MutexIf
{
  Mutex( super.name );

  /// acquires a single resource
  @override
  Future<void> lock( [String? threadName] ) async
  {
    await acquire( threadName: threadName );
  }

  /// releases a single resource
  @override
  Future<void> unlock( [String? threadName] ) async
  {
    await release( threadName: threadName );
  }
}

/// An internal class for [Semaphore]
class AcquireRequest
{
  final Completer<void> completer = Completer();
  final int requested;
  final String? name;

  AcquireRequest( this.requested , this.name );
}

/// Thrown by a [Semaphore] when size is <1.
class SemaphoreSizeError implements Exception
{
  int size;
  String name;

  SemaphoreSizeError( this.name , this.size );

  @override
  String toString()
  {
    return 'Semaphore $name: size must be one or more, not $size';
  }
}

/// Thown by [Semaphore] when attempting to releasw more resources than have
// been used
class SemaphoreReleaseError implements Exception
{
  int releaseRequest;
  int currentlyUsed;
  int size;
  String name;

  SemaphoreReleaseError( this.name , this.size , this.currentlyUsed , this.releaseRequest );

  @override
  String toString()
  {
    return 'Semaphore $name only has $currentlyUsed resources used, so cannot release $releaseRequest resouces';
  }
}

/// An internal [Semaphore] Error which should never happen !
class SemaphoreAcquireError extends Error
{
  String? name;
  int currentlyAvailable;
  int acquireRequest;

  SemaphoreAcquireError( this.name , this.currentlyAvailable , this.acquireRequest );

  @override
  String toString()
  {
    return 'Disaster in semaphore $name: about to acquire $acquireRequest resources when only $currentlyAvailable are available';
  }
}
