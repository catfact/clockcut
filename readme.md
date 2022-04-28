# clockcut

simple demonstration of clocked looping / delay with `softcut` on norns

# usage

at present, the demo has no interactive UI. it exposes parameters which are designed for MIDI mapping.

## parameters

- `clock_mul`: multiplied by the clock beat duration to yield loop duration

- `speed_ratio`: speed of the virtual tape, as a ratio

- `speed_tune`: speed tuning offset, in cents

- `rec_level`: level at which input is written to the buffer

- `pre_level`: level at which existing buffer contents are preserved