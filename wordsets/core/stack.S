@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (stack)
@

    .include "forth.inc"

    .text

    .global _twodrop
    .thumb_func
_twodrop:
    popd r0
    popd r0
    NEXT

    .global _twodup
    .thumb_func
_twodup:
    ldr r0, [r8]
    ldr r1, [r8, #4]
    pushd r1
    pushd r0
    NEXT

    .global _twoover
    .thumb_func
_twoover:
    ldr r0, [r8, #8]
    ldr r1, [r8, #12]
    pushd r1
    pushd r0
    NEXT

    .global _twoswap
    .thumb_func
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
    .thumb_func
_qdup:
    ldr r0, [r8]
    cmp r0, #0
    beq 1f
    pushd r0
1:  NEXT

    .global _depth
    .thumb_func
_depth:
    bl __depth
    pushd r0
    NEXT

    .global __depth
    .thumb_func
__depth:
    movw r0, :lower16:data_stack_top
    movt r0, :upper16:data_stack_top
    sub r0, r8                         @ calculate the depth
    lsr r0, #2                         @ divide by 4 to get the number of elements
    bx lr

    .global _drop
    .thumb_func
_drop:
    popd r0
    NEXT

    .global _dup
    .thumb_func
_dup:
    ldr r0, [r8]
    pushd r0
    NEXT

    .global _over
    .thumb_func
_over:
    ldr r0, [r8, #4]
    pushd r0
    NEXT


    @   6.2.2030 PICK ( xu ... x1 x0 u -- xu ... x1 x0 xu )
    @
    @   Remove u. Copy the xu to the top of the stack. An ambiguous condition exists if there are less
    @   than u+2 items on the stack before PICK is executed.

    .global _pick
    .thumb_func
_pick:
    popd r0                             @ get the index
    lsl r0, #2                          @ convert index to byte offset
    add r1, r8, r0                      @ calculate the address of the element
    ldr r0, [r1]
    pushd r0
    NEXT

    .global _rot
    .thumb_func
_rot:
    popd r0
    popd r1
    popd r2
    pushd r1
    pushd r0
    pushd r2
    NEXT

    .global _nrot
    .thumb_func
_nrot:
    popd r0
    popd r1
    popd r2
    pushd r0
    pushd r2
    pushd r1
    NEXT

    .global _swap
    .thumb_func
_swap:
    popd r0
    popd r1
    pushd r0
    pushd r1
    NEXT


    @   6.1.0010    ! ( x a-addr -- )                   “store”
    @
    @   Store x at a-addr.

    .global _store
    .thumb_func
_store:
    popd r0
    popd r1
    str r1, [r0]
    NEXT


    @   6.1.0130    +! ( n|u a-addr -- )                “plus-store”
    @   
    @   Add n|u to the single-cell number at a-addr.

    .global _addstore
    .thumb_func
_addstore:
    popd r0
    popd r1
    ldr r2, [r0]
    add r2, r1
    str r2, [r0]
    NEXT

    .global _twostore
    .thumb_func
_twostore:
    popd r0
    popd r1
    popd r2
    str r1, [r0]
    str r2, [r0, #4]
    NEXT

    .global _twofetch
    .thumb_func
_twofetch:
    popd r0
    ldr r1, [r0]
    ldr r2, [r0, #4]
    pushd r2
    pushd r1
    NEXT

    .global _fetch
    .thumb_func
_fetch:
    popd r0
    ldr r1, [r0]
    pushd r1
    NEXT

    .global _storebyte
    .thumb_func
_storebyte:
    popd r0
    popd r1
    strb r1, [r0]
    NEXT

    .global _addstorebyte
    .thumb_func
_addstorebyte:
    popd r0
    popd r1
    ldrb r2, [r0]
    add r2, r1
    strb r2, [r0]
    NEXT

    .global _fetchbyte
    .thumb_func
_fetchbyte:
    popd r0
    ldrb r1, [r0]
    pushd r1
    NEXT

    .global _twotor
    .thumb_func
_twotor:
    popd r0
    popd r1
    pushr r1
    pushr r0
    NEXT

    .global _twofromr
    .thumb_func
_twofromr:
    popr r0
    popr r1
    pushd r1
    pushd r0
    NEXT

    .global _tworspfetch
    .thumb_func
_tworspfetch:
    ldr r0, [r6]
    ldr r1, [r6, #4]
    pushd r1
    pushd r0
    NEXT

    .global _tor
    .thumb_func
_tor:
    popd r0
    pushr r0
    NEXT

    .global _fromr
    .thumb_func
_fromr:
    popr r0
    pushd r0
    NEXT

    .global _rspfetch
    .thumb_func
_rspfetch:
    ldr r0, [r6]
    pushd r0
    NEXT

    .global _environmentq
    .thumb_func
_environmentq:
    popd r0                             @ get the address of the string
    popd r1                             @ get the length of the string
    eor r2, r2                          @ clear r2 to zero (dummy value for now)
    pushd r2                            @ push a zero to indicate false
    NEXT
