/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:collection';

// The intention behind this is to replace the Set of timers used in FakeAsync
// with something more efficient. Set is fine for testing, which was the orginal
// intention of FakeAsync, but if we have a lot of outstanding Timers in a sim,
// using minBy to get the next pending timer is too ineffecient.
//
// I did consider using a Sorted List ( https://pub.dev/documentation/sorted_list/latest/sorted_list/SortedList-class.html )
// but the add method puts an item at the end of the list and then calls sort,
// which also seems too inefficient.
//
// So I ended up with this. It started life as a non-generic class using
// SimDuration as the key and SimTimer as the element, but it was easy to
// generalise and in fact unit test was easier with a generic class.

/// An abstract interface class for use with [QueueMap]
abstract interface class Indexable<K>
{
  K get index;
}

/// An iterator for [QueueMap]
///
/// [K] is the key and T must provide an index getter by implementing
/// [Indexable]<K>.
class QueueMapIterator<K,T extends Indexable<K>> implements Iterator<T>
{
  /// In practice, _map will be a SplayTreeMap, but we only the need the
  /// interface here, which is [Map].
  final Map<K,Iterable<T>> _map;

  bool _initialised = false;
  final Iterator<K> _keyIterator;
  late Iterator<T> _listIterator;
  bool _gotNext = true;

  /// The interator is initialised with a [Map], usually a [SplayTreeMap].
  QueueMapIterator( this._map ) : _keyIterator = _map.keys.iterator;

  /// moves to the next T, returning true if there is one and false otherwise
  @override
  bool moveNext()
  {
    if( !_gotNext ) {
      // this is possible if _map is empty
      return false;
    }

    if( !_initialised || !_listIterator.moveNext() )
    {
      _initialised = true;
      _advanceQueue();
      return _gotNext;
    }

    return true;
  }

  void _advanceQueue()
  {
    if( _keyIterator.moveNext() )
    {
      _listIterator = _map[_keyIterator.current]!.iterator;
      _gotNext = _listIterator.moveNext();
    }
    else
    {
      _gotNext = false;
    }
  }

  /// returns the current T
  @override
  T get current => _listIterator.current;
}

/// An iterable map of [ListQueue]<T>, ordered by K
class QueueMap<K,T extends Indexable<K>> with Iterable<T>
{
  final _map = SplayTreeMap<K,ListQueue<T>>();

  /// Returns an iterator for the [QueueMap]
  @override
  QueueMapIterator<K,T> get iterator => QueueMapIterator( _map );

  /// is the underlying map empty
  @override
  bool get isEmpty => _map.isEmpty;

  /// is the underlying map non-empty
  @override
  bool get isNotEmpty => _map.isNotEmpty;

  /// add an [Indexable]<T> to the map, creating a new [ListQueue] if needed
  void add( T t )
  {
    _map.putIfAbsent( t.index , () => ListQueue() ).add( t );
  }

  /// add a [QueueMap] to 'this'
  void addQueueMap( QueueMap<K,T> other )
  {
    for( T t in other )
    {
      add( t );
    }
  }

  /// Return the first element of the first queue and remove it from the map
  ///
  /// '''dart
  /// while( queueMap1.isNotEmpty )
  /// {
  ///   T t = queueMap1.popFirst();
  ///   print('popped $t');
  /// }
  T popFirst()
  {
    // ignore: null_check_on_nullable_type_parameter
    K firstKey = _map.firstKey()!;
    ListQueue<T> firstQueue = _map[firstKey]!;

    T t = firstQueue.first;

    firstQueue.removeFirst();

    if( firstQueue.isEmpty )
    {
      _map.remove( firstKey );
    }

    return t;
  }

  /// remove all T's that satisfy [condition] from the map
  void removeWhere( bool Function( T ) condition )
  {
    List<K> removeSlots = [];

    for( K key in  _map.keys )
    {
      ListQueue<T> slot = _map[key]!;

      slot.removeWhere( condition );

      if( slot.isEmpty )
      {
          removeSlots.add( key );
      }
    }

    // ignore: avoid_function_literals_in_foreach_calls
    removeSlots.forEach( (key) => _map.remove( key ) );
  }

  /// Moves t from k to t.index
  ///
  /// Returns true if [t] was in [k] to start with
  /// if t is not in [k], then does nothing
  bool move( K k , T t )
  {
    bool ok = _map[k]!.remove( t );
    if( ok ) add( t );
    return ok;
  }

  /// returns a string representation of 'this'.
  @override
  String toString()
  {
    StringBuffer buffer = StringBuffer();
    for( K key in _map.keys )
    {
      buffer.writeln('$key: ${_map[key]}');
    }
    return buffer.toString().substring(0,buffer.length - 1);
  }
}
