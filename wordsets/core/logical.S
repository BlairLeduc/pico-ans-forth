@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (logical)
@   See 2.2.2 Logical and Relational Operations (FPH, p44)

    .include "forth.inc"

    .text

    .global _abs
    .thumb_func
_abs:
    popd r0
    cmp r0, #0
    it lt                               @ if n >= 0, then +n = n
    rsblt r0, r0, #0                    @ Negate the signed number
    pushd r0
    NEXT

    .global _and
    .thumb_func
_and:
    popd r0
    popd r1
    and r0, r1
    pushd r0
    NEXT

    .global _invert
    .thumb_func
_invert:
    popd r0
    mvn r0, r0
    pushd r0
    NEXT

    .global _max
    .thumb_func
_max:
    popd r0
    popd r1
    cmp r0, r1
    ite ge
    movge r0, r0                        @ if n1 >= n2, then n3 = n1
    movlt r0, r1                        @ if n1 < n2, then n3 = n2
    pushd r0
    NEXT

    .global _min
    .thumb_func
_min:
    popd r0
    popd r1
    cmp r0, r1
    ite le
    movle r0, r0                        @ if n1 <= n2, then n3 = n1   
    movgt r0, r1                        @ if n1 > n2, then n3 = n2    
    pushd r0
    NEXT

    .global _negate
    .thumb_func
_negate:
    popd r0
    rsb r0, r0, #0                      @ Negate the signed number
    pushd r0
    NEXT

    .global _or
    .thumb_func
_or:
    popd r0
    popd r1
    orr r0, r1
    pushd r0
    NEXT

    .global _within
    .thumb_func
_within:
    popd r0                             @ high
    popd r1                             @ low
    popd r2                             @ test
    cmp r2, r1                          @ compare test with low
    blt 1f                              @ if test < low, return false
    cmp r2, r0                          @ compare test with high
    bge 1f                              @ if test >= high, return false
    mov r0, #-1                         @ return true (-1)
    b 2f
1:  mov r0, #0                          @ return false (0)
2:  pushd r0                            @ push the flag
    NEXT

    .global _xor
    .thumb_func
_xor:
    popd r0
    popd r1
    eor r0, r1
    pushd r0
    NEXT

    .global _zlt
    .thumb_func
_zlt:
    popd r0
    cmp r0, #0
    ite lt
    movlt r0, #-1
    movge r0, #0
    pushd r0
    NEXT

    .global _znequ
    .thumb_func
_znequ:
    popd r0
    cmp r0, #0
    ite ne
    movne r0, #-1
    moveq r0, #0
    pushd r0
    NEXT

    .global _zequ
    .thumb_func
_zequ:
    popd r0
    cmp r0, #0
    ite eq
    moveq r0, #-1
    movne r0, #0
    pushd r0
    NEXT

    .global _zgt
    .thumb_func
_zgt:
    popd r0
    cmp r0, #0
    ite gt
    movgt r0, #-1
    movle r0, #0
    pushd r0
    NEXT

    .global _lt
    .thumb_func
_lt:
    popd r0
    popd r1
    cmp r1, r0
    ite lt
    movlt r0, #-1
    movge r0, #0
    pushd r0
    NEXT

    .global _nequ
    .thumb_func
_nequ:
    popd r0
    popd r1
    cmp r0, r1
    ite ne
    movne r0, #-1
    moveq r0, #0
    pushd r0
    NEXT

    .global _equ
    .thumb_func
_equ:
    popd r0
    popd r1
    cmp r0, r1
    ite eq
    moveq r0, #-1
    movne r0, #0
    pushd r0  
    NEXT

    .global _gt
    .thumb_func
_gt:
    popd r0
    popd r1
    cmp r1, r0
    ite gt
    movgt r0, #-1
    movle r0, #0
    pushd r0
    NEXT

    .global _false
    .thumb_func
_false:
    mov r0, #0
    pushd r0
    NEXT

    .global _true
    .thumb_func
_true:
    mov r0, #-1
    pushd r0
    NEXT

    .global _ult
    .thumb_func
_ult:
    popd r0
    popd r1
    cmp r1, r0
    ite lo
    movlo r0, #-1
    movhs r0, #0
    pushd r0
    NEXT

    .global _ugt
    .thumb_func
_ugt:
    popd r0
    popd r1
    cmp r1, r0
    ite hi
    movhi r0, #-1
    movls r0, #0
    pushd r0
    NEXT
