@
@   Leduc Forth - a simple FORTH compiler/interpreter for the ClockWork PicoCalc
@   Copyright Blair Leduc.
@   See LICENSE for details.
@
@   This file contains the Standard Forth initialisation code.
@

    .include "forth.inc"

@   Register Usage:
@       r0-r4:  General purpose/scratch registers
@       r5:     Instruction register [I]
@       r6:     Return stack register [R]
@       r7:     Float stack register [F] 
@       r8:     Data stack register [S]
@       r9:     Reserved by RP2040 SDK (Platform register)
@       r10-r11: Reserved for C compiler (Frame pointers)
@       r12:    IP (Intra-Procedure-call scratch)
@       r13:    SP (Stack pointer)
@       r14:    LR (Link register)
@       r15:    PC (Program counter)

@   Naming conventions:
@   label: Secondary word that completes with EXIT.
@   _label: Primary word that completes with NEXT.
@   __label: Internal routine where parameters and outputs in r0-r3 and completes with bx lr.



@
@   Interpreter bootstrap
@
    .section .rodata
    .balign 4
bootstrap:
    .word QUIT    
@
@   To get things going:
@
@   bootstrap <- r5
@   |
@   v
@   +--------+
@   | QUIT   |
@   +--------+
@
@   We load r5 to hold the address of the first execution token (QUIT) to execute,
@   which points to _quit. We are using indirect threaded code.
@
@   We use the macro NEXT to get started. The NEXT macro calls the interpreter or
@   hand-crafted code of the execution token in r5.
@
@   What NEXT does:  loads r0 with the execution token pointed to by r5 (QUIT)
@   and (since indirect) NEXT loads from r0 the address of the interpreter or
@   hand-crafted code:
@
@   +--------+
@   | QUIT   |
@   +-|------+
@     |
@     r0
@      |
@      +------------------------------------------------+
@                                                       |
@   +--------+--------+---+---+---+---+---+---+---+---+-v------+
@   | LOCATE | LINK   | 4 | Q | U | I | T | 0 | 0 | 0 | _quit  |
@   +--------+--------+---+---+---+---+---+---+---+---+--------+
@
@   and calls, in this case, the hand-crafted code, _quit.
@


@
@   Forth System Initialisation
@


    .text
    .global forth_start
forth_start:
    @ print welcome message
    ldr r0, =welcome_message
    bl __type_cstr

    @ Bootstrap the interpreter
    movw r5, :lower16:bootstrap
    movt r5, :upper16:bootstrap

    NEXT                                @ run the interpreter!
    
    .section .rodata
welcome_message:
    .ascii "Welcome to ANS Forth on the Pico 2!\x0D"
    .ascii "Copyright Blair Leduc.\x0D"
    .asciz "Version 1.0.0-alpha.0\x0D"



@
@   System Support
@
    .section .text

    .global __check_stacks
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
    mov r0, #ERR_FLOAT_STACK_UNDERFLOW
    bx lr
5:  movw r0, :lower16:float_stack        @ check for float stack overflow
    movt r0, :upper16:float_stack
    subs r0, r7
    bmi 6f
    mov r0, #ERR_FLOAT_STACK_OVERFLOW
    bx lr
6:  movw r0, :lower16:data_space_bottom  @ check for data space overflow
    movt r0, :upper16:data_space_bottom
    movw r1, :lower16:var_LATEST
    movt r1, :upper16:var_LATEST
    ldr r1, [r1]                        @ get the address of LATEST
    subs r0, r1
    bpl 7f
    mov r0, #ERR_DICTIONARY_FULL
    bx lr
7:  mov r0, #ERR_OK                     @ all checks passed, return OK
    bx lr
 


@
@   Returning from FORTH words
@


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
    .global data_space, data_space_bottom
data_space:
    .space DATA_SPACE_SIZE
data_space_bottom:                      @ bottom of data space
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


