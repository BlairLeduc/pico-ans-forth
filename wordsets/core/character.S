@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (character)
@

    .include "forth.inc"

    .text

    .global _here
    .thumb_func
_here:
    ldr r0, =var_DP
    ldr r0, [r0]
    pushd r0
    NEXT


    .global _pad
    .thumb_func
_pad:
    ldr r0, =pad_storage
    pushd r0
    NEXT


    .global _blank
    .thumb_func
    .global _erase
    .thumb_func
    .global _fill
    .thumb_func
_blank:
    popd r1
    popd r2
    mov r0, #0x20                       @ fill with ASCII space (0x20)
    b 1f
_erase:
    popd r1
    popd r2
    eor r0, r0                          @ fill with 0x00 
    b 1f
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


    .global _move
    .thumb_func
_move:
    popd r1                             @ count (u)
    popd r2                             @ destination addr (addr2)
    popd r0                             @ source addr (addr1)
    bl __move
    NEXT

    @   Copy a block of bytes from source to destination.
    @   r0 = source address, r1 = count (u), r2 = destination addr
    .global __move
    .thumb_func
__move:
1:  cmp r1, #0
    beq 2f
    ldrb r3, [r0], #1                   @ load byte from source, increment
    strb r3, [r2], #1                   @ store byte to dest, increment
    sub r1, #1
    b 1b
2:  bx lr


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


    .global _word
    .thumb_func
_word:
    popd r0
    bl __word
    pushd r0
    NEXT

    .global __word
    .thumb_func
__word: @ r0 = delimiter (usually space)
    push {r4-r6}

    @ Load all source-related values at once
    movw r4, :lower16:input_source
    movt r4, :upper16:input_source
    ldmia r4, {r4, r5}                  @ r4 = source buffer address, r5 = source size 

    movw r6, :lower16:var_TOIN
    movt r6, :upper16:var_TOIN
    ldr r6, [r6]                        @ r6 = TOIN value

    movw r3, :lower16:var_DP
    movt r3, :upper16:var_DP
    ldr r3, [r3]                        @ r3 = DP value

    add r4, r6                          @ get addr of the parse area
    add r3, #1                          @ skip first byte for length
    eor r1, r1                          @ set word length to 0

    @ Loop for skipping delimiters
1:  cmp r6, r5
    bge 4f
    ldrb r2, [r4], #1
    add r6, #1                          @ increment >IN   
    cmp r2, r0
    beq 1b

    @ Word collection loop
2:  strb r2, [r3], #1
    add r1, #1                          @ increment word length
3:  cmp r6, r5
    bge 4f
    ldrb r2, [r4], #1
    add r6, #1                          @ increment >IN
    cmp r2, r0
    bne 2b

4:  @ Update >IN and create counted string
    movw r3, :lower16:var_TOIN
    movt r3, :upper16:var_TOIN
    str r6, [r3]                        @ store new >IN value

    movw r0, :lower16:var_DP
    movt r0, :upper16:var_DP
    ldr r0, [r0]
    strb r1, [r0]                       @ store length byte

    pop {r4-r6}
    bx lr   @ r0 = address of the word, r1 = length (saves a ldr in the caller)


    @.  6.1.2165    S" “s-quote”
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

    @ compilation state
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

    @ interpretation state
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