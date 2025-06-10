@
@   Leduc Forth - a simple FORTH compiler/interpreter for the PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (onput-output)
@   See 3.3 SERIAL I/O (FPH, p81)

    .include "forth.inc"

    .section .text

    .global _accept
_accept:
    popd r1
    popd r0
    bl __accept
    pushd r0
    NEXT

    .global _key
_key:
    bl __key
    pushd r0
    NEXT

    .global _emit
_emit:
    popd r0
    bl __emit
    NEXT

    .global _type
_type:
    popd r1
    popd r0
    bl __type
    NEXT

    .global _cr
_cr:
    bl __cr
    NEXT

    .global __cr
__cr:
    push {lr}
    mov r0, #0x0d                       @ ASCII carriage return (0x0d)
    bl __emit
    pop {pc}

    .global _space
_space:
    mov r0, #0x20                       @ ASCII space (0x20)
    bl __emit
    NEXT

    .global _spaces
_spaces:
    push {r4}
    popd r4                             @ get the number of spaces (u)
1:  cmp r4, #0
    beq 2f
    mov r0, #0x20                       @ ASCII space (0x20)
    bl __emit                           @ emit the space character
    sub r4, #1
    b 1b                                @ repeat until all spaces are emitted
2:  pop {r4}
    NEXT

