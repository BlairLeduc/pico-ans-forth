@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (onput-output)
@   See 3.3 SERIAL I/O (FPH, p81)

    .include "forth.inc"

    .text

    .global _accept
    .thumb_func
_accept:
    popd r1
    popd r0
    bl __accept
    pushd r0
    NEXT

    .global __accept
    .thumb_func
__accept:
    push    {r4-r7, lr}         @ Save callee-saved registers and return address

    mov     r4, r0              @ r4 = buffer
    mov     r5, r1              @ r5 = len
    movs    r6, #0              @ r6 = pos

accept_loop:
    bl      __key               @ ch = __key()
    mov     r7, r0              @ r7 = ch

    cmp     r7, #0x08           @ Backspace?
    beq     handle_bs

    cmp     r7, #0x7f           @ DEL?
    beq     handle_del

    cmp     r7, #0x0d           @ CR?
    beq     handle_cr

    cmp     r7, #0x20           @ ch < 0x20?
    blt     accept_loop         @ Ignore non-printable

    cmp     r7, #0x7e           @ ch > 0x7e?
    bgt     accept_loop         @ Ignore non-printable

    cmp     r6, r5              @ pos >= len?
    bge     handle_full

    add     r0, r4, r6          @ r0 = buffer + pos
    strb    r7, [r0]            @ buffer[pos] = ch
    mov     r0, r7              @ __emit(ch)
    bl      __emit
    adds    r6, r6, #1          @ pos++
    b       accept_loop

handle_bs:
    cmp     r6, #0
    beq     bell_on_bs
    subs    r6, r6, #1          @ pos--
    movs    r0, #0x08           @ __emit(0x08)
    bl      __emit
    movs    r0, #' '            @ __emit(' ')
    bl      __emit
    movs    r0, #0x08           @ __emit(0x08)
    bl      __emit
    b       accept_loop

bell_on_bs:
    movs    r0, #0x07           @ __emit(0x07)
    bl      __emit
    b       accept_loop

handle_del:
    movs    r6, #0              @ pos = 0
    ldr     r0, =del_str        @ __type_cstr("\033[2K\015")
    bl      __type_cstr
    b       accept_loop

handle_cr:
    add     r0, r4, r6          @ r0 = buffer + pos
    movs    r1, #' '            @ ' '
    strb    r1, [r0]            @ buffer[pos] = ' '
    movs    r0, #' '            @ __emit(' ')
    bl      __emit
    mov     r0, r6              @ return pos
    pop     {r4-r7, pc}

handle_full:
    movs    r0, #0x07           @ __emit(0x07)
    bl      __emit
    b       accept_loop

    .section .rodata
del_str:
    .asciz  "\033[2K\015"
    .balign 4
    .text

    .global _key
    .thumb_func
_key:
    bl __key
    pushd r0
    NEXT

    .global _emit
    .thumb_func
_emit:
    popd r0
    bl __emit
    NEXT

    .global _type
    .thumb_func
_type:
    popd r1
    popd r0
    bl __type
    NEXT

    .global __type
    .thumb_func
__type: @ r0 = address, r1 = length
    push {r4-r5, lr}
    mov r4, r0                          @ r4 = address
    mov r5, r1                          @ r5 = length
1:  cmp r5, #0
    beq 2f
    ldrb r0, [r4], #1                   @ load byte from address, increment address
    bl __emit                           @ emit the character
    sub r5, #1                          @ decrement length
    b 1b                                @ repeat until all characters are emitted
2:  pop {r4-r5, pc}                     @ restore registers and return

    .global __type_cstr
    .thumb_func
__type_cstr: @ r0 = address of C string
    push {r4, lr}
    mov r4, r0                          @ r4 = address of C string
1:  ldrb r0, [r4], #1                   @ load byte from address, increment address
    cmp r0, #0                          @ check for null terminator
    beq 2f                              @ if null terminator, exit loop
    bl __emit                           @ emit the character
    b 1b                                @ repeat until null terminator is found
2:  pop {r4, pc}                        @ restore registers and return

    .global _cr
    .thumb_func
_cr:
    bl __cr
    NEXT

    .global __cr
    .thumb_func
__cr:
    push {lr}
    mov r0, #0x0d                       @ ASCII carriage return (0x0d)
    bl __emit
    mov r0, #0x0a                       @ ASCII line feed (0x0a)
    bl __emit
    pop {pc}

    .global _space
    .thumb_func
_space:
    mov r0, #0x20                       @ ASCII space (0x20)
    bl __emit
    NEXT

    .global _spaces
    .thumb_func
_spaces:
    push {r4}
    popd r4                             @ get the number of spaces (u)
1:  cmp r4, #0
    beq 2f
    mov r0, #0x20                       @ ASCII space (0x20)
    bl __emit                           @ emit the space character
    sub r4, #1
    b 1b                                @ repeat until all spaces are emitted
2:  pop {r4}
    NEXT

