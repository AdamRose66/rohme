This is ROHME ( Rapid Object orientated Hardware Modeling Environment ).
Its immediate inspiration was Rohd, but it also uses ideas from SystemC,
SystemVerilog/UVM, and CoCoTB.

The idea is to take advantage of Dart's language capabilities to create a
modeling Environment for Digital Systems.

It may well be that the implementation is folded into Rohd at some point
in the not-too-distant future.

## Features

- Hierarchical Modules
- Module aware Ports ( ie, interface proxies ) that allow direct remote calling
of abstract interfaces across the module hierarchy
- Timing: Clocks
- Communication: Signal, Fifos, Mutex
- Register and RegisterMap

## Getting started

See the three examples in the examples directory.

One is a simple consumer / producer arrangement talking across a fifo.
There is an initiator -> router -> target arrangement which mimics a simple
processor + memory architecture.
And there is a timer example that uses SimClock, Signal and RegisterMap.

## Usage

Here is the asynchronous run method from the publisher in
examples/fifo_channel_example.dart:

```dart
void run() async
{
  mPrint('run');
  for( int i = 0; i < 10; i++ )
  {
    mPrint('about to put $i');
    await putPort.put( i );
    await Future.delayed( Duration( microseconds : 10 ) );
  }
}
```

There are two asynchronous calls in the loop. The first waits until there is
room in the fifo attached to the putPort before completing. The second
interacts with the scheduler to wait 10 microseconds before continuing.

Here is the connect method from examples/memory_map_test.dart:

```dart
void connect()
{
  initiator.memoryPort <= router.targetExport;

  router.initiatorPort('memPortA') <= memoryA.memoryExport;
  router.initiatorPort('memPortB') <= memoryB.memoryExport;
  router.initiatorPort('memPortC') <= memoryC.memoryExport;
}
```

The initiator ( aka master or processor model ) connects to the router, and
the router connects to each of the memories in this simple system. We use <= to
connect a Port that requires an interface to a Port that provides it.

Here is the code in the timer example that interacts with the register map:
```dart
const loops = 3;
const clocksPerLoop = 10;

registerMap[0x0].value = clocksPerLoop;
registerMap[0x4]['CONTINUOUS'].value = 1;
registerMap[0x4]['START'].value = 1;

Future.delayed( clock.clockPeriod *  clocksPerLoop * loops , () {
  registerMap[0x4]['STOP'].value = 1;
  mPrint('${registerMap[0x8].value} timer loops have expired');
} );
```
The code above sets up the time to do fire continuously, and after 3 loops,
it stops the timer.

And here is how the timer example connects an interrupt controller to the timer:

```dart
void connect()
{
  ...
  timerIrq.alwaysAt( ( signal ) { interrupt(); } , posEdge );
}

Future<void> interrupt() async
{
  mPrint('interrupt');
  for( int i = 0; i < 4; i++ , memoryWriteAddress += 4 )
  {
    await memory.write32( memoryWriteAddress , i );
    mPrint('  just written ${i.hex()} to ${memoryWriteAddress.hex()}');
  }
}
```

So whenever the timer fires, it writes another 4 words to memory.
