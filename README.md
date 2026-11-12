# Conway's Game of Life in RISC-V assembly

Conway's Game of Life written in **RV32I assembly** (about 900 lines), running on a multicycle RISC-V processor with a 12×10 LED display, push buttons and 7-segment displays.

Built for **CS-200 (Computer architecture), EPFL, fall 2026** (Lab A).

## Features

- **Game rules**: underpopulation, overpopulation, reproduction and stasis, on a toroidal grid with walls where no cell can live
- **Double buffering** between two game-state arrays
- **Controls with the buttons**: start / pause, speed up / slow down, number of steps, choice of the starting seed or a random seed
- **7-segment display** of the remaining steps
- Hand-written calling convention, stack management and memory-mapped I/O

## Run

The `Makefile` assembles `gol.s` with the RISC-V GNU toolchain and runs it on the course's Verilator simulator of the Gecko5 board.

```
make
```

## Author

Danny Levy. Lab specification and hardware platform by EPFL (CS-200).
