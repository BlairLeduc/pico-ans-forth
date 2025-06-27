@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth String wordset.
@

    .include "forth.S"

    .text



    @   17.6.1.0170 -TRAILING ( c-addr u1 -— c-addr u2 )    "minus-trailing"
    @
    @   If u1 is greater than zero, u2 is equal to u1 less the number of spaces at the end of the character
    @   string specified by c-addr u1. If u1 is zero or the entire string consists of spaces, u2 is zero.

    .global _dash_trailing
    .thumb_func
_dash_trailing:
    popd r1              @ u1 (length)
    popd r0              @ c-addr (address)

    cmp r1, #0
    beq .Lempty_trailing @ If length is zero, return c-addr 0

    add r2, r0, r1       @ r2 = c-addr + u1 (end of string)
    mov r3, #0           @ r3 = count of trailing spaces

.Lloop_trailing:
    cmp r1, #0
    beq .Ldone_trailing
    ldrb r4, [r2, #-1]!  @ r4 = *(--r2)
    cmp r4, #0x20        @ space?
    bne .Ldone_trailing
    add r3, r3, #1       @ count trailing space
    sub r1, r1, #1
    b .Lloop_trailing

.Ldone_trailing:
    pushd r0             @ c-addr
    pushd r1             @ u2 (new length)
    NEXT

.Lempty_trailing:
    pushd r0             @ c-addr
    mov r1, #0
    pushd r1             @ 0
    NEXT


    @   17.6.1.0780 BLANK ( c-addr u -- )
    @
    @   If u is greater than zero, store the character value for space in u consecutive character positions
    @   beginning at c-addr.

    .global _blank
    .thumb_func
_blank:
    popd r1
    popd r2
    mov r0, #0x20                       @ fill with ASCII space (0x20)
    b 1f

    @   6.2.1350    ERASE ( addr u -- )
    @
    @   If u is greater than zero, clear all bits in each of u consecutive address units of memory
    @   beginning at addr.

    .global _erase
    .thumb_func
_erase:
    popd r1
    popd r2
    eor r0, r0                          @ fill with 0x00 
    b 1f

    @   6.1.1540    FILL ( c-addr u char -- )
    @
    @   If u is greater than zero, store char in each of u consecutive characters of memory beginning at
    @   c-addr.

    .global _fill
    .thumb_func
_fill:
    popd r0
    popd r1
    popd r2                             @ byte to fill  
1:  cmp r1, #0
    beq 2f
    strb r0, [r2], #1                   @ store byte to destination, increment
    sub r1, #1
    b 1b
2:  NEXT


    @   6.1.1900    MOVE ( addr1 addr2 u -- )
    @
    @   If u is greater than zero, copy the contents of u consecutive address units at addr1 to the u
    @   consecutive address units at addr2. After MOVE completes, the u consecutive address units at
    @   addr2 contain exactly what the u consecutive address units at addr1 contained before the move.

    .global _move
    .thumb_func
_move:
    popd r1                             @ count (u)
    popd r2                             @ destination addr (addr2)
    popd r0                             @ source addr (addr1)
    bl __move
    NEXT

    .global __move
    .thumb_func
__move:
    push {r4-r5, lr}       @ save registers
    cmp r0, r2              @ compare src and dest
    beq 2f                  @ if equal, nothing to do
    add r4, r0, r1          @ r4 = src + count
    add r5, r2, r1          @ r5 = dest + count
    cmp r2, r0
    blo 1f                  @ if dest < src, copy forward
    cmp r2, r4
    bhs 1f                  @ if dest >= src+count, no overlap, copy forward
    @ Overlap, copy backward
    bl __c_move_up
    pop {r4-r5, pc}
1:  @ Copy forward
    bl __c_move
2:  pop {r4-r5, pc}


    .global _c_move
    .thumb_func
_c_move:
    popd r1                             @ count (u)
    popd r2                             @ destination addr (addr2)
    popd r0                             @ source addr (addr1)
    bl __c_move
    NEXT

    .global __c_move
    .thumb_func
__c_move:
1:  cmp r1, #0
    beq 2f
    ldrb r3, [r0], #1                   @ load byte from source, increment
    strb r3, [r2], #1                   @ store byte to dest, increment
    sub r1, #1
    b 1b
2:  bx lr


    .global _c_move_up
    .thumb_func
_c_move_up:
    popd r1                             @ count (u)
    popd r2                             @ destination addr (addr2)
    popd r0                             @ source addr (addr1)
    bl __c_move_up
    NEXT

    .global __c_move_up
    .thumb_func
__c_move_up:
    add r0, r1
    add r2, r1
1:  cmp r1, #0
    beq 2f
    ldrb r3, [r0, #-1]!                 @ load byte from source, increment
    strb r3, [r2, #-1]!                 @ store byte to dest, increment
    sub r1, #1
    b 1b
2:  bx lr


    @   17.6.1.0245 /STRING ( c-addr1 u1 n -- c-addr2 u2 ) [string]
    @   Advances c-addr1 by n, reduces u1 by n (not below zero).

    .global _slash_string
    .thumb_func
_slash_string:
    popd r2          @ n
    popd r1          @ u1
    popd r0          @ c-addr1

    cmp r2, r1       @ if n > u1, clamp n to u1
    bls 1f
    mov r2, r1
1:  add r0, r0, r2   @ c-addr2 = c-addr1 + n
    sub r1, r1, r2   @ u2 = u1 - n (>= 0)
    pushd r0         @ push c-addr2
    pushd r1         @ push u2
    NEXT
