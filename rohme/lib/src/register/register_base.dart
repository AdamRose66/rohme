/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import '../primitives/access_type.dart';

import 'register_exceptions.dart';

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

  /// read, write or ( by default ) readWrite
  ///
  /// The intention is that basic read/write access is controlled by this, but
  /// more sophisticated access controls ( W1C etc ) are done by using the
  /// [onRead] or [onWrite] callbacks
  AccessType accessType;

  RegisterBase( this.name , this.accessType );

  /// writes a value without side effects
  void poke( int data );

  /// reads a value without side effects
  int peek();

  /// Writes a value. Calls write callback if present
  ///
  /// Throws WritetoReadOnly if a Read only register is written to
  void write( int data )
  {
    if( !accessType.isWriteAccess() )
    {
      throw WritetoReadOnly( this );
    }
    poke( data );
    onWrite?.call( peek() );
  }

  /// Reads a value. Calls read callback if present.
  ///
  /// If this is a write only register, return 0 and do not call [onRead]
  int read()
  {
    if( !accessType.isReadAccess() )
    {
      return 0;
    }

    int v = peek();
    onRead?.call( v );
    return v;
  }
}
