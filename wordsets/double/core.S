@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Double wordset.
@

    .include "forth.S"

    @   8.6.1.1040  D+ ( d1|ud1 d2|ud2 -- d3|ud3 )      “d-plus”
    @
    @   Add d2|ud2 to d1|ud1, giving the sum d3|ud3.
    
    .global _dadd
    .thumb_func
_dadd:
    popd    r0          @ r0 = low part of first number (d1.lo)
    popd    r1          @ r1 = high part of first number (d1.hi)
    popd    r2          @ r2 = low part of second number (d2.lo)
    popd    r3          @ r3 = high part of second number (d2.hi)

    adds    r4, r0, r2  @ r4 = sum of low parts, set carry
    adc     r5, r1, r3  @ r5 = sum of high parts + carry

    pushd   r5          @ push high part of result
    pushd   r4          @ push low part of result
    NEXT

    @   8.6.1.1050  D- ( d1|ud1 d2|ud2 -- d3|ud3 )      “d-subtract”
    @
    @   Subtract d2|ud2 from d1|ud1, giving the difference d3|ud3.
    .global _dsub
    .thumb_func
_dsub:
    popd    r0          @ r0 = low part of first number (d1.lo)
    popd    r1          @ r1 = high part of first number (d1.hi)
    popd    r2          @ r2 = low part of second number (d2.lo)
    popd    r3          @ r3 = high part of second number (d2.hi)

    subs    r4, r0, r2  @ r4 = low part difference, set carry/borrow
    sbc     r5, r1, r3  @ r5 = high part difference - borrow

    pushd   r5          @ push high part of result
    pushd   r4          @ push low part of result
    NEXT
