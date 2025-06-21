@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (character)
@

    .include "forth.inc"

    .text


    .global _bl
    .thumb_func
_bl:
    mov r0, #0x20                       @ ASCII space (0x20)
    pushd r0
    NEXT


    .global _count
    .thumb_func
_count:
    popd r0
    ldrb r1, [r0], #1
    pushd r0
    pushd r1
    NEXT


    @   6.1.2165    S" “s-quote”
    @
    @   Compilation: ( “ccc<quote>” -- )
    @       Parse ccc delimited by " (double-quote). Append the run-time semantics given below to the
    @       current definition.
    @   Run-time: ( -- c-addr u )
    @       Return c-addr and u describing a string consisting of the characters ccc. A program shall not
    @       alter the returned string.

    .global _s_quote
    .thumb_func
_s_quote:
    mov r0, #0x22                       @ ASCII '"'
    eor r1, r1                          @ skip leading spaces
    bl __parse
    ldr r3, =var_STATE
    ldr r3, [r3]                        @ get the current state
    cmp r3, #0
    beq 1f                              @ if in interpretation state, just return the string  

    @ compilation
    ldr r2, =var_DP
    ldr r2, [r2]                        @ get the current DP value
    ldr r3, =S_LIT
    str r3, [r2], #4                    @ store SLITERAL
    str r1, [r2], #4                    @ store the string length
    push {r1-r2}                        @ save the string length
    bl __move                           @ move the string from the parse area
    pop {r1-r2}                         @ restore the string length
    add r2, r1
    add r2, #3
    and r2, #~3                         @ align the length to 4 bytes
    ldr r3, =var_DP
    str r2, [r3]                        @ update DP
    NEXT

    @ run-time
1:  movw r2, :lower16:s_quoted_string_buffer
    movt r2, :upper16:s_quoted_string_buffer
    pushd r2
    pushd r1
    bl __move
    NEXT


    @   6.1.0190    ."                                  “dot-quote”
    @   
    @   Compilation: ( “ccc<quote>” -- )
    @       Parse ccc delimited by " (double-quote). Append the run-time semantics given below to the
    @       current definition.
    @   Run-time: ( -- )
    @       Display ccc.

    .global _dot_quote
    .thumb_func
_dot_quote:
    mov r0, #0x22                       @ ASCII '"'
    eor r1, r1                          @ skip leading spaces
    bl __parse
    ldr r3, =var_STATE
    ldr r3, [r3]                        @ get the current state
    cmp r3, #0
    beq 1f                              @ if in interpretation state, just return the string  
    
    @ compilation
    ldr r2, =var_DP
    ldr r2, [r2]                        @ get the current DP value
    ldr r3, =S_LIT
    str r3, [r2], #4                    @ store SLITERAL
    str r1, [r2], #4                    @ store the string length
    push {r1-r2}                        @ save the string length
    bl __move                           @ move the string from the parse area
    pop {r1-r2}                         @ restore the string length
    add r2, r1
    add r2, #3
    and r2, #~3                         @ align the length to 4 bytes
    ldr r3, =TYPE
    str r3, [r2], #4                    @ store TYPE
    ldr r3, =var_DP
    str r2, [r3]                        @ update DP
    NEXT

    @ run-time
1:  bl __type
    NEXT