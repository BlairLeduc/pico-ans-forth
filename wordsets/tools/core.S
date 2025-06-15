@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Tools workset.
@

    .include "forth.inc"

    .section .text   

    .global _dot_s
_dot_s:
    push {r4-r5, lr}
    movw r4, :lower16:data_stack_top
    movt r4, :upper16:data_stack_top
    sub r4, #4
    bl __cr
1:  cmp r4, r8                          @ check if data stack is empty
    blt 2f
    ldr r0, [r4], #-4
    bl __dot
    b 1b
2:  ldr r0, =top_message
    bl __type_cstr
    pop {r4-r5, lr}
    NEXT
top_message:
    .asciz "<-Top "
    .balign 4

    .global _dump
_dump:
    popd r0                             @ r0 = number of bytes to dump
    popd r1                             @ r1 = address to dump
    bl __dump
    NEXT

    .global __dump
__dump: @ r0 = count, r1 = address
    push {r4-r7, lr}
    mov r4, r1                          @ save address
    mov r5, r0                          @ save count
    mov r6, #0                          @ line counter

    movw r2, :lower16:var_BASE
    movt r2, :upper16:var_BASE
    ldr r3, [r2]                        @ load current BASE
    push {r3}
    mov r3, #16                         @ set BASE to 16
    str r3, [r2]                        @ store BASE

    bl __cr                             @ print a new line

1:  @ Print address
    mov r1, r4                          @ load address
    mov r0, #8                          @ field width 8
    bl __u_dot_0r                       @ print address
    mov r0, #0x20                       @ space
    bl __emit

    @ Save start of line for ASCII display
    mov r7, r4                          @ save start address

2:  @ Print CPL/4 hex bytes
    mov r3, #BPR                        @ bytes per row
3:  ldrb r1, [r4], #1                   @ load byte and increment
    push {r3}                           @ save counter
    mov r0, #2                          @ field width 2
    bl __u_dot_0r                       @ print byte
    mov r0, #0x20                       @ space
    bl __emit
    pop {r3}                           
    subs r3, #1                         @ decrement counter
    bne 3b

    @ Print ASCII representation
    mov r3, #BPR                       @ reset counter
4:  ldrb r0, [r7], #1                  @ load byte from saved address
    cmp r0, #0x20                      @ check if printable
    blo 5f
    cmp r0, #0x7E
    bhi 5f
    b 6f                               @ printable, skip replacement
5:  mov r0, #'.'                       @ not printable, show dot
6:  push {r3}
    bl __emit
    pop {r3}
    subs r3, #1
    bne 4b

    bl __cr                            @ end of line
    
    subs r5, #BPR                      @ decrement count
    ble 7f                             @ exit if done
    b 1b                               @ next line

7:  
    pop {r3}
    movw r2, :lower16:var_BASE
    movt r2, :upper16:var_BASE
    str r3, [r2]                       @ store BASE
    pop {r4-r7, pc}                    @ return


    .global _words
_words:
    push {r4-r6, lr}
    
    @ Get latest dictionary entry
    movw r4, :lower16:var_LATEST
    movt r4, :upper16:var_LATEST
    ldr r4, [r4]                        @ r4 = first word in dictionary
    eor r5, r5                          @ r5 = chars on current line

    bl __cr                             @ print a new line
    
1:  @ Print each word
    cmp r4, #0                          @ end of dictionary?
    beq 5f                              @ yes, done
    
2:  @ Print the word
    add r4, #4                          @ Move to name
    ldr r1, [r4], #1
    ands r2, r1, #CB_SMUDGE
    bne 4f                              @ skip smudged words
    and r1, #CB_LENGTH                  @ get word name length
    add r5, r1                          @ Add length to char count
    add r5, #1                          @ Add 1 for space
    cmp r5, #CPL                        @ check if line is too long
    blt 3f
    mov r6, r1
    bl __cr                             @ yes, print new line
    mov r1, r6                          @ restore word name length
    eor r5, r5                          @ reset char count
    add r5, r1
    add r5, #1                          @ Add 1 for space
3:  mov r0, r4                          @ word name address
    bl __type                           @ print word
    mov r0, #0x20                       @ space
    bl __emit

    @ Move to next word
4:  sub r4, #5                          @ back to start of header
    ldr r4, [r4]                        @ follow link
    b 1b                                @ next word

5:  pop {r4-r6, pc}
