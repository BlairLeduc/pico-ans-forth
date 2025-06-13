@
@   Leduc Forth - a simple FORTH compiler/interpreter for the ClockWork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (stack)
@

    .include "forth.inc"

    .section .text

    .global _twodrop
_twodrop:
    popd r0
    popd r0
    NEXT

    .global _twodup
_twodup:
    ldr r0, [r8]
    ldr r1, [r8, #4]
    pushd r1
    pushd r0
    NEXT

    .global _twoover
_twoover:
    ldr r0, [r8, #8]
    ldr r1, [r8, #12]
    pushd r1
    pushd r0
    NEXT

    .global _twoswap
_twoswap:
    popd r0
    popd r1
    popd r2
    popd r3
    pushd r1
    pushd r0
    pushd r3
    pushd r2
    NEXT

    .global _qdup
_qdup:
    ldr r0, [r8]
    cmp r0, #0
    beq 1f
    pushd r0
1:  NEXT

    .global _depth
_depth:
    bl __depth
    pushd r0
    NEXT

    .global __depth
__depth:
    movw r0, :lower16:data_stack_top
    movt r0, :upper16:data_stack_top
    sub r0, r8                         @ calculate the depth
    lsr r0, #2                         @ divide by 4 to get the number of elements
    bx lr

    .global _drop
_drop:
    popd r0
    NEXT

    .global _dup
_dup:
    ldr r0, [r8]
    pushd r0
    NEXT

    .global _over
_over:
    ldr r0, [r8, #4]
    pushd r0
    NEXT


    @   6.2.2030 PICK ( xu ... x1 x0 u -- xu ... x1 x0 xu )
    @
    @   Remove u. Copy the xu to the top of the stack. An ambiguous condition exists if there are less
    @   than u+2 items on the stack before PICK is executed.

    .global _pick
_pick:
    popd r0                             @ get the index
    lsl r0, #2                          @ convert index to byte offset
    add r1, r8, r0                      @ calculate the address of the element
    ldr r0, [r1]
    pushd r0
    NEXT

    .global _rot
_rot:
    popd r0
    popd r1
    popd r2
    pushd r1
    pushd r0
    pushd r2
    NEXT

    .global _nrot
_nrot:
    popd r0
    popd r1
    popd r2
    pushd r0
    pushd r2
    pushd r1
    NEXT

    .global _swap
_swap:
    popd r0
    popd r1
    pushd r0
    pushd r1
    NEXT

    .global _store
_store:
    popd r0
    popd r1
    str r1, [r0]
    NEXT

    .global _addstore
_addstore:
    popd r0
    popd r1
    ldr r2, [r0]
    add r2, r1
    str r2, [r0]
    NEXT

    .global _twostore
_twostore:
    popd r0
    popd r1
    popd r2
    str r1, [r0]
    str r2, [r0, #4]
    NEXT

    .global _twofetch
_twofetch:
    popd r0
    ldr r1, [r0]
    ldr r2, [r0, #4]
    pushd r2
    pushd r1
    NEXT

    .global _fetch
_fetch:
    popd r0
    ldr r1, [r0]
    pushd r1
    NEXT

    .global _storebyte
_storebyte:
    popd r0
    popd r1
    strb r1, [r0]
    NEXT

    .global _addstorebyte
_addstorebyte:
    popd r0
    popd r1
    ldrb r2, [r0]
    add r2, r1
    strb r2, [r0]
    NEXT

    .global _fetchbyte
_fetchbyte:
    popd r0
    ldrb r1, [r0]
    pushd r1
    NEXT

    .global _twotor
_twotor:
    popd r0
    popd r1
    pushr r1
    pushr r0
    NEXT

    .global _twofromr
_twofromr:
    popr r0
    popr r1
    pushd r1
    pushd r0
    NEXT

    .global _tworspfetch
_tworspfetch:
    ldr r0, [r6]
    ldr r1, [r6, #4]
    pushd r1
    pushd r0
    NEXT

    .global _tor
_tor:
    popd r0
    pushr r0
    NEXT

    .global _fromr
_fromr:
    popr r0
    pushd r0
    NEXT

    .global _rspfetch
_rspfetch:
    ldr r0, [r6]
    pushd r0
    NEXT

    .global _environmentq
_environmentq:
    popd r0                             @ get the address of the string
    popd r1                             @ get the length of the string
    eor r2, r2                          @ clear r2 to zero (dummy value for now)
    pushd r2                            @ push a zero to indicate false
    NEXT
