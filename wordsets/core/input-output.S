@
@   ANS Forth for the Clockwork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth Core workset (onput-output)
@   See 3.3 SERIAL I/O (FPH, p81)

    .include "forth.S"

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


    .global _refill
    .thumb_func
_refill:
    bl __refill
    pushd r0                             @ get the result of the refill
    NEXT

    .global __refill
    .thumb_func
__refill:
    push {lr}
    movw r0, :lower16:var_BLK           @ load the BLK source
    movt r0, :upper16:var_BLK
    ldr r0, [r0]                        @ get the current block number
    cmp r0, #0                          @ is it zero?
    beq 1f                              @ if so, check SOURCE_ID to determine input source

    @ Block input stream (BLK > 0)
    eor r0, r0                          @ not implemented: clear r0
    pop {pc}                            @ always return false (no input available) until we implement block input

1:  movw r0, :lower16:var_SOURCE_ID     @ load the source ID
    movt r0, :upper16:var_SOURCE_ID
    ldr r0, [r0]                        @ get the current source ID
    cmp r0, #0                          @ the source is?
    beq 2f                              @ = 0, refill from terminal
    bgt 3f                              @ > 0, refill from a text file

    @ Character String input stream or some unknown source (SOURCE_ID < 0)
    eor r0, r0                          @ refill does not apply to character strings (or unknown sources)
    pop {pc}                            @ always return false (no input available)

    @ Terminal input stream (SOURCE_ID = 0)
2:  movw r0, :lower16:terminal_input_buffer
    movt r0, :upper16:terminal_input_buffer
    movw r1, :lower16:input_source
    movt r1, :upper16:input_source
    str r0, [r1]
    mov r1, #TERMINAL_INPUT_BUFFER_SIZE
    bl __accept
    movw r1, :lower16:input_source + 4
    movt r1, :upper16:input_source + 4
    str r0, [r1]
    movw r1, :lower16:var_TOIN
    movt r1, :upper16:var_TOIN
    eor r0,r0
    str r0, [r1]                        @ reset >IN to 0
    mov r0, #-1
    pop {pc}

    @ File input stream (SOURCE_ID > 0)
3:  eor r0, r0                          @ not implemented: clear r0
    pop {pc}                            @ always return false (no input available) until we implement file input


    .global _restore_input
    .thumb_func
_restore_input:
    popd r2                             @ the number of items to restore
    subs r2, #1                         @ decrement and set flags
    blt 3f                              @ if negative, branch to error handling
    popd r0                             
    ldr r1, =var_BLK
    str r0, [r1]                        @ restore the BLK variable
    subs r2, #1                         @ decrement and set flags
    blt 3f                              @ if negative, branch to error handling
    popd r0                             @ the source ID
    ldr r1, =var_SOURCE_ID
    str r0, [r1]                        @ restore the SOURCE_ID variable
    subs r2, #1                         @ decrement and set flags
    blt 3f                              @ if negative, branch to error handling
    popd r1                             @ the source size
    subs r2, #1                         @ decrement and set flags
    blt 3f                              @ if negative, branch to error handling
    popd r0                             @ the source pointer
    movw r3, :lower16:input_source
    movt r3, :upper16:input_source
    stmia r3, {r0, r1}                  @ restore the source pointer and size
    subs r2, #1                         @ decrement and set flags
    blt 3f                              @ if negative, branch to error handling
    
1:  cmp r2, #0                          @ check if we have more items to remove
    ble 2f                              @ if not, we're done
    popd r0                             @ remove extra item from stack
    subs r2, #1                         @ decrement counter
    b 1b                                @ loop until all extra items removed

2:  eor r2, r2                          @ clear r2 (success)
3:  pushd r2                            @ push success flag
    NEXT


    .global _save_input
    .thumb_func
_save_input:
    movw r0, :lower16:input_source
    movt r0, :upper16:input_source
    ldmia r0, {r0, r1}                  @ r4 = source buffer address, r5 = source size 
    pushd r0
    pushd r1
    ldr r0, =var_TOIN
    ldr r0, [r0]
    pushd r0
    ldr r0, =var_SOURCE_ID
    ldr r0, [r0]
    pushd r0
    ldr r0, =var_BLK
    ldr r0, [r0]
    pushd r0
    mov r0, #5
    pushd r0                            @ push the number of items to save
    NEXT

    .global _source
    .thumb_func
_source:
    movw r0, :lower16:input_source
    movt r0, :upper16:input_source
    ldmia r0, {r0, r1}                  @ r4 = source buffer address, r5 = source size 
    pushd r0
    pushd r1
    NEXT

    .global _tib
    .thumb_func
_tib:
    movw r0, :lower16:terminal_input_buffer
    movt r0, :upper16:terminal_input_buffer
    pushd R0
    NEXT
