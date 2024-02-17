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

void main() {
  test('simple_test', () {
    config['test'] = true;
    bool test = getConfig('test');
    expect(true, equals(test));
  });
  test('wrong_name_test', () {
    bool success = true;
    try {
      bool test1 = getConfig('test1');
      test1;
    } catch (e) {
      success = false;
      print('$e');
    }
    expect(false, equals(success));
  });
  test('wrong_type_test', () {
    bool success = true;
    try {
      int test1 = getConfig('test');
      test1;
    } catch (e) {
      success = false;
      print('$e');
    }
    expect(false, equals(success));
  });
  test('function_test', () {
    config['a.c'] = (int n) {
      print('config says $n');
      return n;
    };

    int n = getConfig<int Function(int)>('a.c')(3);
    expect(3, equals(n));
  });
  test('default_value_test', () {
    int i = getConfig<int>('la.la.land', defaultValue: 7);

    print('default value is $i');
    expect(7, equals(i));
  });
  test('nothing_test', () {
    config['nothing'] = null;

    Object? nothingOk = getConfigNullable('nothing');

    print('nothing is $nothingOk');

    bool success = true;
    try {
      Object nothingNotOk = getConfig('nothing');
      nothingNotOk;
    } catch (e) {
      success = false;
      print('$e');
    }
    expect(false, equals(success));
  });
}
