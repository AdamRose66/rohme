/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

void checkBottomUp( List<Module> moduleList )
{
  var i = 0;

  for( i = 0; i < moduleList.length - 1; i++ )
  {
    bool foundParent = false;

    for( var j = i + 1; j < moduleList.length && !foundParent; j++ )
    {
      if( moduleList[i].parent == moduleList[j] )
      {
        foundParent = true;
      }
    }

    expect( foundParent , equals( true ) );
  }

  expect( moduleList[i].parent , equals( null ) );
}

void checkTopDown( List<Module> moduleList )
{
  var i = 0;

  expect( moduleList[0].parent , equals( null ) );

  for( i = 1; i < moduleList.length - 1; i++ )
  {
    bool foundParent = false;

    for( var j = i + 1; j < moduleList.length && !foundParent; j++ )
    {
      if( moduleList[i].parent == moduleList[j] )
      {
        foundParent = true;
      }
    }

    expect( foundParent , equals( false ) );
  }
}

void main() {
  test('child_test' , () {
    Module parent = Module('parent');
    NamedComponent child = NamedComponent('child',parent);

    print('child name $child.fullName');
    expect( child.fullName, equals('parent.child') );
  });

  test('visit_test' , () {
    List<Module> topDownList = [];
    List<Module> bottomUpList = [];

    Module top = Module('top');
    Module c1 = Module('c1',top);
    Module c2 = Module('c2',top);
    Module g1 = Module('g1',c1);
    Module g2 = Module('g2',c1);
    Module g3 = Module('g3',c2);

    ( c1 , c2 , g1 , g2 , g3 );

    visit( top ,
      topDown : ( Module m ) {
        topDownList.add( m );
      } ,
      bottomUp : ( Module m ) {
        bottomUpList.add( m );
      }
    );

    for( Module m in topDownList )
    {
      print('Top Down $m.fullName');
    }

    for( Module m in bottomUpList ) {
      print('bottom Up $m.fullName');
    }

    checkBottomUp( bottomUpList );
    checkTopDown( topDownList );

    expect( 6 , equals( topDownList.length ) );
    expect( 6 , equals( bottomUpList.length ) );

    expect( topDownList.length , equals( topDownList.toSet().length ) );
    expect( bottomUpList.length , equals( bottomUpList.toSet().length ) );
  });
}
