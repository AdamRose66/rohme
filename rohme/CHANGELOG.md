## 1.0.0

- Initial version.

## 1.0.1

- Changes to Register Classes

Introduced RegisterWithOverlaps to allow C style struct/union overlapping access
Registers with Fields now only write to/read from the bits specified by the
combined masks of the Fields ( subject to AccessType ).
