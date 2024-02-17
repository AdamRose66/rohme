import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

List<(int, int, String)> memoryMap = [
  (0x000, 0x100, 'memPortA'),
  (0x100, 0x200, 'memPortB'),
  (0x400, 0x500, 'memPortC')
];

class Top extends Module {
  late final Initiator initiator;
  late final Router router;
  late final Memory memoryA, memoryB, memoryC;

  Top(super.name, [super.parent]) {
    initiator = Initiator('initiator', this);
    router = Router('router', this, memoryMap);

    memoryA = Memory('memoryA', this, 0x100, fill: -1);
    memoryB = Memory('memoryB', this, 0x100, fill: -1);
    memoryC = MemoryNoDmi('memoryC', this, 0x100, fill: -1);
  }

  @override
  void connect() {
    initiator.memoryPort <= router.targetExport;

    router.initiatorPort('memPortA') <= memoryA.memoryExport;
    router.initiatorPort('memPortB') <= memoryB.memoryExport;
    router.initiatorPort('memPortC') <= memoryC.memoryExport;
  }
}

class Initiator extends Module {
  late final MemoryPort memoryPort;

  Initiator(super.name, [super.parent]) {
    memoryPort = MemoryPort('memoryPort', this);
  }

  @override
  void run() async {
    routerTest();
  }

  Future<void> routerTest() async {
    await testMemIf(memoryPort);

    bool ok = true;
    try {
      await memoryPort.read8(0x6000);
    } on RouterDecodeError catch (e) {
      ok = false;
      print('saw expected exception $e');
    }
    expect(ok, false);

    ok = true;
    try {
      memoryPort.getDmiHint(0x400);
    } on NoDmiHint catch (e) {
      ok = false;
      print('saw expected exception $e');
    }
    expect(ok, false);
  }
}

class MemoryNoDmi extends Memory {
  MemoryNoDmi(super.name, super.parent, super.size,
      {super.duration, super.fill});

  @override
  DmiHint getDmiHint(int addr, [AccessType accessType = AccessType.readWrite]) {
    throw NoDmiHint(name, addr, accessType);
  }
}

void main() {
  group('Memory Tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('router test', () async {
      simulateModel(() {
        return Top('top');
      });
    });

    test('memory test', () async {
      Memory memory = Memory('memory', null, 0x100, fill: -1);
      await testMemIf(memory);
    });
  });
}

Future<void> testMemIf(MemoryIf memoryIf) async {
  int readData = 0;

  await memoryIf.write64(0x10, 0x0123456789abcdef);
  readData = await memoryIf.read64(0x10);

  expect(readData, 0x0123456789abcdef);

  await memoryIf.write32(0x20, 0x01234567);
  readData = await memoryIf.read32(0x20);

  expect(readData, 0x01234567);

  await memoryIf.write16(0x30, 0x0123);
  readData = await memoryIf.read16(0x30);

  expect(readData, 0x0123);

  await memoryIf.write8(0x40, 0xab);
  readData = await memoryIf.read8(0x40);

  expect(readData, 0xab);

  readData = await memoryIf.read8(0x44);
  expect(readData, 0xff);

  DmiHint dmiHint = memoryIf.getDmiHint(0x10);

  expect(dmiHint.adjustedView.read64(0x0), 0x0123456789abcdef);

  bool ok = true;
  try {
    await memoryIf.write64(0x11, 0x0123456789abcdef);
  } on AlignmentError catch (e) {
    ok = false;
    print('saw expected exception $e');
  }
  expect(ok, false);
}
