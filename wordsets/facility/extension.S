@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Facility Extension wordset.
@

    .include "forth.inc"

    .section .text

    .global _emitq
_emitq:
    bl __emit_available
    pushd r0
    NEXT

