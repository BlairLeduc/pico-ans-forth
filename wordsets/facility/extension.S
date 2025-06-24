@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Facility Extension wordset.
@

    .include "forth.S"

    .text

    .global _emitq
    .thumb_func
_emitq:
    bl __emit_available
    pushd r0
    NEXT

