@
@   Leduc Forth - a simple FORTH compiler/interpreter for the PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (comments)
@

    .include "forth.inc"

    .section .text

    .global _dot_paren
_dot_paren:
    mov r0, #0x29                       @ ASCII '"'
    mov r1, #1                          @ skip leading spaces
    bl __parse
    bl __type
    NEXT