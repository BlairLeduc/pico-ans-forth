@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@

    .include "forth.S"
    
    .text

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


    .global _parse_word
    .thumb_func
_parse_word:
    mov r0, #0x20                       @ space delimiter
    mov r1, #1
    bl __parse                          @ skip initial delimiters
    pushd r0
    pushd r1
    NEXT

    .global _parse
    .thumb_func
_parse:
    popd r0                             @ delimiter
    eor r1, r1                          @ don't skip initial delimiters
    bl __parse
    pushd r0
    pushd r1
    NEXT

    .global __parse
    .thumb_func
__parse: @ r0 = delimiter, r1 = skip initial spaces
    push {r4-r7}

    movw r4, :lower16:input_source
    movt r4, :upper16:input_source
    ldmia r4, {r4, r5}                  @ r4 = source buffer address, r5 = source size 
        
    movw r6, :lower16:var_TOIN
    movt r6, :upper16:var_TOIN
    ldr r6, [r6]                        @ position in source

    add r4, r6                          @ get addr of the parse area
    mov r7, r4                          @ save address of the parse area
    mov r3, r1
    eor r1, r1                          @ set word length to 0

1:  cmp r3, #0                          @ check if we are skipping initial delimiters
    beq 4f

2:  cmp r6, r5                          @ have we reached the end of the source?
    bge 6f
    ldrb r2, [r4], #1                   @ load the next character from the source
    add r6, #1                          @ increment the position
    add r7, #1                          @ increment the parse area pointer
    cmp r2, #32                         @ is it a space?
    beq 2b                              @ if so, branch to skip initial delimiters

    sub r7, #1                          @ adjust for delimiter
    add r1, #1                          @ increment word length

3:  @ Scan the input buffer looked for the end of the word
4:  cmp r6, r5                          @ have we reached the end of the source?
    bge 5f                              @ if so, exit
    ldrb r2, [r4], #1
    add r6, #1                          @ increment >IN
    add r1, #1
    cmp r2, r0                          @ is it a delimiter?
    bne 3b                              @ if not, continue scanning

5:  sub r1, #1                          @ adjust for delimiter
6:  movw r3, :lower16:var_TOIN
    movt r3, :upper16:var_TOIN
    str r6, [r3]                        @ store new >IN value

    mov r0, r7                          @ restore address of the parsed text
    pop {r4-r7}
    bx lr

