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

RegisterMap registerMap = RegisterMap('map');

void main() async {
  group('A group of tests', () {
    setUp(() {});

    test('simple register test', () async {
      Register rmapR0 = registerMap.addRegister('r0', 0x100);

      rmapR0.addField('a', (0, 2));
      rmapR0.addField('b', (4, 9));
      rmapR0.addField('c', (31, 32));

      registerMap[0x100].write(0x1234);
      Register r0 = registerMap.getByName('r0');

      print('$r0');
      expect(r0.peek(), 0x1234 & 0x1f3);

      bool ok;

      ok = true;
      try {
        // ignore: unused_local_variable
        Register r1 = registerMap[0x9a];
      } on TypeError catch (e) {
        print('expected Error $e');
        ok = false;
      }
      expect(ok, false);

      ok = true;
      try {
        // ignore: unused_local_variable
        Register r2 = registerMap.getByName('r2');
      } on TypeError catch (e) {
        print('expected Error $e');
        ok = false;
      }
      expect(ok, false);

      Register r1 =
          registerMap.addRegister('r1', 0x200, initialValue: 0xffffffff);

      registerMap[0x200].write(0x5678);
      expect(registerMap[0x200].peek(), 0x5678);

      registerMap.reset();

      print('$r1');
      expect(registerMap[0x100].peek(), 0);
      expect(registerMap[0x200].peek(), 0xffffffff);

      int count = 0;
      for (int? addr = registerMap.map.firstKeyAfter(0x99);
          addr != null && addr < 0x180;
          addr = registerMap.map.firstKeyAfter(addr), count++) {
        print('${addr.hex()} : ${registerMap[addr]}');
      }

      expect(count, 1);
    });
  });
}
