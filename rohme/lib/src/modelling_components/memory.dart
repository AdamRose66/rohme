/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import '../modelling.dart';
import '../primitives/semaphore.dart';
import '../primitives/access_type.dart';
import '../utils.dart';

import 'memory_if.dart';
import 'bus_data.dart';

/// This Module is a memory 'one page' memory
///
/// It has an export and implements the interface, to enable either <= or
/// 'implementedBy' style connectivity.
///
/// The implementation uses [BusData], which is allocated lazily.
///
class Memory extends Module implements MemoryIf {
  /// an export to allow <= style connections
  late final Port<MemoryIf> memoryExport;

  /// the size of the memory
  final int size;

  /// the initial 64 bit fill pattern of this memory.
  ///
  /// null is interpreted as zero.
  final int? fill;

  /// An optional duration, applied to each read or write
  final Duration? duration;

  /// A mutex to control access for non-null delays
  late final Mutex? _mutex;

  /// The actual storage ( lazily created )
  BusData? _storage;

  bool debug = false;

  Memory(super.name, super.parent, this.size,
      {this.duration = const Duration(microseconds: 10),
      this.fill,
      this.debug = false}) {
    memoryExport = Port('memoryExport', this);
    _mutex = (duration == null) ? null : Mutex(fullName);

    memoryExport.implementedBy(this);
  }

  /// writes 64 bit [data] to an 8 byte aligned address
  @override
  Future<void> write64(int addr, int data) async {
    if (_mutex != null) await _mutex.lock();
    if (duration != null) await Future.delayed(duration!);
    _busData.write64(addr, data);
    _debugWriteTransaction(addr, data, 64);
    if (_mutex != null) await _mutex.unlock();
  }

  /// Returns 64 bit data from an 8 byte aligned address
  @override
  Future<int> read64(int addr) async {
    if (_mutex != null) await _mutex.lock();
    if (duration != null) await Future.delayed(duration!);
    int data = _busData.read64(addr);
    _debugReadTransaction(addr, data, 64);
    if (_mutex != null) await _mutex.unlock();
    return data;
  }

  /// writes 32 bit [data] to an 4 byte aligned address
  @override
  Future<void> write32(int addr, int data) async {
    if (_mutex != null) await _mutex.lock();
    if (duration != null) await Future.delayed(duration!);
    _busData.write32(addr, data);
    _debugWriteTransaction(addr, data, 32);
    if (_mutex != null) await _mutex.unlock();
  }

  /// Returns 32 bit data from a 4 byte aligned address
  @override
  Future<int> read32(int addr) async {
    if (_mutex != null) await _mutex.lock();
    if (duration != null) await Future.delayed(duration!);
    int data = _busData.read32(addr);
    _debugReadTransaction(addr, data, 32);
    if (_mutex != null) await _mutex.unlock();
    return data;
  }

  /// writes 16 bit [data] to an 2 byte aligned address
  @override
  Future<void> write16(int addr, int data) async {
    if (_mutex != null) await _mutex.lock();
    if (duration != null) await Future.delayed(duration!);
    _busData.write16(addr, data);
    _debugWriteTransaction(addr, data, 16);
    if (_mutex != null) await _mutex.unlock();
  }

  /// Returns 16 bit data from a 2 byte aligned address
  @override
  Future<int> read16(int addr) async {
    if (_mutex != null) await _mutex.lock();
    if (duration != null) await Future.delayed(duration!);
    int data = _busData.read16(addr);
    _debugReadTransaction(addr, data, 16);
    if (_mutex != null) await _mutex.unlock();
    return data;
  }

  /// writes 8 bit [data] to [addr]
  @override
  Future<void> write8(int addr, int data) async {
    if (_mutex != null) await _mutex.lock();
    if (duration != null) await Future.delayed(duration!);
    _busData.write8(addr, data);
    _debugWriteTransaction(addr, data, 8);
    if (_mutex != null) await _mutex.unlock();
  }

  /// Returns 8 bit data from [addr]
  @override
  Future<int> read8(int addr) async {
    if (_mutex != null) await _mutex.lock();
    if (duration != null) await Future.delayed(duration!);
    int data = _busData.read8(addr);
    _debugReadTransaction(addr, data, 8);
    if (_mutex != null) await _mutex.unlock();
    return data;
  }

  /// get a DmiHint from [addr].
  ///
  /// The availability of the hint may depend on the [accessType]
  ///
  @override
  DmiHint getDmiHint(int addr, [AccessType accessType = AccessType.readWrite]) {
    return _busData.getDmiHint(addr, accessType);
  }

  /// A lazy getter for _busData
  BusData get _busData {
    if (_storage == null) {
      _storage = BusData(size);

      if (fill != null) {
        for (int i = 0; i < _storage!.byteData.lengthInBytes; i += 8) {
          _storage!.byteData.setUint64(i, fill!);
        }
      }
    }

    return _storage!;
  }

  void _debugReadTransaction(int addr, int data, int bits) {
    // ignore: unnecessary_brace_in_string_interps
    if (debug)
      mPrint('just read ${bits} bit ${data.hex()} from address ${addr.hex()}');
  }

  void _debugWriteTransaction(int addr, int data, int bits) {
    // ignore: unnecessary_brace_in_string_interps
    if (debug)
      mPrint('just wrote ${bits} bit ${data.hex()} to address ${addr.hex()}');
  }
}
