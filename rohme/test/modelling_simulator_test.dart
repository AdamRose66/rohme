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

abstract interface class A
{
  int a();
}

class APort extends Port<A> implements A {
  APort( super.name , [super.parent] );
}

void main() {
  test('port_combined_test' , () {
    simulate( () => Top('top') );
  });
}

class Top extends Module
{
  late final ChildInitiator ci1;
  late final ChildInitiator ci2;
  late final ChildTarget ct;

  Top( super.name , [super.parent] )
  {
    ci1 = ChildInitiator('ci1' , this );
    ci2 = ChildInitiator('ci2' , this );
    ct = ChildTarget('ct' , this );
  }

  @override
  void connect()
  {
    ci1.aPort <= ct.aExport;
    ci2.aPort <= ct.aExport;
  }
}

class ChildInitiator extends Module
{
  late final APort aPort;
  late final GrandChildInitiator gci;

  ChildInitiator( super.name , [super.parent] )
  {
    aPort = APort('aPort',this);
    gci = GrandChildInitiator('gci',this);
  }

  @override
  void connect()
  {
    gci.aPort <= aPort;
  }
}

class GrandChildInitiator extends Module
{
  late final APort aPort;

  GrandChildInitiator( super.name , [super.parent] )
  {
    aPort = APort('aPort',this);
  }

  @override
  Future<void> run() async
  {
    int aVal = aPort.a();

    print('$fullName: a is $aVal');

    expect( -1 , equals( aVal ) );
  }
}

class ChildTarget extends Module
{
  late final APort aExport;
  late final GrandChildTarget gct;

  ChildTarget( super.name , [super.parent] )
  {
    aExport = APort('aExport',this);
    gct = GrandChildTarget('gct',this);
  }

  @override
  void connect()
  {
    aExport.implementedBy( gct );
  }
}

class GrandChildTarget extends NamedComponent implements A
{
  GrandChildTarget( super.name , [super.parent] );

  @override
  int a() => -1;
}
