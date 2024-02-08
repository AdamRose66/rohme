/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'field.dart';
import 'register_base.dart';

// Thrown when attempting to creating a [Field] that overlaps with another
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

/// Thrown when attempting to Write to a Read only register
class WritetoReadOnly implements Exception
{
  RegisterBase registerBase;

  WritetoReadOnly( this.registerBase );

  @override
  String toString()
  {
    return 'Cannot write to $registerBase';
  }
}