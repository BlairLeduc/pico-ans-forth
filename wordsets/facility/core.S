@
@   Leduc Forth - a simple FORTH compiler/interpreter for the ClockWork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Facility wordset.
@

    .include "forth.inc"

    .section .text

    .global _keyq
_keyq:
    bl __key_available
    pushd r0
    NEXT
