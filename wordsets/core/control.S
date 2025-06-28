@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (control)
@   See 2.5 PROGRAM STRUCTURES (FPH, p59)

    .include "forth.S"

    .text


    .global _unloop
    .thumb_func
_unloop:
    add r6, #8
    NEXT

    .global _index_i
    .thumb_func
_index_i:
    ldr r0, [r6, #4]
    pushd r0
    NEXT

    .global _index_j
    .thumb_func
_index_j:
    ldr r0, [r6, #12]
    pushd r0
    NEXT
