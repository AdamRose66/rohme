# Overview

There are a number of examples in this directory

- fifo_channel_example.dart
- memory_map_example.dart
- timer_example/timer_example.dart
- clock_zone_examples
  - 01_clock_zone_timers_example.dart
  - 02_clock_delay_port_example.dart
  - 03_clock_config_example.dart

# fifo example
fifo_channel_example.dart is a simple producer / consumer arrangement.

# memory map example

memory_map_example.dart has a master connected to a router, which in turn connects to three memory mapped memories. Memory transactions traverse the router and are implemented in the decoded memories.

This example also demonstrates how to fork multiple processes and wait for them to both finish. Since the memory has a mutex on it, the parallel processes are sequentialised by the mutex even though the two threads issuing the memory transactions are running in parallel.

# timer example

The timer example has a memory mapped hardware timer. The registers are 'programmers view accurate' but the hardware timer itself uses an abstract Dart timer in its implementation.

An ISR is connected to a Signal, which triggers each time the hardware 'continuous' timer expires.

# clock zone examples

The three clock zone examples demonstrate different use cases for ClockZones. The first just shows the basic functionality of ClockZones, with the first clock zone dividing the Simulator's clock twice, and the second clock zone dividing the first by another factor of two.

The second clock zone example shows how to use ClockDelayPorts to route a clock across the module hierarchy, while the third example uses the config database to do the clock routing.
