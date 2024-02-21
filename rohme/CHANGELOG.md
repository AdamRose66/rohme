## 1.0.0

- Initial version.

## 1.0.1

- Changes to Register Classes

Introduced RegisterWithOverlaps to allow C style struct/union overlapping access
Registers with Fields now only write to/read from the bits specified by the
combined masks of the Fields ( subject to AccessType ).

## 1.1.0

- Register API is now read/write, peek poke
- use Simulator/SimDuration rather than FakeAsync/Duration

## 1.1.1

- added ClockZone and associated examples

## 1.1.2

- switched Simulator to use queueMap, microtasks now respect delta cycles
