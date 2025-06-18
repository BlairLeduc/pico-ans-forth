@
@   ANS Forth for the Pico 2
@   Copyright Blair Leduc.
@   See LICENSE for details.
@

    .include "forth.inc"

    .text


    @   6.1.1650    HERE ( -- addr )
    @
    @   addr is the data-space pointer.

    .global _here
    .thumb_func
_here:
    ldr r0, =var_DP
    ldr r0, [r0]
    pushd r0
    NEXT


    @   6.2.2000    PAD ( -- c-addr )
    @
    @   c-addr is the address of a transient region that can be used to hold data for intermediate
    @   processing.

    .global _pad
    .thumb_func
_pad:
    ldr r0, =pad_storage
    pushd r0
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
1:  cmp r1, #0
    beq 2f
    ldrb r3, [r0], #1                   @ load byte from source, increment
    strb r3, [r2], #1                   @ store byte to dest, increment
    sub r1, #1
    b 1b
2:  bx lr


    @   Check Stacks
    @
    @   This word checks the integrity of the stacks and data space. It verifies that the stacks have not
    @   overflowed or underflowed, and that the data space has not overflowed. If any of these checks fail,
    @   it returns an error code. If all checks pass, it returns ERR_OK.

    .global __check_stacks
    .thumb_func
__check_stacks:
    @ Check the integrity of the stacks and data space.
    movw r0, :lower16:return_stack_top  @ check for return stack underflow
    movt r0, :upper16:return_stack_top
    subs r0, r6
    bpl 1f
    mov r0, #ERR_RETURN_STACK_UNDERFLOW
    bx lr
1:  movw r0, :lower16:return_stack      @ check for return stack overflow
    movt r0, :upper16:return_stack
    subs r0, r6
    bmi 2f
    mov r0, #ERR_RETURN_STACK_OVERFLOW
    bx lr
2:  movw r0, :lower16:data_stack_top    @ check for data stack underflow
    movt r0, :upper16:data_stack_top
    subs r0, r8
    bpl 3f
    mov r0, #ERR_STACK_UNDERFLOW
    bx lr
3:  movw r0, :lower16:data_stack        @ check for data stack overflow
    movt r0, :upper16:data_stack
    subs r0, r8
    bmi 4f
    mov r0, #ERR_STACK_OVERFLOW
    bx lr
4:  movw r0, :lower16:float_stack_top   @ check for float stack underflow
    movt r0, :upper16:float_stack_top
    subs r0, r7
    bpl 5f
    mov r0, #ERR_FP_STACK_UNDERFLOW
    bx lr
5:  movw r0, :lower16:float_stack        @ check for float stack overflow
    movt r0, :upper16:float_stack
    subs r0, r7
    bmi 6f
    mov r0, #ERR_FP_STACK_OVERFLOW
    bx lr
6:  movw r0, :lower16:data_space_top  @ check for data space overflow
    movt r0, :upper16:data_space_top
    movw r1, :lower16:var_LATEST
    movt r1, :upper16:var_LATEST
    ldr r1, [r1]                        @ get the address of LATEST
    subs r0, r1
    bpl 7f
    mov r0, #ERR_DICTIONARY_OVERFLOW
    bx lr
7:  mov r0, #ERR_OK                     @ all checks passed, return OK
    bx lr
 

@
@   Data Reservations
@

    .data

    @ Forth data stack
    .balign 4
    .space 8                            @ reserve space for the bottom of the stack pointer in case of overflow   
    .global data_stack, data_stack_top
data_stack:
    .space DATA_STACK_SIZE
data_stack_top:                         @ initial top of data stack
    .space 8                            @ reserve space for the top of the stack pointer in case of underflow   

    @ Forth return stack
    .balign 4
    .space 8                            @ reserve space for the bottom of the stack pointer in case of overflow   
    .global return_stack, return_stack_top
return_stack:
    .space RETURN_STACK_SIZE
return_stack_top:                       @ initial top of return stacki
    .space 8                            @ reserve space for the top of the stack pointer in case of underflow

    @ Forth float stack
    .balign 4
    .space 8                            @ reserve space for the bottom of the stack pointer in case of overflow   
    .global float_stack, float_stack_top
float_stack:
    .space FLOAT_STACK_SIZE
float_stack_top:                        @ initial top of float stack
    .space 8                            @ reserve space for the top of the stack pointer in case of underflow

    @ Forth data space
    .balign 4
    .global data_space, data_space_top
data_space:
    .space DATA_SPACE_SIZE
data_space_top:                      @ bottom of data space
    .space 8                            @ reserve space for the bottom of the data space pointer in case of overflow

    @ Forth Pad Storage
    .balign 4
    .global pad_storage
pad_storage:
    .space PAD_SIZE

    @ Forth Terminal input buffer
    .balign 4
    .global terminal_input_buffer
terminal_input_buffer:
    .space TERMINAL_INPUT_BUFFER_SIZE   @ reserve bytes for the terminal input buffer

    @ Forth s-quoted string buffer
    .balign 4
    .global s_quoted_string_buffer
s_quoted_string_buffer:
    .space S_QUOTED_STRING_BUFFER_SIZE  @ reserve bytes for the s-quoted string buffer
