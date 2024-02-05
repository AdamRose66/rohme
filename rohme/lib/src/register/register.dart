/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import '../utils/hex_print.dart';

// To be done : handle different access types ( read only, write only , read write , etc etc )

/// A base class used for [Register] and [Field]
abstract class RegisterBase
{
  /// the name of the [Register] or [Field]
  final String name;

  /// the read callback
  void Function( int )? onRead;
  /// the write callback
  void Function( int )? onWrite;

  RegisterBase( this.name );

  /// the setter for debugValue ( ie poke )
  set debugValue( int data );

  /// the getter for debugValue ( ie peek )
  int get debugValue;

  /// the setter ( ie write ) for the value. Calls write callback if present.
  set value( int data )
  {
    debugValue = data;
    onWrite?.call( debugValue );
  }

  /// the getter ( ie read ) for the value. Calls read callback if present.
  int get value
  {
    int v = debugValue;
    onRead?.call( v );
    return v;
  }
}

/// The Register class
///
/// The register class has an [initialValue] , a [size] and zero, one or more
/// [Field]s.
///
class Register extends RegisterBase
{
  /// The initial value
  final int initialValue;
  /// the stored value
  int _value;
  /// the size ( in bits ) of the register
  int size;
  /// the list of fields of this register
  final Map<String,Field> _fields = {};

  /// the setter ( ie poke )
  @override
  set debugValue( int data ) => _value = data;

  // the getter ( ie peek )
  @override
  int get debugValue => _value;

  /// The Register Constructor
  ///
  /// The initialValue is the value that the register gets at start of day and
  /// when [reset()] is called.
  Register( super.name , { this.initialValue = 0 , this.size = 32 } ) : _value = initialValue
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

  /// Adds a field with name [fieldName] and a [range].
  ///
  /// The range is [first,last), so (0,10) specifies bits 0,1,...,9.
  Field addField( String fieldName , (int,int) range )
  {
    if( _fields.containsKey( fieldName ) )
    {
      throw DuplicateFieldNameError( name , fieldName );
    }

    _fields.forEach( (name,field) {
      if( _startsOrEndsWithin( range , field.range ) ||
          _startsOrEndsWithin( field.range , range ) )
      {
        throw FieldOverlapError( range , field );
      }
    } );

    Field field = Field( this , fieldName , range );
    _fields[fieldName] = ( field );
    return field;
  }

  /// The setter for the underlying value ( ie write )
  ///
  /// This sets the value, calls the write field callbacks, and then calls the
  /// write register callback.
  @override
  set value( int data )
  {
    debugValue = data;

    _fields.forEach( (name,f) { f.onWrite?.call( f.debugValue ); } );
    onWrite?.call( data );
  }

  /// The getter for the underlying value ( ie write )
  ///
  /// This calls the read field callbacks, gets the value, calls the register
  /// read callbacks, and then returns the value.
  @override
  int get value
  {
    _fields.forEach( (name,f) {
      print('calling on Read for field $name');
      f.onRead?.call( f.debugValue );
    });

    int v = debugValue;
    onRead?.call( v );

    return v;
  }

  /// Resets the underlying value to [initialValue], without calling any
  /// callbacks.
  void reset() => debugValue = initialValue;

  /// A string representation of the Register
  @override
  String toString()
  {
    int v = debugValue;
    String str = '$name = ${v.hex()},${v.bin()}';

    if( _fields.isNotEmpty ) {
      str += ' {';
      _fields.forEach( (fieldName,field) { str += ' $fieldName${field.range} = ${field.debugValue.hex()},${field.debugValue.bin()};'; } );
      str += ' }';
    }
    return str;
  }

  static bool _startsOrEndsWithin( (int,int) range1 , (int,int) range2 )
  {
    int from , to;

    (from,to) = range1;

    return inRange( from , range2 ) || inRange( to - 1 , range2 );
  }

  /// b is in range if start <= b < end
  static bool inRange( int b , (int,int) range )
  {
    int from , to;

    (from,to) = range;
    return from <= b && b < to;
  }
}

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
  final Register register;
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
  Field( this.register , super.name , this.range ) :
    mask = calculateMask( range );

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
    int from , to;

    (from,to) = range;
    return '$name : ${register.name}[$from,$to] = ${debugValue.bin()}';
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

/// Thrown when attempting to creating a [Field] that overlaps with another
/// Field in the same [Register]
class FieldOverlapError implements Exception
{
  Field clashingField;
  (int,int) requestRange;

  FieldOverlapError( this.requestRange , this.clashingField );

  @override
  String toString()
  {
    return 'cannot create range $requestRange because it overlaps with Field $clashingField';
  }
}

/// Thrown when attempting to create a Field] that has the same name as another
/// Field in the same [Register]
class DuplicateFieldNameError implements Exception
{
  String registerName , fieldName;

  DuplicateFieldNameError( this.registerName , this.fieldName );

  @override
  String toString()
  {
    return 'cannot create field $fieldName in register $registerName because a field of that name already exists';
  }
}
