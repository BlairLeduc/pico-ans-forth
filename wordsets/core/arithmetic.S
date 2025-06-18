@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the ANS Forth Core workset (arithmetic)
@   See 2.2.1 Arithmetic and Shift Operators (FPH, p54)
@

    .include "forth.inc"

    .text


    @   6.1.0090    * ( n1|u1 n2|u2 -- n3|u3 )          “star”
    @
    @   Multiply n1|u1 by n2|u2 giving the product n3|u3.

    .global _mul
    .thumb_func
_mul:
    popd r0
    popd r1
    mul r0, r1, r0
    pushd r0
    NEXT


    @   6.1.0120    + ( n1|u1 n2|u2 -- n3|u3 )          “plus”
    @
    @   Add n2|u2 to n1|u1, giving the sum n3|u3.

    .global _add
    .thumb_func
_add:
    popd r0
    popd r1
    add r0, r1
    pushd r0
    NEXT


    @   6.1.0160    - ( n1|u1 n2|u2 -- n3|u3 )          “minus”
    @   
    @   Subtract n2|u2 from n1|u1, giving the difference n3|u3.

    .global _sub
    .thumb_func
_sub:
    popd r0
    popd r1
    sub r0, r1, r0
    pushd r0
    NEXT


    @   6.1.0240    /MOD ( n1 n2 -- n3 n4 )             “slash-mod”
    @   
    @   Divide n1 by n2, giving the single-cell remainder n3 and the single-cell quotient n4. An
    @   ambiguous condition exists if n2 is zero. If n1 and n2 differ in sign, the implementation-defined
    @   result returned will be the same as that returned by either the phrase >R S>D R> FM/MOD or
    @   the phrase >R S>D R> SM/REM.

    .global _slash_mod
    .thumb_func
_slash_mod:
    popd r0                             @ get the divisor
    popd r1                             @ get dividend
    cmp r0, #0                          @ check for division by zero
    beq 1f                              @ if zero, branch to error

    sdiv r2, r1, r0                     @ r2 = quotient
    mul  r3, r2, r0                     @ r3 = quotient * divisor
    sub  r3, r1, r3                     @ r3 = dividend - (quotient * divisor) = remainder

    pushd r3                            @ push the remainder
    pushd r2                            @ push the quotient
    NEXT

1:                                      @ Divide by zero error
    mov r0, #ERR_DIVISION_BY_ZERO
    bl __throw
    NEXT


    .global _incr
    .thumb_func
_incr:
    popd r0
    add r0, #1
    pushd r0
    NEXT

    .global _decr
    .thumb_func
_decr:
    popd r0
    sub r0, #1
    pushd r0
    NEXT

    .global _incr2
    .thumb_func
_incr2:
    popd r0
    add r0, #2
    pushd r0
    NEXT

    .global _decr2
    .thumb_func
_decr2:
    popd r0
    sub r0, #2
    pushd r0
    NEXT

    .global _twomul
    .thumb_func
_twomul:
    popd r0
    lsl r0, r0, #1                      @ multiply by 2
    pushd r0
    NEXT

    .global _twodiv
    .thumb_func
_twodiv:
    popd r0
    asr r0, r0, #1                      @ divide by 2 (arithmetic shift)
    pushd r0
    NEXT

    .global _incr4
    .thumb_func
_incr4:
    popd r0
    add r0, #4
    pushd r0
    NEXT

    .global _decr4
    .thumb_func
_decr4:
    popd r0
    sub r0, #4                          @ decrement the address by 4 (size of a cell)
    pushd r0
    NEXT

    .global _cell_incr
    .thumb_func
_cell_incr:
    popd r0
    add r0, r0, #4                      @ increment the address by 4 (size of a cell)
    pushd r0
    NEXT

    .global _cells
    .thumb_func
_cells:
    popd r0
    lsl r0, r0, #2                      @ multiply by 4 (size of a cell)
    pushd r0
    NEXT

    .global _char_incr
    .thumb_func
_char_incr:
    popd r0
    add r0, r0, #1                      @ increment the address by 1 (size of a character)
    pushd r0
    NEXT

    .global _lshift
    .thumb_func
_lshift:
    popd r0                             @ get the value to shift
    cmp r0, #0                          @ check for zero shift
    beq 1f                              @ if zero, branch to no-op
    cmp r0, #32                         @ check for shift greater than 31
    bge 1f                              @ if greater than or equal to 32, branch to no-op
    popd r1                             @ get the number of bits to shift
    lsl r1, r0                          @ shift left
    pushd r1                            @ push the result on to the stack
1:  NEXT

    .global _rshift
    .thumb_func
_rshift:
    popd r0                             @ get the value to shift
    cmp r0, #0                          @ check for zero shift
    beq 1f                              @ if zero, branch to no-op
    cmp r0, #32                         @ check for shift greater than 31
    bge 1f                              @ if greater than or equal to 32, branch to no-op
    popd r1                             @ get the number of bits to shift
    lsr r1, r0                          @ shift right (arithmetic shift)
    pushd r1                            @ push the result on to the stack
1:  NEXT

    .global _udivmod
    .thumb_func
_udivmod:
    popd r0                             @ get the divisor
    popd r1                             @ get the dividend
    cmp r0, #0                          @ check for division by zero
    beq 1f                              @ if zero, branch to error

    udiv r2, r1, r0                     @ unsigned divide
    mul r3, r2, r0                      @ multiply
    sub r3, r1, r3                      @ subtract to get remainder

    pushd r3                            @ push the remainder
    pushd r2                            @ push the quotient
    NEXT
1:                                      @ Divide by zero error  
    mov r0, #ERR_DIVISION_BY_ZERO
    bl __throw
    NEXT

