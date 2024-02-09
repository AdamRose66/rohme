/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'register_base.dart';
import 'field.dart';
import 'register_exceptions.dart';

import '../primitives/access_type.dart';
import '../utils/hex_print.dart';

/// A Register class that allows overlapping fields
///
/// Has an [initialValue] , a [size] and zero, one or more [Field]s.
/// If instantiated directly, the fields may overlap.
///
class RegisterWithOverlaps extends RegisterBase
{
  /// The initial value
  final int initialValue;
  /// the stored value
  ///
  /// This can either be local storage, or shared with one or more other
  /// Registers, as if the Register was a union of structs
  final SharedInt sharedIntValue;
  /// the size ( in bits ) of the register
  final int size;
  /// the list of fields of this register
  final Map<String,Field> _fields = {};

  /// the read mask for this register
  int? _readMask;
  /// the write mask for this register
  int? _writeMask;

  /// Writes a value, with no side effects
  @override
  void poke( int data ) =>  sharedIntValue.value = data;

  /// Reads a value, with no side effects
  @override
  int peek() => sharedIntValue.value;

  /// The Register Constructor
  ///
  /// In the default case of [sharedInt] == null, the initialValue is the value
  /// that the register gets at start of day and when [reset()] is called.
  ///
  /// If sharedInt is not null, then the int storage is whatever is supplied
  /// in that [SharedInt]. Calling reset() on this register will set the _value
  /// of that shared int to this register's initialValue.
  RegisterWithOverlaps( String name ,
    { AccessType accessType = AccessType.readWrite ,
      this.initialValue = 0 ,
      this.size = 32 ,
      SharedInt? sharedInt ,
      } ) :  sharedIntValue = sharedInt ?? SharedInt( initialValue ) ,
            super( name , accessType )
  {
    if( size > 64 )
    {
      throw ArgumentError.value( size , 'Register class can currently only handle sizes less than 64');
    }
  }

  /// Returns the [Field] with name [fieldName].
  Field operator[]( String fieldName )
  {
    if( !_fields.containsKey( fieldName ) )
    {
      throw ArgumentError.value( fieldName , 'no such field in register $name');
    }

    return _fields[fieldName]!;
  }

  /// Adds a field with name [fieldName], a [range] and an optional [AccessType]
  ///
  /// The range is [first,last), so (0,10) specifies bits 0,1,...,9.
  /// Also updates register read/write masks depending on [accessType]
  Field addField( String fieldName , (int,int) range ,
                  [AccessType accessType = AccessType.readWrite] )
  {
    if( _fields.containsKey( fieldName ) )
    {
      throw DuplicateFieldNameError( name , fieldName );
    }

    _checkForOverlaps( range );

    Field field = Field( this , fieldName , range , accessType );
    _fields[fieldName] = ( field );

    if( accessType.isReadAccess() )
    {
      _readMask = _addToMask( _readMask , field.mask );
    }
    if( accessType.isWriteAccess() )
    {
      _writeMask = _addToMask( _writeMask , field.mask );
    }

    return field;
  }

  /// does nothing here - but overriden in [Register]
  void _checkForOverlaps( (int,int) range ) {}

  /// Writes a value, with possible side effects
  ///
  /// If this register is writeable, sets the value, calls the write field
  /// callbacks, and then calls the write register callback.
  ///
  /// If it is not writeable, we throw WritetoReadOnly immediately
  @override
  void write( int data )
  {
    if( !accessType.isWriteAccess() )
    {
      throw WritetoReadOnly( this );
    }

    poke( _writeMask == null ? data : data & _writeMask! );

    _fields.forEach( (name,f) {
      if( f.accessType.isWriteAccess() ) {
        f.onWrite?.call( f.peek() );
      }
    });

    onWrite?.call( data );
  }

  /// Reads a value, with possible side effects
  ///
  /// If this register is readable, calls the read field callbacks, gets the
  /// value, calls the register read callbacks, and then returns the value.
  ///
  /// If it not readable, simply return zero.
  @override
  int read()
  {
    if( !accessType.isReadAccess() )
    {
      return 0;
    }

    _fields.forEach( (name,f) {
      if( f.accessType.isReadAccess() ) {
        f.onRead?.call( f.peek() );
      }
    });

    int v = _readMask == null ? peek() : peek() & _readMask!;

    onRead?.call( v );
    return v;
  }

  /// Resets the underlying value to [initialValue], without calling any
  /// callbacks.
  void reset() => poke( initialValue );

  /// A string representation of the Register
  @override
  String toString()
  {
    int v = peek();
    String str = '$name = ${v.hexBin()}';

    if( accessType != AccessType.readWrite )
    {
      str += ' : $accessType only';
    }

    if( _fields.isNotEmpty ) {
      str += ' {';
      _fields.forEach( (fieldName,field) { str += ' $fieldName${field.range} = ${field.peek().hexBin()};'; } );
      str += ' }';
    }
    return str;
  }

  static int _addToMask( int? currentMask , int newMask )
  {
    if( currentMask == null ) return newMask;
    return currentMask | newMask;
  }
}

/// The Register class used in [RegisterMap]
///
/// The register class does not allow overlapping bit fields
class Register extends RegisterWithOverlaps
{
  Register( super.name ,
    { super.accessType = AccessType.readWrite ,
      super.initialValue = 0 ,
      super.size = 32 ,
      super.sharedInt } );

  @override
  void _checkForOverlaps( (int,int) range )
  {
    _fields.forEach( (name,field) {
      if( _startsOrEndsWithin( range , field.range ) ||
          _startsOrEndsWithin( field.range , range ) )
      {
        throw FieldOverlapError( range , field );
      }
    } );
  }

  static bool _startsOrEndsWithin( (int,int) range1 , (int,int) range2 )
  {
    int from , to;

    (from,to) = range1;

    return _inRange( from , range2 ) || _inRange( to - 1 , range2 );
  }

  /// b is in range if start <= b < end
  static bool _inRange( int b , (int,int) range )
  {
    int from , to;

    (from,to) = range;
    return from <= b && b < to;
  }
}
