# Pico ANS Forth

This hobby project is ANS Forth for the [Raspberry Pi Pico 2 (W)](https://www.raspberrypi.com/products/raspberry-pi-pico-2/).

> The goal of this project is my personal exploration, development, and enrichment. I wish to learn more about TILs and ANS Forth is the specification that I am targeting.

This is not intended for the embedded Forth use case. There are many TILs out there that are better suited for this.

## Projected Features

I hope to get to a point in this project where:

- Meets the ANS "Standard" Forth specification (ANSI X3.215-1994)
  - 32-bit cells, byte addressing
  - 8-bit characters
  - two's complement maths
  - symetric division
- Majority written in Arm assembly language for the Cortex-M33
- Fixed storage in the on-board flash using the Block wordset
- Removable storage on a SD Card (FAT32) using the File-Access wordset
- Internet connectivity

## Influences

The "starter" of this project is [Jones Forth](http://annexia.org/forth) by Richard W.M. Jones and codescribe's [consistent version](https://github.com/codescribe/jonesforth) of the same. The commentary within Jones Forth source may provide some basis of understanding, although much has changed.

The references listed below set the direction after the primordial work.

## Required Hardware

A [Raspberry Pi Pico or Pico 2](https://www.raspberrypi.com/products/raspberry-pi-pico-2/) and a [Raspbery Pi Debug Probe](https://www.raspberrypi.com/products/debug-probe/).

## Development

When debugging, I use [VS Code](https://code.visualstudio.com) and the [Raspberry Pi Pico](https://marketplace.visualstudio.com/items?itemName=raspberry-pi.raspberry-pi-pico) extension.

I am using [Raspberry Pi Pico 2 W](https://www.raspberrypi.com/products/raspberry-pi-pico-2/) in a breadboard with the [debug probe](https://www.raspberrypi.com/products/debug-probe/) connected (debug and uart) as documented.

## Status

I have implemented words from the core and tools wordsets, and I am starting the implementation of defining words.

## Roadmap

My current plan:

- The ANS Forth compiler and text interpreper
- The Core wordset (with many core extensions) and the Tools wordset (no extensions)
- The Exception wordset with extensions
- The Block wordset with extensions (used for flash storage)
- The File-Access wordset with extensions (used for SD storage)
- The Facility wordset with extensions
- The Search-Order wordset with extensions

Of course, there should be more to this roadmap, but I feel this will get me to the point for deciding next steps.

## References

The references listed here is what I am using to create this version of Forth.

- [Threaded Interpreted Languages: Their Design and Implementation](https://archive.org/details/R.G.LoeligerThreadedInterpretiveLanguagesTheirDesignAndImplementationByteBooks1981) by R.G. Loeliger
- [Forth Programmer's Handbook](https://www.forth.com/forth-books/) by Conklin and Rather
- [The final draft (1994) of the ANS Forth standard](http://www.taygeta.com/forth/dpans.html)
