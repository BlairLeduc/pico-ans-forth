@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (numberic)
@   See 2.4 NUMERIC OUTPUT WORDS (FPH, p52)
@       1.1.6 Numeric Input (FPH, p13)
@

    .include "forth.S"

    .text

    .global _char
    .thumb_func
_char:
    bl __char                            @ r0 = pointer to string
    pushd r0                            @ Push the pointer to the string on the stack
    NEXT

    .global __char
    .thumb_func
__char: @ r0 = pointer to string
    push {lr}
    mov r0, #32                         @ ASCII space
    bl __word                           @ Returns r0 = length, r1 = pointer to word
    cmp r1, #0                          @ Check if word is empty
    beq 1f                              @ If empty, return
    ldrb r0, [r0, #1]                   @ Get the first character of the word
    pop {pc}                            @ Return with the character in r0

1:  eor r0, r0
    pop {pc}                            @ If empty, return 0 (cleared r0)

    .global __number
    .thumb_func
__number: @ r0 = pointer to string
    push {r4-r5}
    ldrb r1, [r0]                       @ length of the string
    add r2, r0, #1                      @ start address of string (skip the length byte)
    eor r0, r0                          @ r0 = parsed number (cleared)
    eor r5, r5                          @ r5 = negative flag (cleared)

    cmp r1, #0                          @ trying to parse a zero-length string is an error, but will return 0.
    beq 5f

    ldr r3, =var_BASE                   @ pointer to BASE
    ldrb r3, [r3]                       @ r3 = BASE

    @ Check if first character is '-'.
    ldrb r4, [r2], #1                   @ r5 = first character in string
    cmp r4, #'-'                        @ negative number?
    bne 2f
    mov r5, #1                          @ set flag to indicate negative number
    subs r1, #1                         @ decrement length of string
    bne 1f
    mov r1, #1
    pop {r4-r5}
    bx lr

    @ Loop reading digits.
1:  cmp r1, #0                          @ end of string?   
    beq 4f
    mul r0, r3, r0                      @ r0 *= BASE
    ldrb r4, [r2], #1                   @ r5 = next character in string

    @ Convert 0-9, A-Z, a-z to a number 0-35.
2:  subs r4, #'0'                        @ < '0'?
    bmi 4f
    cmp r4, #10                         @ <= '9'?
    blt 3f
    and r4, #0xDF                       @ convert to uppercase (a-z -> A-Z)
    subs r4, #17                         @ < 'A'? (17 is 'A'-'0')
    blt 4f
    add r4, #10

3:  cmp r4, r3                          @ >= BASE?
    bge 4f

    @ OK, so add it to r0 and loop.
    add r0, r4
    subs r1, #1
    bne 1b

    @ Negate the result if first character was '-' (saved on the stack).
4:  cmp r5, #0
    beq 5f
    neg r0, r0

5:  pop {r4-r5}
    bx lr


    @   6.1.0180    . ( n -- )                          “dot”
    @   
    @   Display n in free field format.

    .global _dot
    .thumb_func
_dot:
    popd r0                             @ get number from stack
    bl __dot                            @ convert to string and print
    mov r0, #32
    bl __emit
    NEXT

    .global __dot
    .thumb_func
__dot:
    push {lr}
    mov r1, r0
    eor r0, r0
    bl __dot_r
    pop {pc}

    .global _dot_r
    .thumb_func
_dot_r:
    popd r0
    popd r1
    bl __dot_r
    NEXT

    .global __dot_r
    .thumb_func
__dot_r: @ r0 = field width, r1 = number to print
    push {r4-r8, lr}
    mov r4, r1                          @ save number to convert
    mov r7, r0                          @ save field width
    eor r5, r5                          @ digit counter
    mov r6, sp                          @ save original stack pointer
    eor r3, r3                          @ clear negative flag

    @ Handle negative numbers
    cmp r4, #0
    bge 1f
    neg r4, r4                          @ make positive
    sub r7, #1                          @ account for minus sign in width
    mov r3, #1                          @ set negative flag

1:  @ Convert to digits
    ldr r8, =var_BASE                   @ get BASE
    ldr r8, [r8]                        @ r8 = BASE value

2:  @ Convert next digit
    udiv r1, r4, r8                     @ quotient in r1
    mul r2, r1, r8                      
    sub r0, r4, r2                      @ remainder in r0
    mov r4, r1                          @ quotient becomes new number
    
    @ Convert to ASCII
    cmp r0, #10
    bge 3f
    add r0, #'0'                        @ 0-9
    b 4f
3:  add r0, #'A'-10                     @ A-Z

4:  push {r0}                           @ save digit
    add r5, #1                          @ increment digit counter
    cmp r4, #0                          @ more digits?
    bne 2b

    @ Print leading spaces
    push {r3}
5:  cmp r7, r5                          @ compare width with digits
    ble 6f                              @ if width <= digits, skip spaces
    mov r0, #0x20                       @ ASCII space
    bl __emit
    sub r7, #1                          @ decrement width
    b 5b

6:  @ Print negative sign only if number is negative
    pop {r3}
    cmp r3, #0                          @ check negative flag
    beq 7f                              @ skip if positive
    mov r0, #'-'                        @ load minus sign
    bl __emit                           @ print it

7:  @ Print digits
    cmp r5, #0                          @ any digits left?
    beq 8f
    pop {r0}                            @ get next digit
    bl __emit                           @ print it
    sub r5, #1                          @ decrement counter
    b 7b

8:  mov sp, r6                          @ restore stack pointer
    pop {r4-r8, pc}


    .global _u_dot
    .thumb_func
_u_dot:
    popd r0                             @ get number from stack
    bl __u_dot                            @ convert to string and print
    mov r0, #32
    bl __emit
    NEXT

    .global __u_dot
    .thumb_func
__u_dot:
    push {lr}
    mov r1, r0
    eor r0, r0
    bl __u_dot_r
    pop {pc}

    .global _u_dot_r
    .thumb_func
_u_dot_r:
    popd r0
    popd r1
    bl __u_dot_r
    NEXT

    .global __u_dot_r
    .thumb_func
__u_dot_r: @ r0 = field width, r1 = number to print
    push {r4-r8, lr}
    mov r4, r1                          @ save number to convert
    mov r7, r0                          @ save field width
    eor r5, r5                          @ digit counter
    mov r6, sp                          @ save original stack pointer

1:  @ Convert to digits
    ldr r8, =var_BASE                   @ get BASE
    ldr r8, [r8]                        @ r8 = BASE value

2:  @ Convert next digit
    udiv r1, r4, r8                     @ quotient in r1
    mul r2, r1, r8                      
    sub r0, r4, r2                      @ remainder in r0
    mov r4, r1                          @ quotient becomes new number
    
    @ Convert to ASCII
    cmp r0, #10
    bge 3f
    add r0, #'0'                        @ 0-9
    b 4f
3:  add r0, #'A'-10                     @ A-Z

4:  push {r0}                           @ save digit
    add r5, #1                          @ increment digit counter
    cmp r4, #0                          @ more digits?
    bne 2b

    @ Print leading spaces
5:  cmp r7, r5                          @ compare width with digits
    ble 7f                              @ if width <= digits, skip spaces
    mov r0, #0x20                       @ ASCII space
    bl __emit
    sub r7, #1                          @ decrement width
    b 5b

7:  @ Print digits
    cmp r5, #0                          @ any digits left?
    beq 8f
    pop {r0}                            @ get next digit
    bl __emit                           @ print it
    sub r5, #1                          @ decrement counter
    b 7b

8:  mov sp, r6                          @ restore stack pointer
    pop {r4-r8, pc}

    .global __u_dot_0r
    .thumb_func
__u_dot_0r: @ r0 = field width, r1 = number to print
    push {r4-r8, lr}
    mov r4, r1                          @ save number to convert
    mov r7, r0                          @ save field width
    eor r5, r5                          @ digit counter
    mov r6, sp                          @ save original stack pointer

1:  @ Convert to digits
    ldr r8, =var_BASE                   @ get BASE
    ldr r8, [r8]                        @ r8 = BASE value

2:  @ Convert next digit
    udiv r1, r4, r8                     @ quotient in r1
    mul r2, r1, r8                      
    sub r0, r4, r2                      @ remainder in r0
    mov r4, r1                          @ quotient becomes new number
    
    @ Convert to ASCII
    cmp r0, #10
    bge 3f
    add r0, #'0'                        @ 0-9
    b 4f
3:  add r0, #'A'-10                     @ A-Z

4:  push {r0}                           @ save digit
    add r5, #1                          @ increment digit counter
    cmp r4, #0                          @ more digits?
    bne 2b

    @ Print leading spaces
5:  cmp r7, r5                          @ compare width with digits
    ble 7f                              @ if width <= digits, skip spaces
    mov r0, #0x30                       @ ASCII '0'
    bl __emit
    sub r7, #1                          @ decrement width
    b 5b

7:  @ Print digits
    cmp r5, #0                          @ any digits left?
    beq 8f
    pop {r0}                            @ get next digit
    bl __emit                           @ print it
    sub r5, #1                          @ decrement counter
    b 7b

8:  mov sp, r6                          @ restore stack pointer
    pop {r4-r8, pc}
