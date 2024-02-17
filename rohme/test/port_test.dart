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

abstract interface class A {
  int a();
}

abstract interface class B {
  int b();
}

abstract interface class Combined implements A, B {}

class AProxy implements A {
  @override
  int a() => aFunc();

  late final int Function() aFunc;
}

abstract interface class D {
  int d();
}

class Component implements Combined {
  @override
  int a() => 0;

  @override
  int b() => 1;
}

class OtherComponent {
  int c() => 2;
  int d() => 3;

  AProxy cProxy = AProxy();
  AProxy dProxy = AProxy();

  OtherComponent() {
    cProxy.aFunc = () {
      return c();
    };
    dProxy.aFunc = () {
      return d();
    };
  }
}

class APort extends Port<A> implements A {
  APort(super.name, [super.parent]);
}

void main() {
  test('port_combined_test', () {
    Component component = Component();
    Port<Combined> pCombined = Port('pCombined');
    APort pA2 = APort('pA2');
    Port<A> pA1 = Port('pA1');

    pA2 <= pA1;
    pA1 <= pCombined;

    pCombined.implementedBy(component);

    pA2.doConnections();

    expect(1, equals(pCombined.portIf.b()));
    expect(0, equals(pA1.portIf.a()));
    expect(0, equals(pA2.a()));
  });
  test('port_proxy_test', () {
    OtherComponent otherComponent = OtherComponent();
    APort pA2c = APort('pA2c');
    APort pA2d = APort('pA2c');

    pA2c.implementedBy(otherComponent.cProxy);
    pA2d.implementedBy(otherComponent.dProxy);

    pA2c.doConnections();
    pA2d.doConnections();

    expect(2, equals(pA2c.a()));
    expect(3, equals(pA2d.a()));
  });
  test('connection error', () {
    bool ok = true;
    try {
      Port<A> aPort = Port('a');
      aPort.portIf.a();
    } on ProbableConnectionError catch (e) {
      print('expected error $e');
      ok = false;
    }
    expect(ok, false);
  });
}
